import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:logger/logger.dart';
import '../../../player/domain/entities/music_item.dart';

final _log = Logger(printer: SimplePrinter());

/// 群晖登录结果
enum SynologyLoginStatus { success, otpRequired, failed }

class SynologyLoginResult {
  final SynologyLoginStatus status;
  final String? sid;
  final String? deviceId;
  final String? errorMessage;

  const SynologyLoginResult.success(this.sid, {this.deviceId})
    : status = SynologyLoginStatus.success,
      errorMessage = null;

  const SynologyLoginResult.otpRequired()
    : status = SynologyLoginStatus.otpRequired,
      sid = null,
      deviceId = null,
      errorMessage = '需要二级验证码';

  const SynologyLoginResult.failed(this.errorMessage)
    : status = SynologyLoginStatus.failed,
      sid = null,
      deviceId = null;
}

/// 支持的音频扩展名
const _audioExts = {
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

const _coverNames = {
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

const _imageExts = {'.jpg', '.jpeg', '.png', '.webp'};

/// SMB 网络扫描器
///
/// 通过自建 API 代理来列举 SMB 共享目录（因为 Flutter 不直接支持 SMB 协议）。
///
/// 两种工作模式:
/// 1. **网关代理模式**: 需要在 NAS 上运行一个简单的 HTTP 代理来列举 SMB 文件
/// 2. **直接 URL 模式**: 如果 NAS 暴露了 HTTP 接口（如群晖 FileStation API）
class SmbScanner {
  final Dio _dio;

  SmbScanner() : _dio = Dio() {
    // 跳过 SSL 证书验证（群晖 NAS 通常使用自签名证书）
    _dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient()
          ..badCertificateCallback = (cert, host, port) => true;
        return client;
      },
    );
  }

  /// 通过群晖 FileStation API 扫描
  ///
  /// [host] 群晖地址 (e.g. 192.168.1.100)
  /// [port] 端口 (默认 5000)
  /// [sid] 登录获取的 session ID
  /// [folderPath] 共享文件夹路径 (e.g. /music)
  Future<List<MusicItem>> scanSynology({
    required String host,
    int port = 5000,
    required String sid,
    required String folderPath,
    bool useSsl = false,
    void Function(int count, String currentFile)? onProgress,
  }) async {
    final songs = <MusicItem>[];
    await _scanSynologyDir(
      host,
      port,
      sid,
      folderPath,
      songs,
      onProgress,
      useSsl,
    );
    _log.i('群晖扫描完成: $folderPath, 共 ${songs.length} 首');
    return songs;
  }

  /// 群晖 FileStation 登录获取 SID
  ///
  /// 支持 OTP 二级验证：
  /// - 首次不带 otpCode 尝试登录
  /// - 如果返回 error 403，则表示需要 OTP
  /// - 携带 otpCode 重新登录
  /// - 可选 deviceId 跳过后续 OTP
  Future<SynologyLoginResult> synologyLogin({
    required String host,
    int port = 5000,
    required String username,
    required String password,
    bool useSsl = false,
    String? otpCode,
    String? deviceId,
  }) async {
    try {
      final protocol = useSsl ? 'https' : 'http';
      // 使用 entry.cgi（与 my-nas 一致，兼容新版 DSM）
      final url = '$protocol://$host:$port/webapi/entry.cgi';
      final params = <String, String>{
        'api': 'SYNO.API.Auth',
        'version': '6',
        'method': 'login',
        'account': username,
        'passwd': password,
        'session': 'FileStation',
        'format': 'sid',
        // 始终启用设备令牌（记住设备，跳过后续 OTP）
        'enable_device_token': 'yes',
        'device_name': 'Primuse Music Player',
      };

      // OTP 二级验证码
      if (otpCode != null && otpCode.isNotEmpty) {
        params['otp_code'] = otpCode;
      }

      // 如有已保存的 device_id，跳过 OTP
      if (deviceId != null && deviceId.isNotEmpty) {
        params['device_id'] = deviceId;
      }

      final response = await _dio.get(url, queryParameters: params);

      if (response.data is Map && response.data['success'] == true) {
        final sid = response.data['data']['sid'] as String?;
        // 群晖 API 返回 "did"（不是 "device_id"）
        final did = response.data['data']['did'] as String?;
        return SynologyLoginResult.success(sid, deviceId: did);
      }

      // 检查错误码
      final error = response.data?['error'];
      final errorCode = error is Map ? error['code'] : null;
      if (errorCode == 403) {
        return const SynologyLoginResult.otpRequired();
      }

      _log.w('群晖登录失败: ${response.data}');
      return SynologyLoginResult.failed(_synologyErrorMessage(errorCode));
    } on DioException catch (e) {
      return SynologyLoginResult.failed(_friendlyError(e));
    } catch (e) {
      _log.w('群晖登录异常: $e');
      return SynologyLoginResult.failed(e.toString());
    }
  }

  String _synologyErrorMessage(dynamic code) {
    switch (code) {
      case 400:
        return '用户名或密码错误';
      case 401:
        return '账户已被停用';
      case 402:
        return '权限不足';
      case 403:
        return '需要二级验证码';
      case 404:
        return '二级验证码错误';
      case 406:
        return 'OTP 强制且未启用';
      case 407:
        return '二级验证码有误，请重试';
      case null:
        return '登录失败（服务器返回未知错误）';
      default:
        return '登录失败 (错误码: $code)';
    }
  }

  /// 测试群晖连接（仅登录，不扫描）
  ///
  /// 返回 (success, errorMessage)
  /// 当需要 OTP 时返回 (false, 'OTP_REQUIRED') 作为特殊标记
  Future<(bool, String?)> testSynologyConnection({
    required String host,
    int port = 5000,
    required String username,
    required String password,
    bool useSsl = false,
    String? otpCode,
    String? deviceId,
  }) async {
    final result = await synologyLogin(
      host: host,
      port: port,
      username: username,
      password: password,
      useSsl: useSsl,
      otpCode: otpCode,
      deviceId: deviceId,
    );
    switch (result.status) {
      case SynologyLoginStatus.success:
        return (true, null);
      case SynologyLoginStatus.otpRequired:
        return (false, 'OTP_REQUIRED');
      case SynologyLoginStatus.failed:
        return (false, result.errorMessage);
    }
  }

  /// 列出群晖根目录下的共享文件夹
  ///
  /// 登录成功后调用，返回顶层共享目录名称列表
  Future<List<String>> listSynologySharedFolders({
    required String host,
    int port = 5000,
    required String sid,
    bool useSsl = false,
  }) async {
    try {
      final protocol = useSsl ? 'https' : 'http';
      final url = '$protocol://$host:$port/webapi/entry.cgi';
      final response = await _dio.get(
        url,
        queryParameters: {
          'api': 'SYNO.FileStation.List',
          'version': '2',
          'method': 'list_share',
          '_sid': sid,
        },
      );

      if (response.data is Map && response.data['success'] == true) {
        final shares = response.data['data']['shares'] as List? ?? [];
        return shares.map<String>((s) => s['path'] as String).toList();
      }
      return [];
    } catch (e) {
      _log.w('列出群晖共享文件夹失败: $e');
      return [];
    }
  }

  /// 列出群晖指定目录下的子文件夹（用于下钻浏览）
  ///
  /// 返回 (name, path) 列表
  Future<List<({String name, String path})>> listSynologySubFolders({
    required String host,
    int port = 5000,
    required String sid,
    required String folderPath,
    bool useSsl = false,
  }) async {
    try {
      final protocol = useSsl ? 'https' : 'http';
      final url = '$protocol://$host:$port/webapi/entry.cgi';
      final response = await _dio.get(
        url,
        queryParameters: {
          'api': 'SYNO.FileStation.List',
          'version': '2',
          'method': 'list',
          'folder_path': folderPath,
          'sort_by': 'name',
          'sort_direction': 'asc',
          '_sid': sid,
        },
      );

      if (response.data is Map && response.data['success'] == true) {
        final files = response.data['data']['files'] as List? ?? [];
        return files
            .where((f) => f['isdir'] == true)
            .map<({String name, String path})>(
              (f) => (name: f['name'] as String, path: f['path'] as String),
            )
            .toList();
      }
      return [];
    } catch (e) {
      _log.w('列出群晖子目录失败: $folderPath - $e');
      return [];
    }
  }

  String _friendlyError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout) return '连接超时，请检查地址和端口';
    if (e.type == DioExceptionType.connectionError) return '无法连接，请检查网络和地址';
    if (e.type == DioExceptionType.unknown &&
        e.error.toString().contains('HandshakeException')) {
      return 'SSL 证书验证失败，请检查 SSL 设置或尝试关闭 SSL';
    }
    if (e.response?.statusCode == 403) return '访问被拒绝';
    if (e.response?.statusCode == 401) return '认证失败';
    final msg = e.message;
    return msg != null && msg.isNotEmpty ? '连接失败: $msg' : '连接失败，请检查地址和端口';
  }

  Future<void> _scanSynologyDir(
    String host,
    int port,
    String sid,
    String folderPath,
    List<MusicItem> songs,
    void Function(int count, String)? onProgress,
    bool useSsl,
  ) async {
    try {
      final protocol = useSsl ? 'https' : 'http';
      final url = '$protocol://$host:$port/webapi/entry.cgi';
      int offset = 0;
      const limit = 500;
      final directorySongs = <({MusicItem song, String stem})>[];
      final subDirectories = <String>[];
      final namedCoverUrls = <String, String>{};
      String? folderCoverUrl;
      var folderCoverPriority = 999;

      while (true) {
        final response = await _dio.get(
          url,
          queryParameters: {
            'api': 'SYNO.FileStation.List',
            'version': '2',
            'method': 'list',
            'folder_path': folderPath,
            'additional': 'size,type',
            'limit': '$limit',
            'offset': '$offset',
            '_sid': sid,
          },
        );

        if (response.data is! Map || response.data['success'] != true) break;

        final files = response.data['data']['files'] as List? ?? [];
        if (files.isEmpty) break;

        for (final file in files) {
          final name = file['name'] as String;
          final isDir = file['isdir'] as bool? ?? false;
          final path = file['path'] as String;
          final size = file['additional']?['size'] as int?;

          if (isDir) {
            subDirectories.add(path);
            continue;
          }

          final fileUrl =
              '$protocol://$host:$port/webapi/entry.cgi?'
              'api=SYNO.FileStation.Download&version=2&method=download'
              '&path=${Uri.encodeComponent(path)}&_sid=$sid';

          if (_isImageFile(name)) {
            namedCoverUrls[_stemOfName(name).toLowerCase()] = fileUrl;
            if (_isCoverImage(name)) {
              final priority = _coverPriority(name);
              if (priority < folderCoverPriority) {
                folderCoverPriority = priority;
                folderCoverUrl = fileUrl;
              }
            }
          } else if (_isAudio(name)) {
            directorySongs.add((
              song: MusicItem(
                id: path.hashCode.toRadixString(36),
                title: _titleFromName(name),
                artist: _artistFromName(name),
                album: folderPath.split('/').last,
                filePath: fileUrl,
                fileSize: size,
                format: _extOf(name),
              ),
              stem: _stemOfName(name).toLowerCase(),
            ));
          }
        }

        if (files.length < limit) break;
        offset += limit;
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
        onProgress?.call(
          songs.length - directorySongs.length + index + 1,
          directorySongs[index].song.title,
        );
      }

      for (final subDirectory in subDirectories) {
        await _scanSynologyDir(
          host,
          port,
          sid,
          subDirectory,
          songs,
          onProgress,
          useSsl,
        );
      }
    } catch (e) {
      _log.w('群晖目录扫描失败: $folderPath - $e');
    }
  }

  bool _isAudio(String name) {
    final lower = name.toLowerCase();
    return _audioExts.any((ext) => lower.endsWith(ext));
  }

  bool _isImageFile(String name) {
    final lower = name.toLowerCase();
    return _imageExts.any((ext) => lower.endsWith(ext));
  }

  bool _isCoverImage(String name) =>
      _coverNames.containsKey(name.toLowerCase());

  int _coverPriority(String name) => _coverNames[name.toLowerCase()] ?? 999;

  String _stemOfName(String name) {
    final dot = name.lastIndexOf('.');
    if (dot <= 0) return name;
    return name.substring(0, dot);
  }

  String _titleFromName(String name) {
    final noExt = name.contains('.')
        ? name.substring(0, name.lastIndexOf('.'))
        : name;
    if (noExt.contains(' - ')) {
      return noExt.split(' - ').sublist(1).join(' - ').trim();
    }
    return noExt;
  }

  String _artistFromName(String name) {
    final noExt = name.contains('.')
        ? name.substring(0, name.lastIndexOf('.'))
        : name;
    if (noExt.contains(' - ')) return noExt.split(' - ').first.trim();
    return '未知艺术家';
  }

  String _extOf(String name) {
    final dot = name.lastIndexOf('.');
    return dot >= 0 ? name.substring(dot + 1).toUpperCase() : '';
  }
}
