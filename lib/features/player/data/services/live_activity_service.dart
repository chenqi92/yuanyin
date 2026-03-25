import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../player/domain/entities/music_item.dart';

/// 音乐播放器 Live Activity 服务
/// 用于在 iOS 灵动岛和锁屏上显示音乐播放状态
///
/// 使用自定义 Method Channel 实现，专为个人开发者账号设计
/// pushType: nil 避免 Push Notification 能力限制
class LiveActivityService {
  factory LiveActivityService() => _instance ??= LiveActivityService._();
  LiveActivityService._();

  static LiveActivityService? _instance;

  static const _channel = MethodChannel('com.kkape.primuse/music_live_activity');
  static const _eventChannel = EventChannel('com.kkape.primuse/music_live_activity_events');

  String? _currentActivityId;
  bool _initialized = false;

  /// 控制命令回调（来自灵动岛按钮点击）
  void Function(String action)? onControlAction;

  /// 当前封面数据
  Uint8List? _currentCoverData;

  /// 当前主题颜色（ARGB 格式）
  int? _currentThemeColor;

  StreamSubscription<dynamic>? _eventSubscription;

  bool get isSupported => Platform.isIOS;

  /// 初始化服务
  Future<void> init() async {
    if (_initialized) return;
    if (!isSupported) return;

    try {
      final enabled = await _channel.invokeMethod<bool>('areActivitiesEnabled') ?? false;
      debugPrint('LiveActivityService: areActivitiesEnabled=$enabled');

      _startListeningToControlCommands();

      _initialized = true;
      debugPrint('LiveActivityService: 初始化成功');
    } on PlatformException catch (e) {
      debugPrint('LiveActivityService: 初始化失败: $e');
    } on Exception catch (e) {
      debugPrint('LiveActivityService: 初始化失败: $e');
    }
  }

