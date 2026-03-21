import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:logger/logger.dart';

final _log = Logger(printer: SimplePrinter());

/// 在线歌词服务 — 通过 LRCLIB API 获取 LRC 歌词（含 Hive 缓存）
///
/// LRCLIB (https://lrclib.net) 是免费开放的歌词 API，
/// 支持按歌名、艺术家、专辑精确匹配或模糊搜索。
class LyricService {
  static const _boxName = 'lyrics_cache';
  final Dio _dio;
  Box? _box;

  LyricService() : _dio = Dio(BaseOptions(
    baseUrl: 'https://lrclib.net/api',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'User-Agent': 'Primuse Music Player v0.1.0 (https://kkape.com)',
    },
  ));

  Future<Box> get _openBox async {
    _box ??= await Hive.openBox(_boxName);
    return _box!;
  }

  /// 生成缓存 key
  String _cacheKey(String title, String artist) =>
      '${artist.trim().toLowerCase()}::${title.trim().toLowerCase()}';

  /// 精确匹配获取歌词（先查缓存，未命中走网络）
  ///
  /// 优先使用同步歌词（syncedLyrics），退而使用纯文本歌词（plainLyrics）
  Future<String?> fetchLyrics({
    required String title,
    required String artist,
    String? album,
    Duration? duration,
    bool forceRefresh = false,
  }) async {
    final key = _cacheKey(title, artist);

    // 1. 查缓存
    if (!forceRefresh) {
      try {
        final box = await _openBox;
        final cached = box.get(key) as String?;
        if (cached != null && cached.isNotEmpty) {
          _log.i('歌词缓存命中: $title - $artist');
          return cached;
        }
      } catch (e) {
        _log.w('读取歌词缓存失败: $e');
      }
    }

    // 2. 网络获取
    try {
      final exactResult = await _tryExactMatch(title, artist, album, duration);
      if (exactResult != null) {
        await _saveToCache(key, exactResult);
        return exactResult;
      }

      final searchResult = await _searchLyrics(title, artist);
      if (searchResult != null) {
        await _saveToCache(key, searchResult);
        return searchResult;
      }
    } catch (e) {
      _log.w('歌词获取失败: $title - $artist: $e');
    }
    return null;
  }

  /// 写入缓存
  Future<void> _saveToCache(String key, String lyrics) async {
    try {
      final box = await _openBox;
      await box.put(key, lyrics);
    } catch (e) {
      _log.w('写入歌词缓存失败: $e');
    }
  }

  /// 清除所有歌词缓存
  Future<void> clearCache() async {
    final box = await _openBox;
    await box.clear();
    _log.i('歌词缓存已清除');
  }

  /// 获取缓存数量
  Future<int> cacheCount() async {
    final box = await _openBox;
    return box.length;
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
        final synced = data['syncedLyrics'] as String?;
        if (synced != null && synced.isNotEmpty) return synced;
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
