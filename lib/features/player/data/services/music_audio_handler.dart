import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logger/logger.dart';

import '../../domain/entities/music_item.dart';
import 'audio_handler_interface.dart';

final _log = Logger(printer: SimplePrinter());

/// just_audio 播放引擎
///
/// 基于 AVFoundation (iOS) / ExoPlayer (Android)，
/// 深度集成系统媒体控制：锁屏、控制中心、蓝牙、CarPlay。
class MusicAudioHandler extends BaseAudioHandler
    with SeekHandler, WidgetsBindingObserver
    implements IMusicAudioHandler {
  MusicAudioHandler() {
    _init();
  }

  AudioPlayer _player = AudioPlayer();
  AudioPlayer? _playerB; // 交叉淡化第二播放器

  // Android 均衡器
  AndroidEqualizer? _androidEqualizer;
  bool _eqEnabled = false;

  Uint8List? _currentArtworkData;
  MusicItem? _currentMusicItem;
  final List<MusicItem> _musicQueue = [];
  int _currentIndex = 0;
  double _volume = 1.0;
  double _crossfadeDuration = 0; // 秒，0 = 关闭
  Timer? _fadeTimer;

  AudioPlayer get player => _player;

  @override
  Uint8List? get currentArtworkData => _currentArtworkData;

  @override
  int get currentIndex => _currentIndex;

  @override
  MusicItem? get currentMusicItem => _currentMusicItem;

  @override
  Future<void> Function(int index)? onSkipToIndex;

  Future<void> _init() async {
    // 延迟注册生命周期监听器
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addObserver(this);
    });

    // 监听播放状态变化，更新 playbackState
    _player.playbackEventStream.listen(_broadcastState);

    // 监听时长变化
    _player.durationStream.listen((duration) {
      if (duration != null && mediaItem.value != null) {
        mediaItem.add(mediaItem.value!.copyWith(duration: duration));
      }
    });

    // 广播初始 playbackState
    _broadcastState(PlaybackEvent());

    // 初始化 Android 均衡器
    if (Platform.isAndroid) {
      _androidEqualizer = AndroidEqualizer();
      _player = AudioPlayer(
        audioPipeline: AudioPipeline(androidAudioEffects: [_androidEqualizer!]),
      );
      // 重新绑定流
      _player.playbackEventStream.listen(_broadcastState);
      _player.durationStream.listen((duration) {
        if (duration != null && mediaItem.value != null) {
          mediaItem.add(mediaItem.value!.copyWith(duration: duration));
        }
      });
    }

    _log.i('MusicAudioHandler: 初始化完成');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _player.playing && Platform.isIOS) {
      unawaited(_reactivateAudioSession());
    }
  }

  Future<void> _reactivateAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.setActive(true);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (_player.playing && mediaItem.value != null) {
        _broadcastStateWithPlaying(true);
      }
    } on Exception catch (e) {
      _log.w('重新激活 AudioSession 失败: $e');
    }
  }

  void _broadcastStateWithPlaying(bool playing) {
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: _mapProcessingState(_player.processingState),
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: _currentIndex,
    ));
  }

  void _broadcastState(PlaybackEvent event) {
    _broadcastStateWithPlaying(_player.playing);
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  // ==================== 交叉淡化 ====================

  /// 设置交叉淡化时长（秒）
  void setCrossfadeDuration(double seconds) {
    _crossfadeDuration = seconds;
  }

  /// 执行交叉淡化切歌
  Future<void> _crossfadeToNew(String url) async {
    final fadeDurationMs = (_crossfadeDuration * 1000).toInt();
    const stepMs = 50;
    final steps = fadeDurationMs ~/ stepMs;
    if (steps <= 0) return;

    // 准备新播放器
    _playerB ??= AudioPlayer();
    await _playerB!.setAudioSource(AudioSource.uri(Uri.parse(url)));
    await _playerB!.setVolume(0);
    unawaited(_playerB!.play());

    // 渐变：旧淡出 + 新淡入
    int step = 0;
    _fadeTimer?.cancel();
    _fadeTimer = Timer.periodic(Duration(milliseconds: stepMs), (timer) {
      step++;
      final progress = (step / steps).clamp(0.0, 1.0);
      _player.setVolume((1.0 - progress) * _volume);
      _playerB?.setVolume(progress * _volume);

      if (step >= steps) {
        timer.cancel();
        final oldPlayer = _player;
        _player = _playerB!;
        _playerB = oldPlayer;
        _playerB!.stop();
        // 重新连接流
        _reconnectStreams();
      }
    });
  }

  void _reconnectStreams() {
    // playbackEvent 流已自动绑定到当前 _player 实例
    _player.playbackEventStream.listen(_broadcastState);
    _player.durationStream.listen((duration) {
      if (duration != null && mediaItem.value != null) {
        mediaItem.add(mediaItem.value!.copyWith(duration: duration));
      }
    });
  }

  // ==================== IMusicAudioHandler ====================

  @override
  Future<void> prepareForNewTrack() async {
    _fadeTimer?.cancel();
    if (_player.playing) {
      await _player.pause();
      _broadcastState(PlaybackEvent());
    }
    _currentMusicItem = null;
    _currentArtworkData = null;
  }

  @override
  Future<void> setCurrentMusic(MusicItem music, {Uint8List? artworkData}) async {
    _currentMusicItem = music;
    _currentArtworkData = artworkData;

    final item = MediaItem(
      id: music.id,
      title: music.title,
      artist: music.artist,
      album: music.album,
      duration: music.duration,
    );

    mediaItem.add(item);
    _broadcastState(PlaybackEvent());

    _log.i('设置当前音乐: ${music.title} - ${music.artist}');
  }

  @override
  Future<void> updateArtwork(Uint8List artworkData) async {
    _currentArtworkData = artworkData;
    if (mediaItem.value != null) {
      _broadcastState(PlaybackEvent());
    }
  }

  @override
  void updateDuration(Duration duration) {
    if (mediaItem.value != null && duration > Duration.zero) {
      mediaItem.add(mediaItem.value!.copyWith(duration: duration));
    }
  }

  @override
  void setQueue(List<MusicItem> items, {int startIndex = 0}) {
    _musicQueue
      ..clear()
      ..addAll(items);
    _currentIndex = startIndex;

    final mediaItems = items
        .map((m) => MediaItem(
              id: m.id,
              title: m.title,
              artist: m.artist,
              album: m.album,
              duration: m.duration,
            ))
        .toList();
    queue.add(mediaItems);
  }

  @override
  void updateCurrentIndex(int index) {
    _currentIndex = index;
    _broadcastState(PlaybackEvent());
  }

  @override
  Future<Duration?> setAudioSource(String url, {Map<String, String>? headers}) async {
    // 如果启用了交叉淡化且当前正在播放，使用交叉淡化
    if (_crossfadeDuration > 0 && _player.playing) {
      await _crossfadeToNew(url);
      return _player.duration;
    }

    final uri = Uri.parse(url);
    AudioSource audioSource;

    if (uri.scheme == 'file') {
      audioSource = AudioSource.uri(uri);
    } else if (headers != null && headers.isNotEmpty) {
      audioSource = AudioSource.uri(uri, headers: headers);
    } else {
      audioSource = AudioSource.uri(uri);
    }

    return _player.setAudioSource(audioSource);
  }

  @override
  Future<void> stopPlayer() => _player.stop();

  @override
  Future<void> seekTo(Duration position) => _player.seek(position);

  // ==================== 标准控制 ====================

  @override
  Future<void> play() async {
    unawaited(_player.play());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    _broadcastState(PlaybackEvent());
  }

  @override
  Future<void> pause() async {
    unawaited(_player.pause());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    _broadcastState(PlaybackEvent());
  }

  @override
  Future<void> stop() async {
    unawaited(_player.stop());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    _broadcastState(PlaybackEvent());
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
    _broadcastState(PlaybackEvent());
  }

  @override
  Future<void> skipToNext() async {
    if (_musicQueue.isEmpty) return;
    final nextIndex = (_currentIndex + 1) % _musicQueue.length;
    await _skipToIndex(nextIndex);
  }

  @override
  Future<void> skipToPrevious() async {
    if (_musicQueue.isEmpty) return;
    if (_player.position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }
    final prevIndex = (_currentIndex - 1 + _musicQueue.length) % _musicQueue.length;
    await _skipToIndex(prevIndex);
  }

  Future<void> _skipToIndex(int index) async {
    if (index < 0 || index >= _musicQueue.length) return;
    _currentIndex = index;
    if (onSkipToIndex != null) {
      await onSkipToIndex!(index);
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume;
    await _player.setVolume(volume);
  }

  @override
  double get volume => _volume;

  @override
  Future<void> refreshNowPlaying() async {
    _broadcastState(PlaybackEvent());
  }

  // ==================== Streams ====================

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;

  @override
  Stream<Duration> get durationStream =>
      _player.durationStream.where((d) => d != null).map((d) => d!);

  @override
  Stream<bool> get playingStream => _player.playingStream;

  @override
  Stream<bool> get bufferingStream => _player.processingStateStream.map((state) =>
      state == ProcessingState.buffering || state == ProcessingState.loading);

  @override
  Stream<bool> get completedStream => _player.processingStateStream
      .map((state) => state == ProcessingState.completed)
      .distinct();

  @override
  Future<void> dispose() async {
    _fadeTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    await _player.dispose();
    await _playerB?.dispose();
  }

  // ==================== 均衡器 ====================

  /// 设置均衡器增益
  ///
  /// Android: 通过 AndroidEqualizer 应用
  /// iOS: just_audio 不支持原生 EQ，静默跳过
  Future<void> setEqualizerGains(List<double> gains, bool enabled) async {
    _eqEnabled = enabled;
    if (Platform.isAndroid && _androidEqualizer != null) {
      await _androidEqualizer!.setEnabled(enabled);
      if (enabled) {
        final params = await _androidEqualizer!.parameters;
        final bands = params.bands;
        for (int i = 0; i < bands.length && i < gains.length; i++) {
          // AndroidEqualizer 增益范围通常是 -1500 到 +1500 (毫贝尔)
          // 我们的增益范围是 -12 到 +12 dB，换算: dB * 100 = 毫贝尔
          final gainMb = (gains[i] * 100).round();
          final minLevel = params.minDecibels.round() * 100;
          final maxLevel = params.maxDecibels.round() * 100;
          final clampedGain = gainMb.clamp(minLevel, maxLevel);
          await bands[i].setGain(clampedGain.toDouble() / 100);
        }
      }
    }
    // iOS: 静默跳过（just_audio 不支持 DarwinEqualizer）
  }
}

/// 全局 AudioHandler 初始化
Future<MusicAudioHandler> initAudioHandler() => AudioService.init(
      builder: MusicAudioHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.kkape.primuse.channel.audio',
        androidNotificationChannelName: 'Primuse 播放',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
