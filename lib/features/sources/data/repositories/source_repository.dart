import 'package:hive_ce/hive.dart';
import 'package:logger/logger.dart';
import '../../domain/entities/source_entity.dart';

final _log = Logger(printer: SimplePrinter());

/// 数据源 Repository
///
/// 使用 Hive 持久化数据源配置信息。
class SourceRepository {
  static const _boxName = 'sources';
  Box? _box;

  Future<Box> get _openBox async {
    _box ??= await Hive.openBox(_boxName);
    return _box!;
  }

  /// 获取所有数据源
  Future<List<SourceEntity>> getAll() async {
    final box = await _openBox;
    final sources = <SourceEntity>[];
    for (final key in box.keys) {
      try {
        final map = box.get(key);
        if (map is Map) {
          sources.add(SourceEntity.fromMap(map));
        }
      } catch (e) {
        _log.w('读取数据源失败: $key - $e');
      }
    }
    return sources;
  }

  /// 添加数据源
  Future<void> add(SourceEntity source) async {
    final box = await _openBox;
    await box.put(source.id, source.toMap());
    _log.i('添加数据源: ${source.name} (${source.typeDisplayName})');
  }

  /// 更新数据源
  Future<void> update(SourceEntity source) async {
    final box = await _openBox;
    await box.put(source.id, source.toMap());
  }

  /// 删除数据源
  Future<void> delete(String id) async {
    final box = await _openBox;
    await box.delete(id);
    _log.i('删除数据源: $id');
  }

  /// 根据 ID 获取
  Future<SourceEntity?> getById(String id) async {
    final box = await _openBox;
    final map = box.get(id);
    if (map is Map) {
      return SourceEntity.fromMap(map);
    }
    return null;
  }
}
