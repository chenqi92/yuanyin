import 'dart:io';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:logger/logger.dart';
import '../../../player/domain/entities/music_item.dart';

final _log = Logger(printer: SimplePrinter());

/// 支持的音频文件扩展名
const _audioExtensions = {
  '.mp3', '.flac', '.m4a', '.aac', '.wav', '.ogg', '.opus',
  '.ape', '.wma', '.aiff', '.aif', '.tta', '.dsf', '.dff',
  '.mka', '.wv', '.ncm',
};

/// 本地文件扫描器
///
/// 递归扫描指定目录，提取音频文件元数据并构建 MusicItem 列表。
class LocalFileScanner {
  /// 扫描指定目录下的所有音频文件
  ///
  /// [directoryPath] 扫描根目录
  /// [onProgress] 进度回调 (已扫描数, 当前文件名)
  /// 返回扫描到的歌曲列表
  Future<List<MusicItem>> scan(
    String directoryPath, {
    void Function(int count, String currentFile)? onProgress,
  }) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) {
      _log.w('扫描目录不存在: $directoryPath');
      return [];
    }

    final songs = <MusicItem>[];
    int count = 0;

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;

      final ext = _getExtension(entity.path);
      if (!_audioExtensions.contains(ext)) continue;

      count++;
      final fileName = entity.path.split('/').last;
      onProgress?.call(count, fileName);

      try {
        final item = await _parseAudioFile(entity);
        if (item != null) {
          songs.add(item);
        }
      } catch (e) {
        _log.w('解析文件失败: ${entity.path} - $e');
      }
    }

    _log.i('扫描完成: $directoryPath, 共 ${songs.length} 首歌曲');
    return songs;
  }

  /// 解析单个音频文件的元数据
  Future<MusicItem?> _parseAudioFile(File file) async {
    try {
      final metadata = readMetadata(file, getImage: false);

      final fileName = file.path.split('/').last;
      final nameWithoutExt = fileName.substring(0, fileName.lastIndexOf('.'));

      // 尝试从文件名解析艺术家和标题（格式: "艺术家 - 标题"）
      String fallbackTitle = nameWithoutExt;
      String? fallbackArtist;
      if (nameWithoutExt.contains(' - ')) {
        final parts = nameWithoutExt.split(' - ');
        fallbackArtist = parts[0].trim();
        fallbackTitle = parts.sublist(1).join(' - ').trim();
      }

      return MusicItem(
        id: file.path.hashCode.toRadixString(36),
        title: metadata.title ?? fallbackTitle,
        artist: metadata.artist ?? fallbackArtist ?? '未知艺术家',
        album: metadata.album ?? '未知专辑',
        duration: metadata.duration,
        filePath: file.path,
        fileSize: await file.length(),
        format: _getExtension(file.path).replaceFirst('.', '').toUpperCase(),
        year: metadata.year,
        trackNumber: metadata.trackNumber,
        genre: metadata.genres.isNotEmpty ? metadata.genres.first : null,
        bitrate: metadata.bitrate,
        sampleRate: metadata.sampleRate,
      );
    } catch (e) {
      _log.w('读取元数据失败: ${file.path} - $e');
      // 如果元数据读取失败，仍然创建基础 MusicItem
      final fileName = file.path.split('/').last;
      final nameWithoutExt = fileName.substring(0, fileName.lastIndexOf('.'));
      return MusicItem(
        id: file.path.hashCode.toRadixString(36),
        title: nameWithoutExt,
        artist: '未知艺术家',
        album: '未知专辑',
        filePath: file.path,
        fileSize: await file.length(),
        format: _getExtension(file.path).replaceFirst('.', '').toUpperCase(),
      );
    }
  }

  String _getExtension(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1) return '';
    return path.substring(dot).toLowerCase();
  }
}
