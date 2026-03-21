import 'package:hive_ce/hive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 搜索历史服务
///
/// 持久化最近搜索关键词，最多 20 条。
class SearchHistoryService {
  static const _boxName = 'search_history';
  static const _maxItems = 20;
  Box? _box;

  Future<Box> get _openBox async {
    _box ??= await Hive.openBox(_boxName);
    return _box!;
  }

  /// 获取搜索历史（最新在前）
  Future<List<String>> getHistory() async {
    final box = await _openBox;
    final items = <String>[];
    for (final key in box.keys.toList().reversed) {
      final value = box.get(key);
      if (value is String && !items.contains(value)) {
        items.add(value);
      }
    }
    return items.take(_maxItems).toList();
  }

  /// 添加搜索记录
  Future<void> addSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final box = await _openBox;

    // 删除重复
    final keysToRemove = <dynamic>[];
    for (final key in box.keys) {
      if (box.get(key) == q) keysToRemove.add(key);
    }
    await box.deleteAll(keysToRemove);

    // 添加新记录
    await box.put(DateTime.now().millisecondsSinceEpoch.toString(), q);

    // 限制数量
    while (box.length > _maxItems) {
      await box.delete(box.keys.first);
    }
  }

  /// 删除单条记录
  Future<void> removeSearch(String query) async {
    final box = await _openBox;
    final keysToRemove = <dynamic>[];
    for (final key in box.keys) {
      if (box.get(key) == query) keysToRemove.add(key);
    }
    await box.deleteAll(keysToRemove);
  }

  /// 清空全部历史
  Future<void> clearAll() async {
    final box = await _openBox;
    await box.clear();
  }
}

/// Provider
final searchHistoryProvider = Provider((ref) => SearchHistoryService());
