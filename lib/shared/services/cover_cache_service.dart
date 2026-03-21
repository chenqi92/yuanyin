import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:logger/logger.dart';

final _log = Logger(printer: SimplePrinter());

/// 封面缓存服务
///
/// 将音频文件中提取的封面图片缓存到磁盘，
/// 避免每次都重新解析音频文件。
class CoverCacheService {
  String? _cacheDir;

  /// 获取缓存目录
  Future<String> get _dir async {
    if (_cacheDir != null) return _cacheDir!;
    final appDir = await getApplicationSupportDirectory();
    _cacheDir = p.join(appDir.path, 'cover_cache');
    await Directory(_cacheDir!).create(recursive: true);
    return _cacheDir!;
  }

  /// 保存封面到缓存
  ///
  /// 返回缓存文件路径
  Future<String?> saveCover(String songId, Uint8List imageData) async {
    if (imageData.isEmpty) return null;
    try {
      final dir = await _dir;
      // 检测图片格式并决定扩展名
      final ext = _detectImageExt(imageData);
      final filePath = p.join(dir, '$songId.$ext');
      final file = File(filePath);
      if (await file.exists()) return filePath; // 已缓存
      await file.writeAsBytes(imageData);
      return filePath;
    } catch (e) {
      _log.w('保存封面失败 ($songId): $e');
      return null;
    }
  }

  /// 获取缓存封面路径（仅检查是否存在）
  Future<String?> getCoverPath(String songId) async {
    final dir = await _dir;
    for (final ext in ['jpg', 'png', 'webp']) {
      final file = File(p.join(dir, '$songId.$ext'));
      if (await file.exists()) return file.path;
    }
    return null;
  }

  /// 通过 MIME 前缀检测图片格式
  String _detectImageExt(Uint8List data) {
    if (data.length >= 3 && data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF) {
      return 'jpg';
    }
    if (data.length >= 8 && data[0] == 0x89 && data[1] == 0x50 &&
        data[2] == 0x4E && data[3] == 0x47) {
      return 'png';
    }
    if (data.length >= 4 && data[0] == 0x52 && data[1] == 0x49 &&
        data[2] == 0x46 && data[3] == 0x46) {
      return 'webp';
    }
    return 'jpg'; // 默认
  }

  /// 清空所有缓存
  Future<void> clearAll() async {
    final dir = await _dir;
    final d = Directory(dir);
    if (await d.exists()) {
      await d.delete(recursive: true);
      await d.create(recursive: true);
    }
  }
}

/// Provider
final coverCacheProvider = Provider((ref) => CoverCacheService());
