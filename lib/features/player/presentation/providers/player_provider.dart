import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/music_audio_handler.dart';
import '../../data/services/media_kit_audio_handler.dart';
import '../../data/services/audio_handler_interface.dart';
import '../../domain/entities/music_item.dart';
import '../../../library/presentation/providers/library_provider.dart';
import '../../../favorites/data/services/favorites_service.dart';
import '../../../settings/data/services/settings_service.dart';
import '../../../library/data/services/play_stats_service.dart';

/// 播放模式
enum PlayMode { loop, single, shuffle }

/// 播放器状态
class PlayerState {
  final MusicItem? currentSong;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final PlayMode playMode;
  final List<MusicItem> queue;
  final int queueIndex;
  final bool isFavorite;
  final double volume;
  final bool isBuffering;

  const PlayerState({
    this.currentSong,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.playMode = PlayMode.loop,
    this.queue = const [],
    this.queueIndex = 0,
    this.isFavorite = false,
    this.volume = 1.0,
    this.isBuffering = false,
  });

  PlayerState copyWith({
    MusicItem? currentSong,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    PlayMode? playMode,
    List<MusicItem>? queue,
    int? queueIndex,
    bool? isFavorite,
    double? volume,
    bool? isBuffering,
  }) {
    return PlayerState(
      currentSong: currentSong ?? this.currentSong,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      playMode: playMode ?? this.playMode,
      queue: queue ?? this.queue,
      queueIndex: queueIndex ?? this.queueIndex,
      isFavorite: isFavorite ?? this.isFavorite,
      volume: volume ?? this.volume,
      isBuffering: isBuffering ?? this.isBuffering,
    );
  }

  double get progress {
    if (duration.inMilliseconds == 0) return 0.0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  bool get hasSong => currentSong != null;
}

/// 播放器 StateNotifier
class PlayerNotifier extends StateNotifier<PlayerState> {
  IMusicAudioHandler? _audioHandler;
  final Ref _ref;
  final List<StreamSubscription> _subscriptions = [];
  String _currentEngine = 'justAudio';

  PlayerNotifier(this._audioHandler, this._ref) : super(const PlayerState()) {
    if (_audioHandler != null) {
      _setupStreams();
      // 同步交叉淡化设置
      final settings = _ref.read(settingsProvider);
      _currentEngine = settings.engine;
      if (_audioHandler is MusicAudioHandler) {
        (_audioHandler as MusicAudioHandler).setCrossfadeDuration(settings.crossfadeDuration);
      }
    }
  }

  /// 切换播放引擎
  Future<void> switchEngine(String engineName) async {
    if (engineName == _currentEngine) return;

    // 停止当前播放
    if (state.isPlaying) {
      _audioHandler?.pause();
    }

    // 释放旧的流订阅
    for (final sub in _subscriptions) { sub.cancel(); }
    _subscriptions.clear();

    // 保存当前状态（歌曲和队列）
    final savedSong = state.currentSong;
    final savedQueue = state.queue;
    final savedIndex = state.queueIndex;

    // 重置播放状态
    state = state.copyWith(
      isPlaying: false,
      position: Duration.zero,
      isBuffering: false,
    );

    // 创建新的音频 handler
    IMusicAudioHandler? newHandler;
    try {
      if (engineName == 'mediaKit') {
        newHandler = MediaKitAudioHandler();
      } else {
        newHandler = await initAudioHandler();
      }
    } catch (e) {
      debugPrint('切换引擎失败: $e');
      return;
    }

    // dispose 旧 handler
    try {
      await _audioHandler?.dispose();
    } catch (_) {}

    _audioHandler = newHandler;
    _currentEngine = engineName;

    // 更新全局 provider
    _ref.read(audioHandlerProvider.notifier).state = newHandler;

    // 重新设置流
    _setupStreams();

    // 恢复队列（不恢复播放位置）
    if (savedQueue.isNotEmpty && newHandler != null) {
      newHandler.setQueue(savedQueue, startIndex: savedIndex);
    }

    debugPrint('引擎已切换到: $engineName');
  }

  void _setupStreams() {
    final handler = _audioHandler!;

    _subscriptions.add(handler.positionStream.listen((pos) {
      if (mounted) state = state.copyWith(position: pos);
    }));

    _subscriptions.add(handler.durationStream.listen((dur) {
      if (mounted) state = state.copyWith(duration: dur);
    }));

    _subscriptions.add(handler.playingStream.listen((playing) {
      if (mounted) state = state.copyWith(isPlaying: playing);
    }));

    _subscriptions.add(handler.bufferingStream.listen((buffering) {
      if (mounted) state = state.copyWith(isBuffering: buffering);
    }));

    _subscriptions.add(handler.completedStream.listen((completed) {
      if (completed && mounted) _onTrackCompleted();
    }));

    handler.onSkipToIndex = (index) async {
      if (index >= 0 && index < state.queue.length) {
        await _playAtIndex(index);
      }
    };
  }

  /// 播放指定歌曲
  Future<void> playSong(MusicItem song, {List<MusicItem>? queue}) async {
    if (queue != null && queue.isNotEmpty) {
      final index = queue.indexWhere((s) => s.id == song.id);
      state = state.copyWith(queue: queue, queueIndex: index >= 0 ? index : 0);
      _audioHandler?.setQueue(queue, startIndex: index >= 0 ? index : 0);
      await _playAtIndex(index >= 0 ? index : 0);
    } else {
      final index = state.queue.indexWhere((s) => s.id == song.id);
      if (index != -1) {
        await _playAtIndex(index);
      } else {
        state = state.copyWith(
          currentSong: song,
          queue: [song],
          queueIndex: 0,
          position: Duration.zero,
          duration: song.duration ?? Duration.zero,
        );
        await _startPlayback(song);
      }
    }
  }