  void _startListeningToControlCommands() {
    _eventSubscription?.cancel();
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is String) {
          debugPrint('LiveActivityService: 收到灵动岛控制命令: $event');
          onControlAction?.call(event);
        }
      },
      onError: (Object error) {
        debugPrint('LiveActivityService: EventChannel 错误: $error');
      },
    );
  }

  /// 开始音乐播放的 Live Activity
  Future<void> startMusicActivity({
    required MusicItem music,
    required bool isPlaying,
    required Duration position,
    required Duration duration,
    Uint8List? coverData,
  }) async {
    if (!isSupported) return;

    if (!_initialized) {
      await init();
      if (!_initialized) return;
    }

    try {
      final enabled = await _channel.invokeMethod<bool>('areActivitiesEnabled') ?? false;
      if (!enabled) return;

      if (_currentActivityId != null) {
        if (coverData != null) _currentCoverData = coverData;
        await _forceUpdateActivity(
          music: music,
          isPlaying: isPlaying,
          position: position,
          duration: duration,
          coverData: coverData ?? _currentCoverData,
        );
        return;
      }

      _currentCoverData = coverData;

      final activityData = _buildActivityData(
        music: music,
        isPlaying: isPlaying,
        position: position,
        duration: duration,
        coverData: coverData,
      );

      _currentActivityId = await _channel.invokeMethod<String>(
        'createActivity',
        {'data': activityData},
      );

      debugPrint('LiveActivity: 创建成功, ID=$_currentActivityId');
    } on PlatformException catch (e) {
      debugPrint('LiveActivity: 创建失败: $e');
    } on Exception catch (e) {
      debugPrint('LiveActivity: 创建失败: $e');
    }
  }

  /// 更新 Live Activity 状态
  Future<void> updateActivity({
    required MusicItem music,
    required bool isPlaying,
    required Duration position,
    required Duration duration,
    Uint8List? coverData,
  }) async {
    if (!isSupported || !_initialized || _currentActivityId == null) return;

    try {
      if (coverData != null) _currentCoverData = coverData;

      final activityData = _buildActivityData(
        music: music,
        isPlaying: isPlaying,
        position: position,
        duration: duration,
        coverData: coverData,
      );

      await _channel.invokeMethod('updateActivity', {'data': activityData});
    } on PlatformException catch (e) {
      debugPrint('LiveActivity: 更新失败: $e');
    } on Exception catch (e) {
      debugPrint('LiveActivity: 更新失败: $e');
    }
  }

  /// 强制更新 Live Activity（切歌时使用）
  Future<void> _forceUpdateActivity({
    required MusicItem music,
    required bool isPlaying,
    required Duration position,
    required Duration duration,
    Uint8List? coverData,
  }) async {
    if (!isSupported || !_initialized || _currentActivityId == null) return;

    try {
      final activityData = _buildActivityData(
        music: music,
        isPlaying: isPlaying,
        position: position,
        duration: duration,
        coverData: coverData,
      );

      await _channel.invokeMethod('updateActivity', {'data': activityData});
      debugPrint('LiveActivity: 强制更新完成 - title=${music.title}');
    } on PlatformException catch (e) {
      debugPrint('LiveActivity: 强制更新失败: $e');
    } on Exception catch (e) {
      debugPrint('LiveActivity: 强制更新失败: $e');
    }
  }

  /// 结束 Live Activity
  Future<void> endActivity() async {
    if (!isSupported || !_initialized || _currentActivityId == null) return;

    try {
      await _channel.invokeMethod('endActivity');
      debugPrint('LiveActivity: 已结束, ID=$_currentActivityId');
      _currentActivityId = null;
      _currentCoverData = null;
    } on PlatformException catch (e) {
      debugPrint('LiveActivity: 结束失败: $e');
    } on Exception catch (e) {
      debugPrint('LiveActivity: 结束失败: $e');
    }
  }

  /// 结束所有 Live Activities
  Future<void> endAllActivities() async {
    if (!isSupported || !_initialized) return;

    try {
      await _channel.invokeMethod('endAllActivities');
      debugPrint('LiveActivity: 已结束所有活动');
      _currentActivityId = null;
      _currentCoverData = null;
    } on PlatformException catch (e) {
      debugPrint('LiveActivity: 结束所有活动失败: $e');
    } on Exception catch (e) {
      debugPrint('LiveActivity: 结束所有活动失败: $e');
    }
  }

  bool get isActivityRunning => _currentActivityId != null;

  /// 设置主题颜色
  void setThemeColor(Color color) {
    _currentThemeColor = color.toARGB32();
  }

  Map<String, dynamic> _buildActivityData({
    required MusicItem music,
    required bool isPlaying,
    required Duration position,
    required Duration duration,
    Uint8List? coverData,
  }) {
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    final data = <String, dynamic>{
      'title': music.title,
      'artist': music.artist,
      'album': music.album,
      'isPlaying': isPlaying,
      'progress': progress.clamp(0.0, 1.0),
      'currentTime': position.inSeconds,
      'totalTime': duration.inSeconds,
    };

    if (coverData != null && coverData.isNotEmpty) {
      data['coverImage'] = coverData;
    }

    if (_currentThemeColor != null) {
      data['themeColor'] = _currentThemeColor;
    }

    return data;
  }

  /// 更新封面图片
  Future<void> updateCoverImage(MusicItem music, Uint8List coverData) async {
    if (!isSupported || !_initialized || _currentActivityId == null) return;

    try {
      _currentCoverData = coverData;

      final activityData = <String, dynamic>{
        'title': music.title,
        'artist': music.artist,
        'album': music.album,
        'coverImage': coverData,
      };

      await _channel.invokeMethod('updateActivity', {'data': activityData});
      debugPrint('LiveActivity: 封面图片已更新');
    } on PlatformException catch (e) {
      debugPrint('LiveActivity: 更新封面图片失败: $e');
    } on Exception catch (e) {
      debugPrint('LiveActivity: 更新封面图片失败: $e');
    }
  }

  /// 强制刷新 Now Playing / 灵动岛
  Future<void> forceRefreshNowPlaying() async {
    if (!isSupported) return;

    try {
      await _channel.invokeMethod('forceRefreshNowPlaying');
      debugPrint('LiveActivityService: 强制刷新 Now Playing 完成');
    } on PlatformException catch (e) {
      debugPrint('LiveActivityService: 强制刷新失败: $e');
    } on Exception catch (e) {
      debugPrint('LiveActivityService: 强制刷新失败: $e');
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    await endAllActivities();
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    _initialized = false;
    _currentCoverData = null;
  }
}
