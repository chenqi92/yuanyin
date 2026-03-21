import 'package:hive_ce/hive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 播放统计服务
///
/// 记录每首歌的播放次数和累计时长。
class PlayStatsService {
  static const _boxName = 'play_stats';
  Box? _box;

  Future<Box> get _openBox async {
    _box ??= await Hive.openBox(_boxName);
    return _box!;
  }

  /// 记录一次播放
  Future<void> recordPlay(String songId, {Duration? duration}) async {
    final box = await _openBox;
    final existing = box.get(songId);
    if (existing is Map) {
      final map = Map<String, dynamic>.from(existing);
      map['playCount'] = ((map['playCount'] as int?) ?? 0) + 1;
      map['totalMs'] = ((map['totalMs'] as int?) ?? 0) + (duration?.inMilliseconds ?? 0);
      map['lastPlayed'] = DateTime.now().millisecondsSinceEpoch;
      await box.put(songId, map);
    } else {
      await box.put(songId, {
        'playCount': 1,
        'totalMs': duration?.inMilliseconds ?? 0,
        'lastPlayed': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  /// 获取单首歌的统计
  Future<SongPlayStats?> getStats(String songId) async {
    final box = await _openBox;
    final data = box.get(songId);
    if (data is Map) {
      return SongPlayStats(
        songId: songId,
        playCount: (data['playCount'] as int?) ?? 0,
        totalDuration: Duration(milliseconds: (data['totalMs'] as int?) ?? 0),
        lastPlayed: data['lastPlayed'] != null
            ? DateTime.fromMillisecondsSinceEpoch(data['lastPlayed'] as int)
            : null,
      );
    }
    return null;
  }

  /// 获取播放次数排行（按播放次数降序）
  Future<List<SongPlayStats>> getTopPlayed({int limit = 50}) async {
    final box = await _openBox;
    final stats = <SongPlayStats>[];
    for (final key in box.keys) {
      final data = box.get(key);
      if (data is Map) {
        stats.add(SongPlayStats(
          songId: key as String,
          playCount: (data['playCount'] as int?) ?? 0,
          totalDuration: Duration(milliseconds: (data['totalMs'] as int?) ?? 0),
          lastPlayed: data['lastPlayed'] != null
              ? DateTime.fromMillisecondsSinceEpoch(data['lastPlayed'] as int)
              : null,
        ));
      }
    }
    stats.sort((a, b) => b.playCount.compareTo(a.playCount));
    return stats.take(limit).toList();
  }

  /// 获取总体统计
  Future<OverallStats> getOverallStats() async {
    final box = await _openBox;
    int totalPlays = 0;
    int totalMs = 0;
    for (final key in box.keys) {
      final data = box.get(key);
      if (data is Map) {
        totalPlays += (data['playCount'] as int?) ?? 0;
        totalMs += (data['totalMs'] as int?) ?? 0;
      }
    }
    return OverallStats(
      totalPlays: totalPlays,
      totalDuration: Duration(milliseconds: totalMs),
      uniqueSongs: box.length,
    );
  }
}

/// 单首歌播放统计
class SongPlayStats {
  final String songId;
  final int playCount;
  final Duration totalDuration;
  final DateTime? lastPlayed;

  const SongPlayStats({
    required this.songId,
    required this.playCount,
    required this.totalDuration,
    this.lastPlayed,
  });
}

/// 总体播放统计
class OverallStats {
  final int totalPlays;
  final Duration totalDuration;
  final int uniqueSongs;
  const OverallStats({required this.totalPlays, required this.totalDuration, required this.uniqueSongs});

  String get totalDurationText {
    final hours = totalDuration.inHours;
    final minutes = totalDuration.inMinutes % 60;
    if (hours > 0) return '$hours 小时 $minutes 分钟';
    return '$minutes 分钟';
  }
}

/// Provider
final playStatsProvider = Provider((ref) => PlayStatsService());
