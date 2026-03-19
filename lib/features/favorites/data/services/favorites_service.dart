import 'package:hive_ce/hive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 收藏服务
///
/// 使用 Hive 持久化收藏歌曲 ID 列表。
class FavoritesService {
  static const _boxName = 'favorites';
  Box? _box;

  Future<Box> get _openBox async {
    _box ??= await Hive.openBox(_boxName);
    return _box!;
  }

  /// 是否已收藏
  Future<bool> isFavorite(String songId) async {
    final box = await _openBox;
    return box.containsKey(songId);
  }

  /// 切换收藏
  Future<bool> toggleFavorite(String songId) async {
    final box = await _openBox;
    if (box.containsKey(songId)) {
      await box.delete(songId);
      return false;
    } else {
      await box.put(songId, DateTime.now().millisecondsSinceEpoch);
      return true;
    }
  }

  /// 获取所有收藏 ID
  Future<List<String>> getAllFavoriteIds() async {
    final box = await _openBox;
    return box.keys.cast<String>().toList();
  }

  /// 获取收藏数量
  Future<int> count() async {
    final box = await _openBox;
    return box.length;
  }
}

/// 收藏服务 Provider
final favoritesServiceProvider = Provider((ref) => FavoritesService());
