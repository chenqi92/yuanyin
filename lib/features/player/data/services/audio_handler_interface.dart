import 'dart:async';
import 'dart:typed_data';

import 'package:audio_service/audio_service.dart';
import '../../domain/entities/music_item.dart';

/// 音乐播放 AudioHandler 抽象接口
///
/// 统一 just_audio 和 media_kit 两种播放引擎的接口，
/// 使上层播放器不感知具体引擎实现。
abstract class IMusicAudioHandler extends BaseAudioHandler {
  // ==================== 播放器状态 ====================

  /// 当前封面数据
  Uint8List? get currentArtworkData;

  /// 当前音乐项
  MusicItem? get currentMusicItem;

  /// 当前队列索引
  int get currentIndex;

  /// 外部切歌回调
  set onSkipToIndex(Future<void> Function(int index)? callback);
  Future<void> Function(int index)? get onSkipToIndex;

  // ==================== 音频源设置 ====================

  /// 设置音频源
  Future<Duration?> setAudioSource(String url, {Map<String, String>? headers});

  /// 停止播放并释放当前音频源
  Future<void> stopPlayer();

  /// 跳转到指定位置
  Future<void> seekTo(Duration position);

  /// 设置当前播放的音乐
  Future<void> setCurrentMusic(MusicItem music, {Uint8List? artworkData});

  /// 更新封面图片
  Future<void> updateArtwork(Uint8List artworkData);

  /// 更新时长
  void updateDuration(Duration duration);

  // ==================== 播放队列 ====================

  /// 设置播放队列
  void setQueue(List<MusicItem> items, {int startIndex = 0});

  /// 更新当前索引
  void updateCurrentIndex(int index);

  // ==================== 播放控制扩展 ====================

  /// 设置音量 (0.0 - 1.0)
  Future<void> setVolume(double volume);

  /// 获取当前音量
  double get volume;

  /// 准备切换到新歌曲
  Future<void> prepareForNewTrack();

  /// 强制刷新 Now Playing / 灵动岛
  Future<void> refreshNowPlaying();

  // ==================== 流订阅 ====================

  /// 播放位置流
  Stream<Duration> get positionStream;

  /// 缓冲位置流
  Stream<Duration> get bufferedPositionStream;

  /// 时长流
  Stream<Duration> get durationStream;

  /// 播放状态流
  Stream<bool> get playingStream;

  /// 缓冲状态流
  Stream<bool> get bufferingStream;

  /// 播放完成流
  Stream<bool> get completedStream;

  // ==================== 资源管理 ====================

  /// 释放资源
  Future<void> dispose();
}

/// 播放引擎类型
enum MusicPlayerEngine {
  /// just_audio 引擎（平台原生解码器）
  justAudio,

  /// media_kit 引擎（FFmpeg/libmpv 解码）
  mediaKit,
}
