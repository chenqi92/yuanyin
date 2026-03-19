/*
 * FFmpegKit Flutter Plugin - macOS Stub Implementation
 * 
 * This is a stub implementation that compiles without FFmpegKit frameworks.
 * FFmpegKit official binaries have been retired as of January 2025.
 * 
 * For full functionality on macOS, you can:
 * 1. Build FFmpegKit from source: https://github.com/arthenica/ffmpeg-kit
 * 2. Use system ffmpeg via Homebrew: brew install ffmpeg
 */

#import "FFmpegKitFlutterPlugin.h"
#import <FlutterMacOS/FlutterMacOS.h>

static NSString *const PLATFORM_NAME = @"macos";
static NSString *const METHOD_CHANNEL = @"flutter.arthenica.com/ffmpeg_kit";
static NSString *const EVENT_CHANNEL = @"flutter.arthenica.com/ffmpeg_kit_event";

@implementation FFmpegKitFlutterPlugin {
  FlutterEventSink _eventSink;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    NSLog(@"FFmpegKitFlutterPlugin (stub) initialized. FFmpegKit frameworks not available on macOS.\n");
  }
  return self;
}

- (FlutterError *)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)eventSink {
  _eventSink = eventSink;
  return nil;
}

- (FlutterError *)onCancelWithArguments:(id)arguments {
  _eventSink = nil;
  return nil;
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FFmpegKitFlutterPlugin* instance = [[FFmpegKitFlutterPlugin alloc] init];

  FlutterMethodChannel* methodChannel = [FlutterMethodChannel methodChannelWithName:METHOD_CHANNEL binaryMessenger:[registrar messenger]];
  [registrar addMethodCallDelegate:instance channel:methodChannel];

  FlutterEventChannel* eventChannel = [FlutterEventChannel eventChannelWithName:EVENT_CHANNEL binaryMessenger:[registrar messenger]];
  [eventChannel setStreamHandler:instance];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  // Return error for all methods since FFmpegKit is not available
  NSString* method = call.method;
  
  if ([@"getPlatform" isEqualToString:method]) {
    result(PLATFORM_NAME);
  } else if ([@"getArch" isEqualToString:method]) {
    #if defined(__arm64__) || defined(__aarch64__)
      result(@"arm64");
    #elif defined(__x86_64__)
      result(@"x86_64");
    #else
      result(@"unknown");
    #endif
  } else if ([@"getFFmpegVersion" isEqualToString:method]) {
    result([FlutterError errorWithCode:@"NOT_AVAILABLE" 
                               message:@"FFmpegKit is not available on macOS. Use system ffmpeg via Homebrew instead." 
                               details:nil]);
  } else if ([@"getPackageName" isEqualToString:method]) {
    result(@"ffmpeg_kit_flutter_new");
  } else if ([@"getExternalLibraries" isEqualToString:method]) {
    result(@[]);
  } else {
    // For all other methods, return NOT_AVAILABLE error
    result([FlutterError errorWithCode:@"NOT_AVAILABLE" 
                               message:@"FFmpegKit frameworks not available on macOS. Build from source or use system ffmpeg." 
                               details:nil]);
  }
}

@end
