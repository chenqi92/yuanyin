import 'dart:io';
import 'dart:typed_data';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../../../shared/utils/cover_art_resolver.dart';
import '../../../player/domain/entities/music_item.dart';

final _log = Logger(printer: SimplePrinter());

/// 支持的音频文件扩展名
const _audioExtensions = {
  '.mp3',
  '.flac',
  '.m4a',
  '.aac',
  '.wav',
  '.ogg',
  '.opus',
  '.ape',
  '.wma',
  '.aiff',
  '.aif',
  '.tta',
  '.dsf',
  '.dff',
  '.mka',
  '.wv',
  '.ncm',
};

/// 本地文件扫描器
///
/// 递归扫描指定目录，提取音频文件元数据（含封面）并构建 MusicItem 列表。
class LocalFileScanner {
  String? _coverCacheDir;

  /// 获取封面缓存目录
  Future<String> _ensureCoverCacheDir() async {
    if (_coverCacheDir != null) return _coverCacheDir!;
    final appDir = await getApplicationSupportDirectory();
    _coverCacheDir = p.join(appDir.path, 'cover_cache');
    await Directory(_coverCacheDir!).create(recursive: true);
    return _coverCacheDir!;
  }

  /// 扫描指定目录下的所有音频文件
  Future<List<MusicItem>> scan(
    String directoryPath, {
    void Function(int count, String currentFile)? onProgress,
  }) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) {
      _log.w('扫描目录不存在: $directoryPath');
      return [];
    }

    // 预先初始化封面缓存目录
    await _ensureCoverCacheDir();

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

  /// 解析单个音频文件的元数据（含封面提取）
  Future<MusicItem?> _parseAudioFile(File file) async {
    try {
      // ★ getImage: true — 提取嵌入封面
      final metadata = readMetadata(file, getImage: true);

      final fileName = file.path.split('/').last;
      final nameWithoutExt = fileName.substring(0, fileName.lastIndexOf('.'));

      // 从文件名解析艺术家和标题
      String fallbackTitle = nameWithoutExt;
      String? fallbackArtist;
      if (nameWithoutExt.contains(' - ')) {
        final parts = nameWithoutExt.split(' - ');
        fallbackArtist = parts[0].trim();
        fallbackTitle = parts.sublist(1).join(' - ').trim();
      }

      final songId = file.path.hashCode.toRadixString(36);

      // 优先使用同名封面文件，其次才回退到嵌入封面
      String? coverUrl = await _findCompanionCover(file);
      if (coverUrl == null && metadata.pictures.isNotEmpty) {
        final picture = metadata.pictures.first;
        coverUrl = await _saveCover(songId, picture.bytes);
      }

      return MusicItem(
        id: songId,
        title: metadata.title ?? fallbackTitle,
        artist: metadata.artist ?? fallbackArtist ?? '未知艺术家',
        album: metadata.album ?? '未知专辑',
        duration: metadata.duration,
        coverUrl: coverUrl,
        filePath: file.path,
        fileSize: await file.length(),
        format: _getExtension(file.path).replaceFirst('.', '').toUpperCase(),
        year: metadata.year?.year,
        trackNumber: metadata.trackNumber,
        genre: metadata.genres.isNotEmpty ? metadata.genres.first : null,
        bitrate: metadata.bitrate,
        sampleRate: metadata.sampleRate,
      );
    } catch (e) {
      _log.w('读取元数据失败: ${file.path} - $e');
      final fileName = file.path.split('/').last;
      final nameWithoutExt = fileName.substring(0, fileName.lastIndexOf('.'));
      final coverUrl = await _findCompanionCover(file);
      return MusicItem(
        id: file.path.hashCode.toRadixString(36),
        title: nameWithoutExt,
        artist: '未知艺术家',
        album: '未知专辑',
        coverUrl: coverUrl,
        filePath: file.path,
        fileSize: await file.length(),
        format: _getExtension(file.path).replaceFirst('.', '').toUpperCase(),
      );
    }
  }

  Future<String?> _findCompanionCover(File audioFile) async {
    for (final candidate in yyResolveCoverCandidates(
      filePath: audioFile.path,
    )) {
      if (yyIsRemoteCoverUrl(candidate)) continue;
      final resolved = yyResolveCoverPath(candidate);
      if (resolved == null || resolved.isEmpty) continue;
      if (resolved == audioFile.path) continue;
      final file = File(resolved);
      if (await file.exists()) {
        return resolved;
      }
    }
    return null;
  }

  /// 保存封面到缓存
  Future<String?> _saveCover(String songId, Uint8List imageData) async {
    if (imageData.isEmpty) return null;
    try {
      final ext = _detectImageExt(imageData);
      final filePath = p.join(_coverCacheDir!, '$songId.$ext');
      final file = File(filePath);
      if (await file.exists()) return filePath;
      await file.writeAsBytes(imageData);
      return filePath;
    } catch (e) {
      _log.w('保存封面失败 ($songId): $e');
      return null;
    }
  }

  /// 检测图片格式
  String _detectImageExt(Uint8List data) {
    if (data.length >= 3 && data[0] == 0xFF && data[1] == 0xD8) return 'jpg';
    if (data.length >= 4 && data[0] == 0x89 && data[1] == 0x50) return 'png';
    return 'jpg';
  }

  String _getExtension(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1) return '';
    return path.substring(dot).toLowerCase();
  }
}
