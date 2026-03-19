#import "./include/audio_service/AudioServicePlugin.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>

// If you'd like to help, please see the TODO comments below, then open a
// GitHub issue to announce your intention to work on a particular feature, and
// submit a pull request. We have an open discussion over at issue #10 about
// all things iOS if you'd like to discuss approaches or ask for input. Thank
// you for your support!

static NSHashTable<AudioServicePlugin *> *plugins = nil;
static FlutterMethodChannel *handlerChannel = nil;
static FlutterResult startResult = nil;
static MPRemoteCommandCenter *commandCenter = nil;
static NSMutableDictionary *mediaItem = nil;
static long actionBits = 0;
static NSMutableArray *commands;
static BOOL _controlsUpdated = NO;
static enum AudioProcessingState processingState = ApsIdle;
static BOOL playing = NO;
static NSNumber *position = nil;
static NSNumber *bufferedPosition = nil;
static NSNumber *updateTime = nil;
static NSNumber *speed = nil;
static NSNumber *repeatMode = nil;
static NSNumber *shuffleMode = nil;
static NSNumber *fastForwardInterval = nil;
static NSNumber *rewindInterval = nil;
static MPMediaItemArtwork* artwork = nil;
static NSMutableDictionary *nowPlayingInfo = nil;
static int forceUpdateCounter = 0;  // 用于强制刷新的计数器

@implementation AudioServicePlugin {
    FlutterMethodChannel *_channel;
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    NSLog(@"audio_service: ===== AudioServicePlugin registerWithRegistrar called =====");

    @synchronized(self) {
        if (!plugins) {
            plugins = [NSHashTable weakObjectsHashTable];
            NSLog(@"audio_service: Created new plugins hash table");
        }
        AudioServicePlugin *instance = [[AudioServicePlugin alloc] initWithRegistrar:registrar];
        [registrar addMethodCallDelegate:instance channel:instance.channel];
        [plugins addObject:instance];
        NSLog(@"audio_service: Plugin instance added (handlerChannel exists: %@)", handlerChannel ? @"YES" : @"NO");
        if (!handlerChannel) {
            processingState = ApsIdle;
            position = @(0);
            bufferedPosition = @(0);
            long long msSinceEpoch = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
            updateTime = [NSNumber numberWithLongLong: msSinceEpoch];
            speed = [NSNumber numberWithDouble: 1.0];
            repeatMode = @(0);
            shuffleMode = @(0);
            nowPlayingInfo = [NSMutableDictionary new];
            handlerChannel = [FlutterMethodChannel
                methodChannelWithName:@"com.ryanheise.audio_service.handler.methods"
                      binaryMessenger:[registrar messenger]];
            [registrar addMethodCallDelegate:instance channel:handlerChannel];

#if TARGET_OS_IPHONE
            // 监听 app 生命周期事件，自动刷新 nowPlayingInfo
            // 这是解决"第二次进入后台灵动岛不显示"问题的关键
            // 由于 Dart 层的 MethodChannel 调用可能在 app 被挂起前未完成，
            // 所以我们直接在原生层监听生命周期事件

            // 使用 __weak 避免循环引用
            __weak AudioServicePlugin *weakInstance = instance;

            // 注意：使用 NSOperationQueue.mainQueue 确保在主线程处理
            [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillResignActiveNotification
                                                              object:nil
                                                               queue:[NSOperationQueue mainQueue]
                                                          usingBlock:^(NSNotification * _Nonnull note) {
                AudioServicePlugin *strongInstance = weakInstance;
                if (!strongInstance) return;

                NSLog(@"audio_service: [Block] applicationWillResignActive - playing=%d, hasNowPlayingInfo=%d",
                      playing, (nowPlayingInfo != nil && nowPlayingInfo.count > 0));
                if (playing && nowPlayingInfo != nil && nowPlayingInfo.count > 0) {
                    // 尝试十四（2024-12-28）：
                    // 日志分析发现：MXSession 的 ClientType = None，因为 ClientIsPlaying = STOPPED
                    // 这是因为 iOS 没有检测到 AudioToolbox 在播放
                    // 解决方案：在进入后台前重新激活 AVAudioSession，强制 iOS 重新识别播放状态
                    [strongInstance reactivateAudioSessionAndRefresh];
                }
            }];

            [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                              object:nil
                                                               queue:[NSOperationQueue mainQueue]
                                                          usingBlock:^(NSNotification * _Nonnull note) {
                AudioServicePlugin *strongInstance = weakInstance;
                if (!strongInstance) return;

                NSLog(@"audio_service: [Block] applicationDidEnterBackground - playing=%d, hasNowPlayingInfo=%d",
                      playing, (nowPlayingInfo != nil && nowPlayingInfo.count > 0));
                if (playing && nowPlayingInfo != nil && nowPlayingInfo.count > 0) {
                    [strongInstance forceRefreshNowPlayingInfo];
                }
            }];

            [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                              object:nil
                                                               queue:[NSOperationQueue mainQueue]
                                                          usingBlock:^(NSNotification * _Nonnull note) {
                AudioServicePlugin *strongInstance = weakInstance;
                if (!strongInstance) return;

                NSLog(@"audio_service: [Block] applicationDidBecomeActive - playing=%d, hasNowPlayingInfo=%d",
                      playing, (nowPlayingInfo != nil && nowPlayingInfo.count > 0));

                // 尝试十四（2024-12-28）：
                // 日志分析发现：MXSession 的 ClientType = None，因为 iOS 没有检测到音频播放
                // 解决方案：返回前台时立即重新激活 AVAudioSession，并延迟刷新播放状态
                if (playing && nowPlayingInfo != nil && nowPlayingInfo.count > 0) {
                    // 立即重新激活 AVAudioSession
                    [strongInstance reactivateAudioSession];

                    // 延迟 100ms 后重新设置播放状态
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(100 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
                        AudioServicePlugin *innerStrongInstance = weakInstance;
                        if (!innerStrongInstance) return;

                        if (playing && nowPlayingInfo != nil && nowPlayingInfo.count > 0) {
                            MPNowPlayingInfoCenter *center = [MPNowPlayingInfoCenter defaultCenter];
                            center.nowPlayingInfo = nowPlayingInfo;

                            if (@available(iOS 13.0, *)) {
                                center.playbackState = MPNowPlayingPlaybackStatePlaying;
                            }

                            NSLog(@"audio_service: [Block] applicationDidBecomeActive - restored playback state to Playing");
                        }
                    });
                }
            }];

            NSLog(@"audio_service: 已注册 app 生命周期监听 (block-based observers)");
#endif
        }
    }
}

