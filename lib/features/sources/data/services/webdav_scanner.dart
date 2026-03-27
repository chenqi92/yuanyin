import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
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
};

const _coverFilePriority = {
  'folder.jpg': 0,
  'folder.jpeg': 0,
  'folder.png': 0,
  'folder.webp': 0,
  'cover.jpg': 1,
  'cover.jpeg': 1,
  'cover.png': 1,
  'cover.webp': 1,
  'front.jpg': 2,
  'front.jpeg': 2,
  'front.png': 2,
  'front.webp': 2,
  'album.jpg': 3,
  'album.jpeg': 3,
  'album.png': 3,
  'album.webp': 3,
  'artwork.jpg': 4,
  'artwork.jpeg': 4,
  'artwork.png': 4,
  'artwork.webp': 4,
};

const _imageExtensions = {'.jpg', '.jpeg', '.png', '.webp'};

/// WebDAV 扫描器
///
/// 使用 PROPFIND 方法递归列举 WebDAV 目录下的音频文件。
class WebDavScanner {
  final Dio _dio;

  WebDavScanner() : _dio = Dio();

  /// 测试 WebDAV 连接可达性
  ///
  /// 返回 (success, errorMessage)
  Future<(bool, String?)> testConnection(
    String baseUrl, {
    String? username,
    String? password,
  }) async {
    try {
      final headers = <String, String>{'Content-Type': 'application/xml'};
      if (username != null && password != null) {
        final credentials = base64Encode(
          Uint8List.fromList('$username:$password'.codeUnits),
        );
        headers['Authorization'] = 'Basic $credentials';
      }

      final url = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
      final response = await _dio.request(
        url,
        options: Options(
          method: 'PROPFIND',
          headers: {...headers, 'Depth': '0'},
          validateStatus: (status) => status != null && status < 500,
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
        data:
            '<?xml version="1.0"?><d:propfind xmlns:d="DAV:"><d:prop><d:resourcetype/></d:prop></d:propfind>',
      );

      if (response.statusCode == 207 || response.statusCode == 200) {
        return (true, null);
      }
      if (response.statusCode == 401) {
        return (false, '认证失败：用户名或密码错误');
      }
      if (response.statusCode == 403) {
        return (false, '访问被拒绝');
      }
      if (response.statusCode == 404) {
        return (false, '路径不存在');
      }
      return (false, 'HTTP ${response.statusCode}');
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        return (false, '连接超时，请检查地址');
      }
      if (e.type == DioExceptionType.connectionError) {
        return (false, '无法连接，请检查网络和地址');
      }
      return (false, '连接失败: ${e.message}');
    } catch (e) {
      return (false, e.toString());
    }
  }

  /// 扫描 WebDAV 服务器上的音频文件
  ///
  /// [baseUrl] WebDAV 根 URL (e.g. https://dav.example.com/music)
  /// [username] 用户名
  /// [password] 密码
  /// [onProgress] 进度回调
  Future<List<MusicItem>> scan(
    String baseUrl, {
    String? username,
    String? password,
    void Function(int count, String currentFile)? onProgress,
  }) async {
    final songs = <MusicItem>[];
    // 认证头
    final headers = <String, String>{'Content-Type': 'application/xml'};
    if (username != null && password != null) {
      final credentials = base64Encode(
        Uint8List.fromList('$username:$password'.codeUnits),
      );
      headers['Authorization'] = 'Basic $credentials';
    }

    await _scanDirectory(
      baseUrl.endsWith('/') ? baseUrl : '$baseUrl/',
      headers,
      songs,
      (c, f) => onProgress?.call(c, f),
    );

    _log.i('WebDAV 扫描完成: $baseUrl, 共 ${songs.length} 首');
    return songs;
  }

  Future<void> _scanDirectory(
    String url,
    Map<String, String> headers,
    List<MusicItem> songs,
    void Function(int count, String file) onProgress,
  ) async {
    try {
      final response = await _dio.request(
        url,
        options: Options(
          method: 'PROPFIND',
          headers: {...headers, 'Depth': '1'},
        ),
        data: '''<?xml version="1.0" encoding="UTF-8"?>
<D:propfind xmlns:D="DAV:">
  <D:prop>
    <D:displayname/>
    <D:getcontentlength/>
    <D:resourcetype/>
    <D:getcontenttype/>
  </D:prop>
</D:propfind>''',
      );

      if (response.statusCode != 207) return;

      final body = response.data.toString();
      final entries = _parseMultiStatus(body, url);
      final directorySongs = <({MusicItem song, String stem})>[];
      final namedCoverUrls = <String, String>{};
      String? folderCoverUrl;
      var folderCoverPriority = 999;

      for (final entry in entries) {
        if (entry.isDirectory) {
          await _scanDirectory(entry.href, headers, songs, onProgress);
        } else if (_isImageFile(entry.name)) {
          namedCoverUrls[_stemOfName(entry.name).toLowerCase()] = entry.href;
          if (_isCoverFile(entry.name)) {
            final priority = _coverPriority(entry.name);
            if (priority < folderCoverPriority) {
              folderCoverPriority = priority;
              folderCoverUrl = entry.href;
            }
          }
        } else if (_isAudioFile(entry.name)) {
          directorySongs.add((
            song: MusicItem(
              id: entry.href.hashCode.toRadixString(36),
              title: _titleFromFileName(entry.name),
              artist: _artistFromFileName(entry.name),
              album: '未知专辑',
              filePath: entry.href,
              fileSize: entry.contentLength,
              format: _extOf(entry.name),
            ),
            stem: _stemOfName(entry.name).toLowerCase(),
          ));
        }
      }

      songs.addAll(
        directorySongs.map((entry) {
          final coverUrl = namedCoverUrls[entry.stem] ?? folderCoverUrl;
          return coverUrl == null
              ? entry.song
              : entry.song.copyWith(coverUrl: coverUrl);
        }),
      );
      for (var index = 0; index < directorySongs.length; index++) {
        onProgress(
          songs.length - directorySongs.length + index + 1,
          directorySongs[index].song.title,
        );
      }
    } catch (e) {
      _log.w('WebDAV PROPFIND 失败: $url - $e');
    }
  }

