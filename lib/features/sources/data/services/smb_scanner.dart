import 'package:dio/dio.dart';
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
  '.mp3', '.flac', '.m4a', '.aac', '.wav', '.ogg', '.opus',
  '.ape', '.wma', '.aiff', '.aif',
};

/// SMB 网络扫描器
///
/// 通过自建 API 代理来列举 SMB 共享目录（因为 Flutter 不直接支持 SMB 协议）。
/// 
/// 两种工作模式:
/// 1. **网关代理模式**: 需要在 NAS 上运行一个简单的 HTTP 代理来列举 SMB 文件
/// 2. **直接 URL 模式**: 如果 NAS 暴露了 HTTP 接口（如群晖 FileStation API）
class SmbScanner {
  final Dio _dio;

  SmbScanner() : _dio = Dio();

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
    void Function(int count, String currentFile)? onProgress,
  }) async {
    final songs = <MusicItem>[];
    await _scanSynologyDir(host, port, sid, folderPath, songs, onProgress);
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
      final url = '$protocol://$host:$port/webapi/auth.cgi';
      final params = <String, String>{
        'api': 'SYNO.API.Auth',
        'version': '6',
        'method': 'login',
        'account': username,
        'passwd': password,
        'session': 'FileStation',
        'format': 'sid',
      };

      // OTP 支持
      if (otpCode != null && otpCode.isNotEmpty) {
        params['otp_code'] = otpCode;
        params['enable_device_token'] = 'yes';
        params['device_name'] = 'Primuse Music Player';
      }

      // 如有已保存的 device_id，可跳过 OTP
      if (deviceId != null && deviceId.isNotEmpty) {
        params['device_id'] = deviceId;
      }

      final response = await _dio.get(url, queryParameters: params);

      if (response.data is Map && response.data['success'] == true) {
        final sid = response.data['data']['sid'] as String?;
        final did = response.data['data']['device_id'] as String?;
        return SynologyLoginResult.success(sid, deviceId: did);
      }

      // 检查错误码
      final errorCode = response.data?['error']?['code'];
      if (errorCode == 403) {
        return const SynologyLoginResult.otpRequired();
      }

      _log.w('群晖登录失败: ${response.data}');
      return SynologyLoginResult.failed(
        _synologyErrorMessage(errorCode),
      );
    } on DioException catch (e) {
      return SynologyLoginResult.failed(_friendlyError(e));
    } catch (e) {
      _log.w('群晖登录异常: $e');
      return SynologyLoginResult.failed(e.toString());
    }
  }

  String _synologyErrorMessage(dynamic code) {
    switch (code) {
      case 400: return '用户名或密码错误';
      case 401: return '账户已被停用';
      case 402: return '权限不足';
      case 403: return '需要二级验证码';
      case 404: return '二级验证码错误';
      case 406: return 'OTP 强制且未启用';
      case 407: return '二级验证码有误，请重试';
      default: return '登录失败 (错误码: $code)';
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
      host: host, port: port, username: username, password: password,
      useSsl: useSsl, otpCode: otpCode, deviceId: deviceId,
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
      final response = await _dio.get(url, queryParameters: {
        'api': 'SYNO.FileStation.List',
        'version': '2',
        'method': 'list_share',
        '_sid': sid,
      });

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
      final response = await _dio.get(url, queryParameters: {
        'api': 'SYNO.FileStation.List',
        'version': '2',
        'method': 'list',
        'folder_path': folderPath,
        'sort_by': 'name',
        'sort_direction': 'asc',
        '_sid': sid,
      });

      if (response.data is Map && response.data['success'] == true) {
        final files = response.data['data']['files'] as List? ?? [];
        return files
            .where((f) => f['isdir'] == true)
            .map<({String name, String path})>((f) => (name: f['name'] as String, path: f['path'] as String))
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
    if (e.response?.statusCode == 403) return '访问被拒绝';
    if (e.response?.statusCode == 401) return '认证失败';
    return '连接失败: ${e.message}';
  }

  Future<void> _scanSynologyDir(
    String host,
    int port,
    String sid,
    String folderPath,
    List<MusicItem> songs,
    void Function(int count, String)? onProgress,
  ) async {
    try {
      final url = 'http://$host:$port/webapi/entry.cgi';
      int offset = 0;
      const limit = 500;

      while (true) {
        final response = await _dio.get(url, queryParameters: {
          'api': 'SYNO.FileStation.List',
          'version': '2',
          'method': 'list',
          'folder_path': folderPath,
          'additional': 'size,type',
          'limit': '$limit',
          'offset': '$offset',
          '_sid': sid,
        });

        if (response.data is! Map || response.data['success'] != true) break;

        final files = response.data['data']['files'] as List? ?? [];
        if (files.isEmpty) break;

        for (final file in files) {
          final name = file['name'] as String;
          final isDir = file['isdir'] as bool? ?? false;
          final path = file['path'] as String;
          final size = file['additional']?['size'] as int?;

          if (isDir) {
            await _scanSynologyDir(host, port, sid, path, songs, onProgress);
          } else if (_isAudio(name)) {
            // 构造流播放 URL
            final streamUrl = 'http://$host:$port/webapi/entry.cgi?'
                'api=SYNO.FileStation.Download&version=2&method=download'
                '&path=${Uri.encodeComponent(path)}&_sid=$sid';

            songs.add(MusicItem(
              id: path.hashCode.toRadixString(36),
              title: _titleFromName(name),
              artist: _artistFromName(name),
              album: folderPath.split('/').last,
              filePath: streamUrl,
              fileSize: size,
              format: _extOf(name),
            ));
            onProgress?.call(songs.length, name);
          }
        }

        if (files.length < limit) break;
        offset += limit;
      }
    } catch (e) {
      _log.w('群晖目录扫描失败: $folderPath - $e');
    }
  }

  bool _isAudio(String name) {
    final lower = name.toLowerCase();
    return _audioExts.any((ext) => lower.endsWith(ext));
  }

  String _titleFromName(String name) {
    final noExt = name.contains('.') ? name.substring(0, name.lastIndexOf('.')) : name;
    if (noExt.contains(' - ')) return noExt.split(' - ').sublist(1).join(' - ').trim();
    return noExt;
  }

  String _artistFromName(String name) {
    final noExt = name.contains('.') ? name.substring(0, name.lastIndexOf('.')) : name;
    if (noExt.contains(' - ')) return noExt.split(' - ').first.trim();
    return '未知艺术家';
  }

  String _extOf(String name) {
    final dot = name.lastIndexOf('.');
    return dot >= 0 ? name.substring(dot + 1).toUpperCase() : '';
  }
}
