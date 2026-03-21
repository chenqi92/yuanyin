import 'dart:async';
import 'dart:typed_data';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/widgets.dart';
import 'package:logger/logger.dart';
import 'package:media_kit/media_kit.dart' as mk;

import '../../domain/entities/music_item.dart';
import 'audio_handler_interface.dart';

final _log = Logger(printer: SimplePrinter());

/// media_kit 播放引擎 (FFmpeg/libmpv)
///
/// 支持更多音频格式（DSD、APE 等），但不具备原生系统媒体控制集成，
/// 需通过 audio_service 手动桥接。
class MediaKitAudioHandler extends BaseAudioHandler
    with SeekHandler
    implements IMusicAudioHandler {
  MediaKitAudioHandler() {
    _init();
  }

  late final mk.Player _player;

  Uint8List? _currentArtworkData;
  MusicItem? _currentMusicItem;
  final List<MusicItem> _musicQueue = [];
  int _currentIndex = 0;
  double _volume = 1.0;
  double _crossfadeDuration = 0;

  // 流控制器
  final _positionCtrl = StreamController<Duration>.broadcast();
  final _durationCtrl = StreamController<Duration>.broadcast();
  final _playingCtrl = StreamController<bool>.broadcast();
  final _bufferingCtrl = StreamController<bool>.broadcast();
  final _completedCtrl = StreamController<bool>.broadcast();

  void _init() {
    mk.MediaKit.ensureInitialized();
    _player = mk.Player();

    // 桥接 media_kit 流到我们的接口
    _player.stream.position.listen((pos) {
      _positionCtrl.add(pos);
    });

    _player.stream.duration.listen((dur) {
      _durationCtrl.add(dur);
      if (dur > Duration.zero && mediaItem.value != null) {
        mediaItem.add(mediaItem.value!.copyWith(duration: dur));
      }
    });

    _player.stream.playing.listen((playing) {
      _playingCtrl.add(playing);
      _broadcastState(playing);
    });

    _player.stream.buffering.listen((buffering) {
      _bufferingCtrl.add(buffering);
    });

    _player.stream.completed.listen((completed) {
      _completedCtrl.add(completed);
    });

    _log.i('MediaKitAudioHandler: 初始化完成');
  }

  void _broadcastState(bool playing) {
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
      },
      playing: playing,
      updatePosition: _player.state.position,
      queueIndex: _currentIndex,
    ));
  }

  // ==================== IMusicAudioHandler ====================

  @override
  Uint8List? get currentArtworkData => _currentArtworkData;

  @override
  int get currentIndex => _currentIndex;

  @override
  MusicItem? get currentMusicItem => _currentMusicItem;

  @override
  Future<void> Function(int index)? onSkipToIndex;

  void setCrossfadeDuration(double seconds) {
    _crossfadeDuration = seconds;
  }

  @override
  Future<void> prepareForNewTrack() async {
    if (_player.state.playing) {
      await _player.pause();
    }
    _currentMusicItem = null;
    _currentArtworkData = null;
  }

  @override
  Future<void> setCurrentMusic(MusicItem music, {Uint8List? artworkData}) async {
    _currentMusicItem = music;
    _currentArtworkData = artworkData;

    mediaItem.add(MediaItem(
      id: music.id,
      title: music.title,
      artist: music.artist,
      album: music.album,
      duration: music.duration,
    ));

    _log.i('media_kit 设置音乐: ${music.title} - ${music.artist}');
  }

  @override
  Future<void> updateArtwork(Uint8List artworkData) async {
    _currentArtworkData = artworkData;
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

    queue.add(items
        .map((m) => MediaItem(
              id: m.id,
              title: m.title,
              artist: m.artist,
              album: m.album,
              duration: m.duration,
            ))
        .toList());
  }

  @override
  void updateCurrentIndex(int index) {
    _currentIndex = index;
    _broadcastState(_player.state.playing);
  }

  @override
  Future<Duration?> setAudioSource(String url, {Map<String, String>? headers}) async {
    await _player.open(mk.Media(url), play: false);
    // media_kit 的 duration 通过流异步返回
    return _player.state.duration;
  }

  @override
  Future<void> stopPlayer() async => await _player.stop();

  @override
  Future<void> seekTo(Duration position) async => await _player.seek(position);

  // ==================== 标准控制 ====================

  @override
  Future<void> play() async {
    await _player.play();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
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
    if (_player.state.position.inSeconds > 3) {
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
    await _player.setVolume(volume * 100); // media_kit 用 0-100
  }

  @override
  double get volume => _volume;

  @override
  Future<void> refreshNowPlaying() async {
    _broadcastState(_player.state.playing);
  }

  // ==================== Streams ====================

  @override
  Stream<Duration> get positionStream => _positionCtrl.stream;

  @override
  Stream<Duration> get bufferedPositionStream =>
      Stream.value(Duration.zero); // media_kit 不提供 buffered position

  @override
  Stream<Duration> get durationStream => _durationCtrl.stream;

  @override
  Stream<bool> get playingStream => _playingCtrl.stream;

  @override
  Stream<bool> get bufferingStream => _bufferingCtrl.stream;

  @override
  Stream<bool> get completedStream => _completedCtrl.stream;

  @override
  Future<void> dispose() async {
    await _player.dispose();
    await _positionCtrl.close();
    await _durationCtrl.close();
    await _playingCtrl.close();
    await _bufferingCtrl.close();
    await _completedCtrl.close();
  }
}