- (instancetype)initWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
    self = [super init];
    NSAssert(self, @"super init cannot be nil");
    _channel = [FlutterMethodChannel
        methodChannelWithName:@"com.ryanheise.audio_service.client.methods"
              binaryMessenger:[registrar messenger]];
    return self;
}

- (FlutterMethodChannel *)channel {
    return _channel;
}

- (void)invokeClientMethod:(NSString *)method arguments:(id _Nullable)arguments {
    for (AudioServicePlugin *plugin in plugins) {
        [plugin.channel invokeMethod:method arguments:arguments];
    }
}

- (void)invokeClientMethod:(NSString *)method arguments:(id _Nullable)arguments result:(FlutterResult)result {
    for (AudioServicePlugin *plugin in plugins) {
        [plugin.channel invokeMethod:method arguments:arguments result:result];
    }
}

- (void)activateCommandCenter {
    NSLog(@"audio_service: ===== activateCommandCenter called =====");
    commandCenter = [MPRemoteCommandCenter sharedCommandCenter];
    commands = [NSMutableArray new];
    [commands addObjectsFromArray:@[
        commandCenter.stopCommand,
        commandCenter.pauseCommand,
        commandCenter.playCommand,
        commandCenter.skipBackwardCommand,
        commandCenter.previousTrackCommand,
        commandCenter.nextTrackCommand,
        commandCenter.skipForwardCommand,
        [NSNull null],
        [NSNull null], // changePlaybackPositionCommand, put below
        commandCenter.togglePlayPauseCommand,
        [NSNull null],
        [NSNull null],
        [NSNull null],
        [NSNull null],
        [NSNull null],
        [NSNull null],
        [NSNull null],
        [NSNull null],
        commandCenter.changeRepeatModeCommand,
        [NSNull null],
        [NSNull null],
        commandCenter.changeShuffleModeCommand,
        commandCenter.seekBackwardCommand,
        commandCenter.seekForwardCommand,
        commandCenter.changePlaybackRateCommand,
    ]];
    if (@available(iOS 9.1, macOS 10.12.2, *)) {
        commands[8] = commandCenter.changePlaybackPositionCommand;
    }
    [commandCenter.changePlaybackRateCommand setEnabled:YES];
    [commandCenter.togglePlayPauseCommand setEnabled:YES];
    [commandCenter.togglePlayPauseCommand addTarget:self action:@selector(togglePlayPause:)];
    // TODO: enable more commands
    // Language options
    if (@available(iOS 9.0, macOS 10.12.2, *)) {
        [commandCenter.enableLanguageOptionCommand setEnabled:NO];
        [commandCenter.disableLanguageOptionCommand setEnabled:NO];
    }
    // Rating
    [commandCenter.ratingCommand setEnabled:NO];
    // Feedback
    [commandCenter.likeCommand setEnabled:NO];
    [commandCenter.dislikeCommand setEnabled:NO];
    [commandCenter.bookmarkCommand setEnabled:NO];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([@"configure" isEqualToString:call.method]) {
        NSDictionary *args = (NSDictionary *)call.arguments;
        NSDictionary *configMap = (NSDictionary *)args[@"config"];
        fastForwardInterval = configMap[@"fastForwardInterval"];
        rewindInterval = configMap[@"rewindInterval"];
        result(@{});
    } else if ([@"setState" isEqualToString:call.method]) {
        NSDictionary *args = (NSDictionary *)call.arguments;
        NSDictionary *stateMap = (NSDictionary *)args[@"state"];
        long long msSinceEpoch;
        if (stateMap[@"updateTime"] != [NSNull null]) {
            msSinceEpoch = [stateMap[@"updateTime"] longLongValue];
        } else {
            msSinceEpoch = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
        }
        actionBits = 0;
        NSArray *controlsArray = stateMap[@"controls"];
        for (int i = 0; i < controlsArray.count; i++) {
            NSDictionary *control = (NSDictionary *)controlsArray[i];
            NSNumber *actionIndex = (NSNumber *)control[@"action"];
            int actionCode = 1 << [actionIndex intValue];
            actionBits |= actionCode;
        }
        NSArray *systemActionsArray = stateMap[@"systemActions"];
        for (int i = 0; i < systemActionsArray.count; i++) {
            NSNumber *actionIndex = (NSNumber *)systemActionsArray[i];
            int actionCode = 1 << [actionIndex intValue];
            actionBits |= actionCode;
        }
        processingState = [stateMap[@"processingState"] intValue];
        BOOL oldPlaying = playing;
        NSNumber *oldSpeed = speed;
        NSNumber *oldPosition = position;
        playing = [stateMap[@"playing"] boolValue];
        position = stateMap[@"updatePosition"];
        bufferedPosition = stateMap[@"bufferedPosition"];
        speed = stateMap[@"speed"];
        repeatMode = stateMap[@"repeatMode"];
        shuffleMode = stateMap[@"shuffleMode"];
        updateTime = [NSNumber numberWithLongLong: msSinceEpoch];
        if (playing && !commandCenter) {
#if TARGET_OS_IPHONE
            [AVAudioSession sharedInstance];
#endif
            [self activateCommandCenter];
        }

        // 尝试十八：添加日志追踪 actionBits
        // ASkipToPrevious = 4, ASkipToNext = 5
        // 所以 actionBits 应该包含 (1<<4)=16 和 (1<<5)=32
        BOOL hasSkipToPrevious = (actionBits >> 4) & 1;
        BOOL hasSkipToNext = (actionBits >> 5) & 1;
        NSLog(@"audio_service: setState actionBits=%ld hasSkipToPrevious=%d hasSkipToNext=%d playing=%d commandCenter=%@",
              actionBits, hasSkipToPrevious, hasSkipToNext, playing, commandCenter ? @"YES" : @"NO");

        [self updateControls];
        if (playing != oldPlaying ||
            speed.doubleValue != oldSpeed.doubleValue ||
            position.longLongValue != oldPosition.longLongValue) {
            [self updateNowPlayingInfo];
        }
        result(@{});
    } else if ([@"setQueue" isEqualToString:call.method]) {
        result(@{});
    } else if ([@"setMediaItem" isEqualToString:call.method]) {
        NSDictionary *args = (NSDictionary *)call.arguments;
        mediaItem = args[@"mediaItem"];
        NSString* artUri = mediaItem[@"artUri"];
        artwork = nil;
        if (![artUri isEqual: [NSNull null]]) {
            NSString* artCacheFilePath = (NSString *)[NSNull null];
            NSDictionary* extras = mediaItem[@"extras"];
            if (![extras isEqual: [NSNull null]]) {
                artCacheFilePath = extras[@"artCacheFile"];
            }
            if (![artCacheFilePath isEqual: [NSNull null]]) {
#if TARGET_OS_IPHONE
                UIImage* artImage = [UIImage imageWithContentsOfFile:artCacheFilePath];
#else
                NSImage* artImage = [[NSImage alloc] initWithContentsOfFile:artCacheFilePath];
#endif
                if (artImage != nil) {
#if TARGET_OS_IPHONE
                    artwork = [[MPMediaItemArtwork alloc] initWithImage: artImage];
#else
                    artwork = [[MPMediaItemArtwork alloc] initWithBoundsSize:artImage.size requestHandler:^NSImage* _Nonnull(CGSize aSize) {
                        return artImage;
                    }];
#endif
                }
            }
        }
        [self updateNowPlayingInfo];
        result(@{});
    } else if ([@"setPlaybackInfo" isEqualToString:call.method]) {
        result(@{});
    } else if ([@"notifyChildrenChanged" isEqualToString:call.method]) {
        result(@{});
    } else if ([@"androidForceEnableMediaButtons" isEqualToString:call.method]) {
        result(@{});
    } else if ([@"stopService" isEqualToString:call.method]) {
        // 尝试十九：修复灵动岛上一首/下一首无法播放的问题
        // 问题原因：切歌流程中 processingState 变为 idle 时，audio_service 会调用 stopService
        // stopService 将 actionBits 设为 0，导致所有 Remote Command handlers 被移除
        // 解决方案：保留 skipToNext 和 skipToPrevious 的 handlers，即使在 stopService 中
        NSLog(@"audio_service: ===== stopService called =====");
        NSLog(@"audio_service: stopService - commandCenter=%@, actionBits=%ld", commandCenter ? @"YES" : @"NO", actionBits);

        [commandCenter.changePlaybackRateCommand setEnabled:NO];
        [commandCenter.togglePlayPauseCommand setEnabled:NO];
        [commandCenter.togglePlayPauseCommand removeTarget:nil];
        [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = nil;
        processingState = ApsIdle;

        // 重要修复（尝试十九）：
        // 不要将 actionBits 设为 0，而是保留 skipToNext 和 skipToPrevious 的位
        // ASkipToPrevious = 4, ASkipToNext = 5
        // (1 << 4) | (1 << 5) = 16 | 32 = 48
        // 这样即使 stopService 被调用，用户仍然可以使用灵动岛/锁屏的上一首/下一首按钮
        long preservedBits = (1 << ASkipToPrevious) | (1 << ASkipToNext);
        actionBits = preservedBits;
        NSLog(@"audio_service: stopService - preserved actionBits=%ld (skipToPrevious + skipToNext)", actionBits);

        [self updateControls];
        _controlsUpdated = NO;
        startResult = nil;
        // 重要修复：不要将 commandCenter 设为 nil
        // 否则下次 setState 时 updateControls 会因为 commandCenter == nil 而跳过
        // commandCenter = nil;
        NSLog(@"audio_service: stopService - completed, commandCenter preserved");
        result(@{});
    } else if ([@"forceUpdateNowPlayingInfo" isEqualToString:call.method]) {
        // 强制刷新 nowPlayingInfo，绕过 iOS 去重机制
        // 注意：现在主要依赖原生层的生命周期监听来触发刷新
        // 这个方法作为备用，仍可从 Dart 层调用
#if TARGET_OS_IPHONE
        [self forceRefreshNowPlayingInfo];
#endif
        result(@{});
    }
}

- (MPRemoteCommandHandlerStatus) play: (MPRemoteCommandEvent *) event {
    //NSLog(@"play");
    [handlerChannel invokeMethod:@"play" arguments:@{}];
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus) pause: (MPRemoteCommandEvent *) event {
    //NSLog(@"pause");
    [handlerChannel invokeMethod:@"pause" arguments:@{}];
    return MPRemoteCommandHandlerStatusSuccess;
}

- (BOOL)updateNowPlayingField:(NSString *)field value:(id)value {
    if (![value isEqual:nowPlayingInfo[field]]) {
        if (value != nil && value != [NSNull null]) {
            //NSLog(@"### %@ = '%@'", field, value);
            nowPlayingInfo[field] = value;
        } else {
            //NSLog(@"### %@ = nil", field);
            [nowPlayingInfo removeObjectForKey:field];
        }
        return YES;
    }
    return NO;
}

- (void) updateNowPlayingInfo {
    // 注意：Apple 推荐的做法是始终设置整个 nowPlayingInfo 字典
    // 参考: https://developer.apple.com/forums/thread/32475
    // "maintain a dictionary with the current info in your model object,
    //  and always set the entire dictionary"
    //
    // 原因：iOS 的去重机制会跳过"相同"的更新，但只有当我们实际调用
    // center.nowPlayingInfo = ... 时，iOS 才会重新评估是否显示灵动岛

    if (mediaItem) {
        [self updateNowPlayingField:MPMediaItemPropertyTitle value:mediaItem[@"title"]];
        [self updateNowPlayingField:MPMediaItemPropertyAlbumTitle value:mediaItem[@"album"]];
        [self updateNowPlayingField:MPMediaItemPropertyArtist value:mediaItem[@"artist"]];
        NSNumber *duration = mediaItem[@"duration"];
        if (duration == (id)[NSNull null]) duration = @(0);
        [self updateNowPlayingField:MPMediaItemPropertyPlaybackDuration value:([NSNumber numberWithDouble: ([duration doubleValue] / 1000)])];
        if (@available(iOS 3.0, macOS 10.13.2, *)) {
            [self updateNowPlayingField:MPMediaItemPropertyArtwork value:artwork];
        }
    }

    if (@available(iOS 10.0, macOS 10.12.2, *)) {
        [self updateNowPlayingField:MPNowPlayingInfoPropertyMediaType value:@(MPNowPlayingInfoMediaTypeAudio)];
    }
    [self updateNowPlayingField:MPNowPlayingInfoPropertyPlaybackRate value:(playing ? speed : [NSNumber numberWithDouble: 0.0])];
    [self updateNowPlayingField:MPNowPlayingInfoPropertyDefaultPlaybackRate value:(playing ? speed : [NSNumber numberWithDouble: 0.0])];
    [self updateNowPlayingField:MPNowPlayingInfoPropertyElapsedPlaybackTime value:[NSNumber numberWithDouble:([position doubleValue] / 1000)]];

    MPNowPlayingInfoCenter *center = [MPNowPlayingInfoCenter defaultCenter];

    // Fix for iOS: playbackState must be set on iOS 13+ for Dynamic Island and Control Center
    // See: https://github.com/ryanheise/audio_service/issues/1139
    if (@available(iOS 13.0, macOS 10.12.2, *)) {
        center.playbackState = playing ? MPNowPlayingPlaybackStatePlaying : MPNowPlayingPlaybackStatePaused;
    }

    if (@available(iOS 10.0, macOS 10.12.2, *)) {
        [self updateNowPlayingField:MPNowPlayingInfoPropertyIsLiveStream value:mediaItem[@"isLive"]];
    }

    // 始终设置 nowPlayingInfo，不检查是否有变化
    // 这是解决"第二次进入后台灵动岛不显示"问题的关键
    // iOS 系统会在内部处理去重，但只有当我们调用这个方法时，
    // 系统才会重新评估是否需要显示灵动岛
    center.nowPlayingInfo = nowPlayingInfo;
  
    // TODO: List of all unused "nowPlayingInfo" keys, we might want to use these at some point:
    //
    // * MPNowPlayingInfoCollectionIdentifier
    // * MPNowPlayingInfoPropertyAvailableLanguageOptions
    // * MPNowPlayingInfoPropertyAssetURL
    // * MPNowPlayingInfoPropertyChapterCount
    // * MPNowPlayingInfoPropertyChapterNumber
    // * MPNowPlayingInfoPropertyCurrentLanguageOptions
    // * MPNowPlayingInfoPropertyDefaultPlaybackRate
    // * MPNowPlayingInfoPropertyCurrentPlaybackDate
    // * MPNowPlayingInfoPropertyExternalContentIdentifier
    // * MPNowPlayingInfoPropertyExternalUserProfileIdentifier
    // * MPNowPlayingInfoPropertyPlaybackProgress
    // * MPNowPlayingInfoPropertyPlaybackQueueCount
    // * MPNowPlayingInfoPropertyPlaybackQueueIndex
    // * MPNowPlayingInfoPropertyServiceIdentifier
}

- (void) updateControls {
    if (!commandCenter) return;
    for (enum MediaAction action = AStop; action <= ASetSpeed; action++) {
        [self updateControl:action];
    }
    _controlsUpdated = YES;
}

- (void) updateControl:(enum MediaAction)action {
    MPRemoteCommand *command = commands[action];
    if (command == (id)[NSNull null]) return;
    // Shift the actionBits right until the least significant bit is the tested action bit, and AND that with a 1 at the same position.
    // All bytes become 0, other than the tested action bit, which will be 0 or 1 according to its status in the actionBits long.
    BOOL enable = ((actionBits >> action) & 1);

    // 尝试十八：在条件检查前添加日志，用于调试 Remote Command 注册
    if (action == ASkipToNext || action == ASkipToPrevious) {
        NSLog(@"audio_service: updateControl action=%ld enable=%d command.enabled=%d _controlsUpdated=%d",
              (long)action, enable, command.enabled, _controlsUpdated);
    }

    if (_controlsUpdated && enable == command.enabled) return;
    //NSLog(@"## updateControl %@ enable=%@", @(action), @(enable));
    [command setEnabled:enable];
    switch (action) {
        case AStop:
            if (enable) {
                [commandCenter.stopCommand addTarget:self action:@selector(stop:)];
            } else {
                [commandCenter.stopCommand removeTarget:nil];
            }
            break;
        case APause:
            if (enable) {
                [commandCenter.pauseCommand addTarget:self action:@selector(pause:)];
            } else {
                [commandCenter.pauseCommand removeTarget:nil];
            }
            break;
        case APlay:
            if (enable) {
                [commandCenter.playCommand addTarget:self action:@selector(play:)];
            } else {
                [commandCenter.playCommand removeTarget:nil];
            }
            break;
        case ARewind:
            if (rewindInterval.integerValue > 0) {
                if (enable) {
                    [commandCenter.skipBackwardCommand addTarget: self action:@selector(skipBackward:)];
                    int rewindIntervalInSeconds = [rewindInterval intValue]/1000;
                    NSNumber *rewindIntervalInSec = [NSNumber numberWithInt: rewindIntervalInSeconds];
                    commandCenter.skipBackwardCommand.preferredIntervals = @[rewindIntervalInSec];
                } else {
                    [commandCenter.skipBackwardCommand removeTarget:nil];
                }
            }
            break;
        case ASkipToPrevious:
            NSLog(@"audio_service: updateControl ASkipToPrevious enable=%d", enable);
            if (enable) {
                [commandCenter.previousTrackCommand addTarget:self action:@selector(previousTrack:)];
                NSLog(@"audio_service: previousTrackCommand registered with handler");
            } else {
                [commandCenter.previousTrackCommand removeTarget:nil];
                NSLog(@"audio_service: previousTrackCommand handler removed");
            }
            break;
        case ASkipToNext:
            NSLog(@"audio_service: updateControl ASkipToNext enable=%d", enable);
            if (enable) {
                [commandCenter.nextTrackCommand addTarget:self action:@selector(nextTrack:)];
                NSLog(@"audio_service: nextTrackCommand registered with handler");
            } else {
                [commandCenter.nextTrackCommand removeTarget:nil];
                NSLog(@"audio_service: nextTrackCommand handler removed");
            }
            break;
        case AFastForward:
            if (fastForwardInterval.integerValue > 0) {
                if (enable) {
                    [commandCenter.skipForwardCommand addTarget: self action:@selector(skipForward:)];
                    int fastForwardIntervalInSeconds = [fastForwardInterval intValue]/1000;
                    NSNumber *fastForwardIntervalInSec = [NSNumber numberWithInt: fastForwardIntervalInSeconds];
                    commandCenter.skipForwardCommand.preferredIntervals = @[fastForwardIntervalInSec];
                } else {
                    [commandCenter.skipForwardCommand removeTarget:nil];
                }
            }
            break;
        case ASetRating:
            // TODO:
            // commandCenter.ratingCommand
            // commandCenter.dislikeCommand
            // commandCenter.bookmarkCommand
            break;
        case ASeekTo:
            if (@available(iOS 9.1, macOS 10.12.2, *)) {
                if (enable) {
                    [commandCenter.changePlaybackPositionCommand addTarget:self action:@selector(changePlaybackPosition:)];
                } else {
                    [commandCenter.changePlaybackPositionCommand removeTarget:nil];
                }
            }
            break;
        case APlayPause:
            // Automatically enabled.
            break;
        case ASetRepeatMode:
            if (enable) {
                [commandCenter.changeRepeatModeCommand addTarget:self action:@selector(changeRepeatMode:)];
            } else {
                [commandCenter.changeRepeatModeCommand removeTarget:nil];
            }
            break;
        case ASetShuffleMode:
            if (enable) {
                [commandCenter.changeShuffleModeCommand addTarget:self action:@selector(changeShuffleMode:)];
            } else {
                [commandCenter.changeShuffleModeCommand removeTarget:nil];
            }
            break;
        case ASeekBackward:
            if (enable) {
                [commandCenter.seekBackwardCommand addTarget:self action:@selector(seekBackward:)];
            } else {
                [commandCenter.seekBackwardCommand removeTarget:nil];
            }
            break;
        case ASeekForward:
            if (enable) {
                [commandCenter.seekForwardCommand addTarget:self action:@selector(seekForward:)];
            } else {
                [commandCenter.seekForwardCommand removeTarget:nil];
            }
            break;
        case ASetSpeed:
            if (enable) {
//                [commandCenter.changePlaybackRateCommand setSupportedPlaybackRates:@[@(1),@(1.5),@(2)]]
                [commandCenter.changePlaybackRateCommand addTarget:self action:@selector(changePlaybackRate:)];
            } else {
                [commandCenter.changePlaybackRateCommand removeTarget:nil];
            }
            break;
        default:
            break;
    }
}

- (MPRemoteCommandHandlerStatus) togglePlayPause: (MPRemoteCommandEvent *) event {
    //NSLog(@"togglePlayPause");
    [handlerChannel invokeMethod:@"click" arguments:@{
        @"button":@(0)
    }];
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus) stop: (MPRemoteCommandEvent *) event {
    //NSLog(@"stop");
    [handlerChannel invokeMethod:@"stop" arguments:@{}];
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus) nextTrack: (MPRemoteCommandEvent *) event {
    NSLog(@"audio_service: ===== nextTrack command received from Dynamic Island/Lock Screen/Control Center =====");
    NSLog(@"audio_service: nextTrack - invoking skipToNext on handlerChannel (channel exists: %@)", handlerChannel ? @"YES" : @"NO");
    [handlerChannel invokeMethod:@"skipToNext" arguments:@{}];
    NSLog(@"audio_service: nextTrack - skipToNext invoked successfully");
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus) previousTrack: (MPRemoteCommandEvent *) event {
    NSLog(@"audio_service: ===== previousTrack command received from Dynamic Island/Lock Screen/Control Center =====");
    NSLog(@"audio_service: previousTrack - invoking skipToPrevious on handlerChannel (channel exists: %@)", handlerChannel ? @"YES" : @"NO");
    [handlerChannel invokeMethod:@"skipToPrevious" arguments:@{}];
    NSLog(@"audio_service: previousTrack - skipToPrevious invoked successfully");
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus) changePlaybackPosition: (MPChangePlaybackPositionCommandEvent *) event {
    //NSLog(@"changePlaybackPosition");
    [handlerChannel invokeMethod:@"seek" arguments: @{
        @"position":@((long long) (event.positionTime * 1000000.0))
    }];
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus) skipForward: (MPRemoteCommandEvent *) event {
    //NSLog(@"skipForward");
    [handlerChannel invokeMethod:@"fastForward" arguments:@{}];
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus) skipBackward: (MPRemoteCommandEvent *) event {
    //NSLog(@"skipBackward");
    [handlerChannel invokeMethod:@"rewind" arguments:@{}];
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus) seekForward: (MPSeekCommandEvent *) event {
    //NSLog(@"seekForward");
    BOOL begin = event.type == MPSeekCommandEventTypeBeginSeeking;
    [handlerChannel invokeMethod:@"seekForward" arguments:@{
        @"begin":@(begin)
    }];
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus) seekBackward: (MPSeekCommandEvent *) event {
    //NSLog(@"seekBackward");
    BOOL begin = event.type == MPSeekCommandEventTypeBeginSeeking;
    [handlerChannel invokeMethod:@"seekBackward" arguments:@{
        @"begin":@(begin)
    }];
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus) changeRepeatMode: (MPChangeRepeatModeCommandEvent *) event {
    //NSLog(@"changeRepeatMode");
    int modeIndex;
    switch (event.repeatType) {
        case MPRepeatTypeOff:
            modeIndex = 0;
            break;
        case MPRepeatTypeOne:
            modeIndex = 1;
            break;
        // MPRepeatTypeAll
        default:
            modeIndex = 2;
            break;
    }
    [handlerChannel invokeMethod:@"setRepeatMode" arguments:@{
        @"repeatMode":@(modeIndex)
    }];
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus) changePlaybackRate: (MPChangePlaybackRateCommandEvent *) event {
    //NSLog(@"changePlaybackRate");
    [handlerChannel invokeMethod:@"setSpeed" arguments:@{
        @"speed":@(event.playbackRate)
    }];
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus) changeShuffleMode: (MPChangeShuffleModeCommandEvent *) event {
    //NSLog(@"changeShuffleMode");
    int modeIndex;
    switch (event.shuffleType) {
        case MPShuffleTypeOff:
            modeIndex = 0;
            break;
        case MPShuffleTypeItems:
            modeIndex = 1;
            break;
        // MPShuffleTypeCollections
        default:
            modeIndex = 2;
            break;
    }
    [handlerChannel invokeMethod:@"setShuffleMode" arguments:@{
        @"shuffleMode":@(modeIndex)
    }];
    return MPRemoteCommandHandlerStatusSuccess;
}

#if TARGET_OS_IPHONE
/// 重新激活 AVAudioSession（尝试十四）
///
/// 日志分析发现：
/// - MXSession 的 ClientType = None，因为 ClientIsPlaying = STOPPED
/// - 这是因为 iOS 没有检测到 AudioToolbox 在播放
///
/// 解决方案：
/// 在返回前台和进入后台前，强制重新激活 AVAudioSession
/// 这会让 iOS 重新创建音频会话，并正确识别播放状态
- (void)reactivateAudioSession {
    NSError *error = nil;
    AVAudioSession *session = [AVAudioSession sharedInstance];

    // 设置 category 为 playback，确保后台播放
    [session setCategory:AVAudioSessionCategoryPlayback
                    mode:AVAudioSessionModeDefault
                 options:0
                   error:&error];
    if (error) {
        NSLog(@"audio_service: reactivateAudioSession setCategory failed: %@", error);
        error = nil;
    }

    // 激活音频会话
    BOOL success = [session setActive:YES error:&error];
    if (error) {
        NSLog(@"audio_service: reactivateAudioSession setActive failed: %@", error);
    } else {
        NSLog(@"audio_service: reactivateAudioSession success=%d", success);
    }
}

/// 重新激活 AVAudioSession 并刷新 nowPlayingInfo（尝试十四）
///
/// 在进入后台前调用，确保：
/// 1. AVAudioSession 处于激活状态
/// 2. NowPlayingInfo 被正确刷新
- (void)reactivateAudioSessionAndRefresh {
    NSLog(@"audio_service: reactivateAudioSessionAndRefresh starting");

    // 步骤1: 重新激活 AVAudioSession
    [self reactivateAudioSession];

    // 步骤2: 刷新 nowPlayingInfo
    [self forceRefreshNowPlayingInfo];

    NSLog(@"audio_service: reactivateAudioSessionAndRefresh completed");
}

/// 强制刷新 nowPlayingInfo，绕过 iOS 去重机制
/// 使用多种策略确保 iOS 正确显示灵动岛
///
/// 重要修复（2024-12-28）：
/// 之前错误地使用 Unix 时间戳作为 elapsedPlaybackTime，导致 iOS 认为
/// 播放位置超出歌曲时长，从而拒绝显示灵动岛。
/// 正确做法是使用当前播放位置（position 变量），加上微小偏移量绕过去重。
- (void)forceRefreshNowPlayingInfo {
    if (nowPlayingInfo == nil || nowPlayingInfo.count == 0) {
        NSLog(@"audio_service: forceRefreshNowPlayingInfo - no nowPlayingInfo to refresh");
        return;
    }

    forceUpdateCounter++;
    NSLog(@"audio_service: forceRefreshNowPlayingInfo starting (counter=%d, position=%@)",
          forceUpdateCounter, position);

    MPNowPlayingInfoCenter *center = [MPNowPlayingInfoCenter defaultCenter];

    // 重要：不要清空 nowPlayingInfo，否则会导致灵动岛闪烁
    // 重要：不要使用 Interrupted 状态，否则也会导致灵动岛闪烁

    // 策略1: 使用正确的播放位置 + 明显偏移量绕过 iOS 去重机制
    // position 是毫秒，需要转换为秒
    // 添加基于 counter 的偏移量（0.1 秒的倍数），确保每次调用都是唯一值
    // 使用 0.1 秒而不是 0.001 秒，因为 iOS 可能会忽略太小的变化
    double positionInSeconds = position ? [position doubleValue] / 1000.0 : 0.0;
    double offsetInSeconds = forceUpdateCounter * 0.1;  // 每次增加 100 毫秒偏移
    double elapsedTime = positionInSeconds + offsetInSeconds;
    nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = @(elapsedTime);

    // 策略2: 确保 playbackRate 正确
    nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = @(playing ? 1.0 : 0.0);

    // 策略3: 确保 Remote Commands 处于激活状态并注册处理程序
    // 重要修复（2024-12-28）：
    // 之前只调用 setEnabled:YES，但没有添加处理程序（addTarget:action:）
    // 这导致 updateControl: 方法的优化条件（enable == command.enabled）会跳过添加处理程序
    // 结果是 iOS 显示 enabled=YES handlers=[] - 命令启用但没有处理程序
    // 必须同时设置 enabled 和添加处理程序
    if (commandCenter) {
        [commandCenter.playCommand setEnabled:YES];
        [commandCenter.playCommand addTarget:self action:@selector(play:)];

        [commandCenter.pauseCommand setEnabled:YES];
        [commandCenter.pauseCommand addTarget:self action:@selector(pause:)];

        [commandCenter.togglePlayPauseCommand setEnabled:YES];
        [commandCenter.togglePlayPauseCommand addTarget:self action:@selector(togglePlayPause:)];

        [commandCenter.nextTrackCommand setEnabled:YES];
        [commandCenter.nextTrackCommand addTarget:self action:@selector(nextTrack:)];

        [commandCenter.previousTrackCommand setEnabled:YES];
        [commandCenter.previousTrackCommand addTarget:self action:@selector(previousTrack:)];

        NSLog(@"audio_service: forceRefreshNowPlayingInfo - Remote Commands re-registered");
    }

    // 策略4: 设置 nowPlayingInfo
    // 注意：直接设置，不要先清空或使用 Interrupted 状态
    center.nowPlayingInfo = nowPlayingInfo;

    // 策略5: 设置播放状态（不使用 Interrupted）
    if (@available(iOS 13.0, *)) {
        center.playbackState = playing ? MPNowPlayingPlaybackStatePlaying : MPNowPlayingPlaybackStatePaused;
    }

    NSLog(@"audio_service: forceRefreshNowPlayingInfo completed (playing=%d, elapsed=%.3f, counter=%d)",
          playing, elapsedTime, forceUpdateCounter);
}

// 注意：生命周期监听现在使用 block-based observers，
// 在 registerWithRegistrar 中注册，不再需要 selector-based 方法
#endif

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
