import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../../../player/domain/entities/music_item.dart';
import '../../data/services/music_database_service.dart';
import '../../../../shared/services/cover_cache_service.dart';

final _log = Logger(printer: SimplePrinter());

/// MusicBrainz 元数据刮削服务
///
/// 通过 MusicBrainz Recording + Release API 补充歌曲缺失的元数据：
/// - 年份、流派、专辑名
/// - 通过 Cover Art Archive 获取专辑封面
class MetadataScraper {
  final Dio _dio;

  MetadataScraper() : _dio = Dio(BaseOptions(
    baseUrl: 'https://musicbrainz.org/ws/2',
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'User-Agent': 'Primuse/0.1.0 (https://kkape.com; primuse@kkape.com)',
      'Accept': 'application/json',
    },
  ));

  /// 刮削单首歌曲的元数据
  ///
  /// 返回包含补充字段的新 MusicItem（如果匹配到结果）
  Future<MusicItem?> scrape(MusicItem song) async {
    try {
      // 1. 搜索 Recording
      final query = _buildQuery(song);
      final response = await _dio.get('/recording', queryParameters: {
        'query': query,
        'limit': '3',
        'fmt': 'json',
      });

      if (response.statusCode != 200) return null;
      final recordings = response.data['recordings'] as List? ?? [];
      if (recordings.isEmpty) return null;

      final best = recordings.first as Map<String, dynamic>;

      // 提取元数据
      int? year;
      String? genre;
      String? albumName;
      String? releaseId;

      // 从 release 中获取年份和专辑名
      final releases = best['releases'] as List? ?? [];
      if (releases.isNotEmpty) {
        final release = releases.first as Map<String, dynamic>;
        releaseId = release['id'] as String?;
        albumName = release['title'] as String?;
        final date = release['date'] as String?;
        if (date != null && date.length >= 4) {
          year = int.tryParse(date.substring(0, 4));
        }
      }

      // 从 tags 中获取流派
      final tags = best['tags'] as List? ?? [];
      if (tags.isNotEmpty) {
        // 取投票数最高的 tag
        tags.sort((a, b) => ((b as Map)['count'] as int? ?? 0)
            .compareTo((a as Map)['count'] as int? ?? 0));
        genre = (tags.first as Map)['name'] as String?;
      }

      // 2. 尝试从 Cover Art Archive 获取封面
      String? coverUrl;
      if (releaseId != null && (song.coverUrl == null || song.coverUrl!.isEmpty)) {
        coverUrl = await _fetchCoverArt(releaseId, song.id);
      }

      // 有效更新才返回
      if (year == null && genre == null && albumName == null && coverUrl == null) {
        return null;
      }

      return song.copyWith(
        year: year ?? song.year,
        genre: genre ?? song.genre,
        album: (albumName != null && (song.album == '未知专辑')) ? albumName : song.album,
        coverUrl: coverUrl ?? song.coverUrl,
      );
    } catch (e) {
      _log.w('MusicBrainz 刮削失败: ${song.title}: $e');
      return null;
    }
  }

  String _buildQuery(MusicItem song) {
    final parts = <String>[];
    parts.add('recording:"${_escape(song.title)}"');
    if (song.artist != '未知艺术家') {
      parts.add('artist:"${_escape(song.artist)}"');
    }
    if (song.album != '未知专辑') {
      parts.add('release:"${_escape(song.album)}"');
    }
    return parts.join(' AND ');
  }

  String _escape(String s) => s.replaceAll('"', '\\"');

  /// 从 Cover Art Archive 获取封面并缓存
  Future<String?> _fetchCoverArt(String releaseId, String songId) async {
    try {
      // Cover Art Archive 返回 JSON 描述，其中包含图片 URL
      final caaUrl = 'https://coverartarchive.org/release/$releaseId/front-250';
      final response = await Dio().get(
        caaUrl,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final coverCache = CoverCacheService();
        return await coverCache.saveCover(songId, response.data);
      }
    } catch (e) {
      // Cover Art Archive 404 很正常（无封面的专辑）
    }
    return null;
  }

  /// MusicBrainz API 限速：每秒最多 1 次请求
  Future<void> rateLimit() => Future.delayed(const Duration(milliseconds: 1100));
}

/// Provider
final metadataScraperProvider = Provider((ref) => MetadataScraper());