  List<_DavEntry> _parseMultiStatus(String xml, String baseUrl) {
    final entries = <_DavEntry>[];
    // 简易 XML 解析（不引入完整 XML 库）
    final responseRegex = RegExp(
      r'<D:response>(.*?)</D:response>',
      dotAll: true,
    );
    final hrefRegex = RegExp(r'<D:href>(.*?)</D:href>');
    final displayNameRegex = RegExp(r'<D:displayname>(.*?)</D:displayname>');
    final lengthRegex = RegExp(
      r'<D:getcontentlength>(.*?)</D:getcontentlength>',
    );
    final collectionRegex = RegExp(r'<D:collection\s*/?>');

    for (final match in responseRegex.allMatches(xml)) {
      final block = match.group(1)!;
      final href = hrefRegex.firstMatch(block)?.group(1) ?? '';
      if (href.isEmpty ||
          href == baseUrl ||
          href.endsWith('/') && href == baseUrl) {
        continue;
      }

      final displayName =
          displayNameRegex.firstMatch(block)?.group(1) ?? href.split('/').last;
      final lengthStr = lengthRegex.firstMatch(block)?.group(1);
      final isDir = collectionRegex.hasMatch(block);

      // 构造完整 URL
      String fullHref = href;
      if (!href.startsWith('http')) {
        final uri = Uri.parse(baseUrl);
        fullHref = '${uri.scheme}://${uri.host}:${uri.port}$href';
      }

      if (fullHref != baseUrl) {
        entries.add(
          _DavEntry(
            href: fullHref,
            name: Uri.decodeFull(displayName),
            isDirectory: isDir,
            contentLength: lengthStr != null ? int.tryParse(lengthStr) : null,
          ),
        );
      }
    }
    return entries;
  }

  bool _isAudioFile(String name) {
    final lower = name.toLowerCase();
    return _audioExtensions.any((ext) => lower.endsWith(ext));
  }

  bool _isImageFile(String name) {
    final lower = name.toLowerCase();
    return _imageExtensions.any((ext) => lower.endsWith(ext));
  }

  bool _isCoverFile(String name) =>
      _coverFilePriority.containsKey(name.toLowerCase());

  int _coverPriority(String name) =>
      _coverFilePriority[name.toLowerCase()] ?? 999;

  String _stemOfName(String name) {
    final dot = name.lastIndexOf('.');
    if (dot <= 0) return name;
    return name.substring(0, dot);
  }

  String _titleFromFileName(String name) {
    final withoutExt = name.contains('.')
        ? name.substring(0, name.lastIndexOf('.'))
        : name;
    if (withoutExt.contains(' - ')) {
      return withoutExt.split(' - ').sublist(1).join(' - ').trim();
    }
    return withoutExt;
  }

  String _artistFromFileName(String name) {
    final withoutExt = name.contains('.')
        ? name.substring(0, name.lastIndexOf('.'))
        : name;
    if (withoutExt.contains(' - ')) {
      return withoutExt.split(' - ').first.trim();
    }
    return '未知艺术家';
  }

  String _extOf(String name) {
    final dot = name.lastIndexOf('.');
    return dot >= 0 ? name.substring(dot + 1).toUpperCase() : '';
  }
}

class _DavEntry {
  final String href;
  final String name;
  final bool isDirectory;
  final int? contentLength;
  const _DavEntry({
    required this.href,
    required this.name,
    required this.isDirectory,
    this.contentLength,
  });
}

/// base64 编码（纯 Dart 实现，无需额外依赖）
String base64Encode(Uint8List bytes) {
  const chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  final buffer = StringBuffer();
  for (var i = 0; i < bytes.length; i += 3) {
    final b0 = bytes[i];
    final b1 = i + 1 < bytes.length ? bytes[i + 1] : 0;
    final b2 = i + 2 < bytes.length ? bytes[i + 2] : 0;
    buffer.write(chars[(b0 >> 2) & 0x3F]);
    buffer.write(chars[((b0 << 4) | (b1 >> 4)) & 0x3F]);
    buffer.write(
      i + 1 < bytes.length ? chars[((b1 << 2) | (b2 >> 6)) & 0x3F] : '=',
    );
    buffer.write(i + 2 < bytes.length ? chars[b2 & 0x3F] : '=');
  }
  return buffer.toString();
}