  Future<void> _playAtIndex(int index) async {
    if (index < 0 || index >= state.queue.length) return;
    final song = state.queue[index];
    state = state.copyWith(
      currentSong: song,
      queueIndex: index,
      position: Duration.zero,
      duration: song.duration ?? Duration.zero,
    );
    await _startPlayback(song);
    _audioHandler?.updateCurrentIndex(index);
  }

  Future<void> _startPlayback(MusicItem song) async {
    // 记录最近播放
    _ref.read(libraryProvider.notifier).recordPlay(song);

    // 记录播放统计
    _ref.read(playStatsProvider).recordPlay(song.id, duration: song.duration);

    // 检查收藏状态
    final isFav = await _ref.read(favoritesServiceProvider).isFavorite(song.id);
    state = state.copyWith(isFavorite: isFav);

    if (_audioHandler != null) {
      await _audioHandler!.prepareForNewTrack();
      await _audioHandler!.setCurrentMusic(song);
      if (song.filePath != null) {
        final uri = Uri.file(song.filePath!).toString();
        await _audioHandler!.setAudioSource(uri);
        await _audioHandler!.play();
      }
    } else {
      state = state.copyWith(isPlaying: true);
    }
  }

  void togglePlay() {
    if (!state.hasSong) return;
    if (_audioHandler != null) {
      state.isPlaying ? _audioHandler!.pause() : _audioHandler!.play();
    } else {
      state = state.copyWith(isPlaying: !state.isPlaying);
    }
  }

  void seek(Duration position) {
    _audioHandler?.seekTo(position);
    state = state.copyWith(position: position);
  }

  Future<void> next() async {
    if (state.queue.isEmpty) return;
    final nextIndex = (state.queueIndex + 1) % state.queue.length;
    await _playAtIndex(nextIndex);
  }

  Future<void> previous() async {
    if (state.queue.isEmpty) return;
    if (state.position.inSeconds > 3) { seek(Duration.zero); return; }
    final prevIndex = (state.queueIndex - 1 + state.queue.length) % state.queue.length;
    await _playAtIndex(prevIndex);
  }

  void cyclePlayMode() {
    const modes = PlayMode.values;
    final nextIndex = (state.playMode.index + 1) % modes.length;
    state = state.copyWith(playMode: modes[nextIndex]);
  }

  /// 切换收藏（持久化）
  Future<void> toggleFavorite() async {
    if (!state.hasSong) return;
    final favService = _ref.read(favoritesServiceProvider);
    final isFav = await favService.toggleFavorite(state.currentSong!.id);
    state = state.copyWith(isFavorite: isFav);
  }

  /// 重排队列
  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex--;
    final queue = [...state.queue];
    final item = queue.removeAt(oldIndex);
    queue.insert(newIndex, item);

    // 修正当前播放索引
    int newQueueIndex = state.queueIndex;
    if (oldIndex == state.queueIndex) {
      newQueueIndex = newIndex;
    } else if (oldIndex < state.queueIndex && newIndex >= state.queueIndex) {
      newQueueIndex--;
    } else if (oldIndex > state.queueIndex && newIndex <= state.queueIndex) {
      newQueueIndex++;
    }

    state = state.copyWith(queue: queue, queueIndex: newQueueIndex);
    _audioHandler?.setQueue(queue, startIndex: newQueueIndex);
  }

  /// 从队列移除
  void removeFromQueue(int index) {
    if (index < 0 || index >= state.queue.length) return;
    if (state.queue.length == 1) return; // 不允许移除最后一首
    final queue = [...state.queue];
    queue.removeAt(index);

    int newQueueIndex = state.queueIndex;
    if (index < state.queueIndex) {
      newQueueIndex--;
    } else if (index == state.queueIndex) {
      // 移除的是当前播放项，播放队列中的下一首
      if (newQueueIndex >= queue.length) newQueueIndex = 0;
      state = state.copyWith(queue: queue, queueIndex: newQueueIndex);
      _playAtIndex(newQueueIndex);
      return;
    }
    state = state.copyWith(queue: queue, queueIndex: newQueueIndex);
  }

  /// 下一首播放（插入到当前曲后面）
  void addNextInQueue(MusicItem song) {
    final queue = [...state.queue];
    final insertIndex = state.queueIndex + 1;
    queue.insert(insertIndex.clamp(0, queue.length), song);
    state = state.copyWith(queue: queue);
    _audioHandler?.setQueue(queue, startIndex: state.queueIndex);
  }

  void _onTrackCompleted() {
    switch (state.playMode) {
      case PlayMode.loop:
        next();
        break;
      case PlayMode.single:
        seek(Duration.zero);
        _audioHandler?.play();
        break;
      case PlayMode.shuffle:
        next();
        break;
    }
  }

  /// 设置音量
  void setVolume(double vol) {
    final clamped = vol.clamp(0.0, 1.0);
    state = state.copyWith(volume: clamped);
    _audioHandler?.setVolume(clamped);
    _ref.read(settingsProvider.notifier).setVolume(clamped);
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) { sub.cancel(); }
    super.dispose();
  }
}

/// 可变的 audioHandler provider（支持引擎运行时切换）
final audioHandlerProvider = StateProvider<IMusicAudioHandler?>((ref) => null);

final playerProvider =
    StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return PlayerNotifier(handler, ref);
});
