import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:logger/logger.dart';

final _log = Logger(printer: SimplePrinter());

/// iCloud 同步服务（基础版）
///
/// 当前使用 UserDefaults-based NSUbiquitousKeyValueStore 模式，
/// 同步收藏 ID 和歌单数据到 iCloud Key-Value Store (KVS)。
///
/// ⚠️ 需要 iOS/macOS entitlements 中启用 iCloud Key-Value Store。
/// ⚠️ Flutter 不提供原生 iCloud API，此服务通过 MethodChannel 桥接。
///
/// 当前此实现为 stub——仅定义接口和 Hive 导出工具，
/// 原生桥接需在 iOS/macOS 端实现。
class ICloudSyncService {
  static const _boxName = 'icloud_sync';
  Box? _box;

  Future<Box> get _openBox async {
    _box ??= await Hive.openBox(_boxName);
    return _box!;
  }

  /// 导出收藏列表（供 iCloud 同步使用）
  Future<List<String>> exportFavoriteIds() async {
    final favBox = await Hive.openBox('favorites');
    return favBox.keys.cast<String>().toList();
  }

  /// 导入收藏列表（从 iCloud 同步而来）
  Future<void> importFavoriteIds(List<String> ids) async {
    final favBox = await Hive.openBox('favorites');
    for (final id in ids) {
      if (!favBox.containsKey(id)) {
        await favBox.put(id, DateTime.now().millisecondsSinceEpoch);
      }
    }
    _log.i('iCloud 同步导入 ${ids.length} 个收藏项');
  }

  /// 导出歌单数据
  Future<List<Map<String, dynamic>>> exportPlaylists() async {
    final playlistBox = await Hive.openBox('playlists');
    final result = <Map<String, dynamic>>[];
    for (final key in playlistBox.keys) {
      final data = playlistBox.get(key);
      if (data is Map) {
        result.add(Map<String, dynamic>.from(data));
      }
    }
    return result;
  }

  /// 导入歌单数据（从 iCloud 同步而来，合并策略）
  Future<void> importPlaylists(List<Map<String, dynamic>> playlists) async {
    final playlistBox = await Hive.openBox('playlists');
    for (final pl in playlists) {
      final id = pl['id'] as String?;
      if (id != null && !playlistBox.containsKey(id)) {
        await playlistBox.put(id, pl);
      }
    }
    _log.i('iCloud 同步导入 ${playlists.length} 个歌单');
  }

  /// 获取最后同步时间
  Future<DateTime?> getLastSyncTime() async {
    final box = await _openBox;
    final ms = box.get('lastSync') as int?;
    if (ms != null) return DateTime.fromMillisecondsSinceEpoch(ms);
    return null;
  }

  /// 更新最后同步时间
  Future<void> setLastSyncTime() async {
    final box = await _openBox;
    await box.put('lastSync', DateTime.now().millisecondsSinceEpoch);
  }
}

/// Provider
final iCloudSyncProvider = Provider((ref) => ICloudSyncService());
