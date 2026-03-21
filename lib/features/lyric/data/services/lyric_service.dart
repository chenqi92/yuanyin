import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

final _log = Logger(printer: SimplePrinter());

/// 在线歌词服务 — 通过 LRCLIB API 获取 LRC 歌词
///
/// LRCLIB (https://lrclib.net) 是免费开放的歌词 API，
/// 支持按歌名、艺术家、专辑精确匹配或模糊搜索。
class LyricService {
  final Dio _dio;

  LyricService() : _dio = Dio(BaseOptions(
    baseUrl: 'https://lrclib.net/api',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'User-Agent': 'Primuse Music Player v0.1.0 (https://kkape.com)',
    },
  ));

  /// 精确匹配获取歌词
  ///
  /// 优先使用同步歌词（syncedLyrics），退而使用纯文本歌词（plainLyrics）
  Future<String?> fetchLyrics({
    required String title,
    required String artist,
    String? album,
    Duration? duration,
  }) async {
    try {
      // 1. 先尝试精确匹配 (get endpoint)
      final exactResult = await _tryExactMatch(title, artist, album, duration);
      if (exactResult != null) return exactResult;

      // 2. 退而使用搜索 (search endpoint)
      return await _searchLyrics(title, artist);
    } catch (e) {
      _log.w('歌词获取失败: $title - $artist: $e');
      return null;
    }
  }

  /// 精确匹配
  Future<String?> _tryExactMatch(
      String title, String artist, String? album, Duration? duration) async {
    try {
      final params = <String, dynamic>{
        'track_name': title,
        'artist_name': artist,
      };
      if (album != null && album != '未知专辑') {
        params['album_name'] = album;
      }
      if (duration != null && duration.inSeconds > 0) {
        params['duration'] = duration.inSeconds;
      }

      final response = await _dio.get('/get', queryParameters: params);

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map;
        // 优先同步歌词
        final synced = data['syncedLyrics'] as String?;
        if (synced != null && synced.isNotEmpty) return synced;
        // 退而纯文本
        final plain = data['plainLyrics'] as String?;
        if (plain != null && plain.isNotEmpty) return plain;
      }
    } on DioException catch (e) {
      if (e.response?.statusCode != 404) {
        _log.w('精确匹配歌词失败: $e');
      }
    }
    return null;
  }

  /// 模糊搜索
  Future<String?> _searchLyrics(String title, String artist) async {
    try {
      final response = await _dio.get('/search', queryParameters: {
        'q': '$artist $title',
      });

      if (response.statusCode == 200 && response.data is List) {
        final results = response.data as List;
        if (results.isEmpty) return null;

        // 取第一个结果
        final best = results.first as Map;
        final synced = best['syncedLyrics'] as String?;
        if (synced != null && synced.isNotEmpty) return synced;
        final plain = best['plainLyrics'] as String?;
        if (plain != null && plain.isNotEmpty) return plain;
      }
    } on DioException catch (e) {
      _log.w('搜索歌词失败: $e');
    }
    return null;
  }
}

/// Provider
final lyricServiceProvider = Provider((ref) => LyricService());
