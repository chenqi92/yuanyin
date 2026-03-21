import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:logger/logger.dart';

final _log = Logger(printer: SimplePrinter());

/// iCloud 同步服务
///
/// 通过 MethodChannel 桥接 iOS 端的 NSUbiquitousKeyValueStore，
/// 实现收藏 ID 和歌单数据的 iCloud Key-Value Store 同步。
///
/// 需要在 Xcode 中启用 iCloud Key-Value Store entitlement。
class ICloudSyncService {
  static const _channel = MethodChannel('com.kkape.primuse/icloud');
  static const _boxName = 'icloud_sync';
  Box? _box;

  Future<Box> get _openBox async {
    _box ??= await Hive.openBox(_boxName);
    return _box!;
  }

  // ==================== 原生 KVS 桥接 ====================

  /// 写入 iCloud KVS
  Future<bool> _setKVS(String key, String value) async {
    try {
      final result = await _channel.invokeMethod<bool>('setKVS', {
        'key': key,
        'value': value,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      _log.w('iCloud KVS 写入失败: $e');
      return false;
    } on MissingPluginException {
      _log.w('iCloud MethodChannel 未注册（非 iOS 平台或 entitlement 未配置）');
      return false;
    }
  }

  /// 读取 iCloud KVS
  Future<String?> _getKVS(String key) async {
    try {
      return await _channel.invokeMethod<String>('getKVS', {'key': key});
    } on PlatformException catch (e) {
      _log.w('iCloud KVS 读取失败: $e');
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// 强制同步 iCloud KVS
  Future<bool> _syncKVS() async {
    try {
      final result = await _channel.invokeMethod<bool>('syncKVS');
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  // ==================== 收藏同步 ====================

  /// 导出收藏列表到 iCloud
  Future<bool> syncFavoritesToCloud() async {
    final ids = await exportFavoriteIds();
    final value = ids.join(',');
    final ok = await _setKVS('favorites', value);
    if (ok) {
      await _syncKVS();
      await setLastSyncTime();
      _log.i('收藏已同步到 iCloud: ${ids.length} 项');
    }
    return ok;
  }

  /// 从 iCloud 导入收藏列表
  Future<int> syncFavoritesFromCloud() async {
    final value = await _getKVS('favorites');
    if (value == null || value.isEmpty) return 0;
    final ids = value.split(',').where((s) => s.isNotEmpty).toList();
    await importFavoriteIds(ids);
    await setLastSyncTime();
    return ids.length;
  }

  /// 导出歌单到 iCloud
  Future<bool> syncPlaylistsToCloud() async {
    final playlists = await exportPlaylists();
    // 简单序列化：JSON 字符串
    final entries = <String>[];
    for (final pl in playlists) {
      final parts = <String>[];
      for (final entry in pl.entries) {
        final k = entry.key.toString().replaceAll('|', '\\|');
        final v = entry.value.toString().replaceAll('|', '\\|');
        parts.add('$k=$v');
      }
      entries.add(parts.join('|'));
    }
    final value = entries.join('\n');
    final ok = await _setKVS('playlists', value);
    if (ok) {
      await _syncKVS();
      _log.i('歌单已同步到 iCloud: ${playlists.length} 个');
    }
    return ok;
  }

  /// 执行完整同步（上传 + 下载合并）
  Future<void> fullSync() async {
    await syncFavoritesToCloud();
    await syncPlaylistsToCloud();
    await syncFavoritesFromCloud();
  }

  // ==================== Hive 数据操作 ====================

  /// 导出收藏列表
  Future<List<String>> exportFavoriteIds() async {
    final favBox = await Hive.openBox('favorites');
    return favBox.keys.cast<String>().toList();
  }

  /// 导入收藏列表
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

  /// 导入歌单数据
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
