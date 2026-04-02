import 'dart:async';

import 'package:dio/dio.dart';

import '../../../domain/entities/music_scraper_result.dart';
import '../../../domain/entities/scraper_source_entity.dart';
import '../../../domain/interfaces/music_scraper.dart';

/// LRCLIB 开源歌词刮削器
///
/// 使用 LRCLIB.net 开源歌词数据库
/// 文档: https://lrclib.net/docs
/// 许可: 完全开源，可合法内置
class LRCLIBScraper implements MusicScraper {
  LRCLIBScraper() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'YuanYin/1.0 (https://github.com/yuanyin)',
      },
    ));
  }

  static const String _baseUrl = 'https://lrclib.net/api';
  late final Dio _dio;

  @override
  ScraperType get type => ScraperType.lrclib;

  @override
  bool get isConfigured => true;

  @override
  Future<bool> testConnection() async {
    try {
      await search('test', limit: 1);
      return true;
    } on Exception {
      return false;
    }
  }

  @override
  Future<MusicScraperSearchResult> search(
    String query, {
    String? artist,
    String? album,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      var searchQuery = query;
      if (artist != null && artist.isNotEmpty) searchQuery += ' $artist';

      final response = await _dio.get<dynamic>(
        '/search',
        queryParameters: {
          'q': searchQuery,
        },
      );

      if (response.data is! List) {
        return MusicScraperSearchResult.empty(type);
      }

      final results = (response.data as List)
          .whereType<Map<String, dynamic>>()
          .take(limit)
          .toList();

      final items = results.map((data) {
        final id = data['id']?.toString() ?? '';
        return MusicScraperItem(
          externalId: id,
          source: type,
          title: data['trackName'] as String? ?? '',
          artist: data['artistName'] as String?,
          album: data['albumName'] as String?,
          durationMs: _secondsToMs(data['duration']),
        );
      }).toList();

      return MusicScraperSearchResult(
        items: items,
        source: type,
        page: page,
        totalResults: items.length,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// 直接查找歌词（LRCLIB 特有的精确匹配 API）
  Future<LyricScraperResult?> fetchLyrics({
    required String title,
    required String artist,
    String? album,
    Duration? duration,
  }) async {
    try {
      final params = <String, dynamic>{
        'track_name': title,
        'artist_name': artist,
      };
      if (album != null) params['album_name'] = album;
      if (duration != null) params['duration'] = duration.inSeconds;

      final response = await _dio.get<dynamic>(
        '/get',
        queryParameters: params,
      );

      if (response.data is! Map<String, dynamic>) return null;
      final data = response.data as Map<String, dynamic>;

      final syncedLyrics = data['syncedLyrics'] as String?;
      final plainLyrics = data['plainLyrics'] as String?;

      if ((syncedLyrics == null || syncedLyrics.isEmpty) &&
          (plainLyrics == null || plainLyrics.isEmpty)) {
        return null;
      }

      return LyricScraperResult(
        source: type,
        lrcContent: syncedLyrics,
        plainText: plainLyrics,
        title: data['trackName'] as String?,
        artist: data['artistName'] as String?,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw _handleDioError(e);
    }
  }

  @override
  Future<MusicScraperDetail?> getDetail(String externalId) async {
    // LRCLIB 不提供元数据详情
    return null;
  }

  @override
  Future<List<CoverScraperResult>> getCoverArt(String externalId) async {
    // LRCLIB 不提供封面
    return [];
  }

  @override
  Future<LyricScraperResult?> getLyrics(String externalId) async {
    try {
      final response = await _dio.get<dynamic>('/get/$externalId');
      if (response.data is! Map<String, dynamic>) return null;
      final data = response.data as Map<String, dynamic>;

      final syncedLyrics = data['syncedLyrics'] as String?;
      final plainLyrics = data['plainLyrics'] as String?;

      if ((syncedLyrics == null || syncedLyrics.isEmpty) &&
          (plainLyrics == null || plainLyrics.isEmpty)) {
        return null;
      }

      return LyricScraperResult(
        source: type,
        lrcContent: syncedLyrics,
        plainText: plainLyrics,
        title: data['trackName'] as String?,
        artist: data['artistName'] as String?,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw _handleDioError(e);
    }
  }

  @override
  void dispose() => _dio.close();

  int? _secondsToMs(dynamic seconds) {
    if (seconds == null) return null;
    if (seconds is num) return (seconds * 1000).toInt();
    final parsed = double.tryParse(seconds.toString());
    return parsed != null ? (parsed * 1000).toInt() : null;
  }

  MusicScraperException _handleDioError(DioException e) {
    if (e.response?.statusCode == 429) {
      return MusicScraperRateLimitException(
        '请求过于频繁',
        source: type,
        cause: e,
      );
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return MusicScraperNetworkException('网络连接失败', source: type, cause: e);
    }
    return MusicScraperException(
      e.message ?? '未知错误',
      source: type,
      cause: e,
    );
  }
}
