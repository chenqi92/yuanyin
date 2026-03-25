import 'dart:async';

import 'package:dio/dio.dart';

import '../../../domain/entities/music_scraper_result.dart';
import '../../../domain/entities/scraper_source_entity.dart';
import '../../../domain/interfaces/music_scraper.dart';

/// MusicBrainz 刮削器
///
/// 使用 MusicBrainz JSON Web Service 2 API
/// 封面通过 Cover Art Archive 获取
/// 文档: https://musicbrainz.org/doc/MusicBrainz_API
class MusicBrainzScraper implements MusicScraper {
  MusicBrainzScraper({
    String? userAgent,
  }) : _userAgent = userAgent ?? 'YuanYin/1.0 (https://github.com/yuanyin)' {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Accept': 'application/json',
        'User-Agent': _userAgent,
      },
    ));

    _coverArtDio = Dio(BaseOptions(
      baseUrl: _coverArtBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Accept': 'application/json',
        'User-Agent': _userAgent,
      },
    ));
  }

  static const String _baseUrl = 'https://musicbrainz.org/ws/2';
  static const String _coverArtBaseUrl = 'https://coverartarchive.org';

  final String _userAgent;
  late final Dio _dio;
  late final Dio _coverArtDio;

  DateTime? _lastRequestTime;
  static const Duration _minInterval = Duration(seconds: 1);

  @override
  ScraperType get type => ScraperType.musicBrainz;

  @override
  bool get isConfigured => true;

  @override
  Future<bool> testConnection() async {
    try {
      await _rateLimitedRequest(() => _dio.get<dynamic>(
            '/recording',
            queryParameters: {
              'query': 'test',
              'limit': 1,
              'fmt': 'json',
            },
          ));
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
      final queryParts = <String>[query];
      if (artist != null && artist.isNotEmpty) {
        queryParts.add('artist:"$artist"');
      }
      if (album != null && album.isNotEmpty) {
        queryParts.add('release:"$album"');
      }

      final luceneQuery = queryParts.join(' AND ');
      final offset = (page - 1) * limit;

      final response = await _rateLimitedRequest(() => _dio.get<dynamic>(
            '/recording',
            queryParameters: {
              'query': luceneQuery,
              'limit': limit,
              'offset': offset,
              'fmt': 'json',
            },
          ));

      if (response.data is! Map<String, dynamic>) {
        return MusicScraperSearchResult.empty(type);
      }

      final data = response.data as Map<String, dynamic>;
      final recordings = (data['recordings'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final count = data['count'] as int? ?? 0;

      final items = recordings.map(_parseRecording).toList();

      return MusicScraperSearchResult(
        items: items,
        source: type,
        page: page,
        totalPages: (count / limit).ceil(),
        totalResults: count,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<MusicScraperDetail?> getDetail(String externalId) async {
    try {
      final response = await _rateLimitedRequest(() => _dio.get<dynamic>(
            '/recording/$externalId',
            queryParameters: {
              'inc': 'artists+releases+genres+isrcs+artist-credits',
              'fmt': 'json',
            },
          ));

      if (response.data is! Map<String, dynamic>) {
        return null;
      }

      final data = response.data as Map<String, dynamic>;
      return _parseRecordingDetail(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      throw _handleDioError(e);
    }
  }

  @override
  Future<List<CoverScraperResult>> getCoverArt(String externalId) async {
    try {
      var releaseId = externalId;

      try {
        final response = await _rateLimitedRequest(() => _dio.get<dynamic>(
              '/recording/$externalId',
              queryParameters: {
                'inc': 'releases',
                'fmt': 'json',
              },
            ));

        if (response.data is Map<String, dynamic>) {
          final data = response.data as Map<String, dynamic>;
          final releases =
              (data['releases'] as List?)?.cast<Map<String, dynamic>>();
          if (releases != null && releases.isNotEmpty) {
            final firstReleaseId = releases.first['id'] as String?;
            if (firstReleaseId != null && firstReleaseId.isNotEmpty) {
              releaseId = firstReleaseId;
            }
          }
        }
      } on DioException {
        // fallback: assume externalId is release ID
      }

      final response = await _coverArtDio.get<dynamic>('/release/$releaseId');

      if (response.data is! Map<String, dynamic>) {
        return [];
      }

      final data = response.data as Map<String, dynamic>;
      final images =
          (data['images'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      if (images.isEmpty) return [];

      final results = <CoverScraperResult>[];
      for (final image in images) {
        final imageUrl = image['image'] as String?;
        final thumbnails = image['thumbnails'] as Map<String, dynamic>?;
        final thumbnailUrl = thumbnails?['500'] as String? ??
            thumbnails?['250'] as String? ??
            thumbnails?['small'] as String?;

        final types = (image['types'] as List?)?.cast<String>() ?? [];
        var coverType = CoverType.other;
        if (types.contains('Front')) {
          coverType = CoverType.front;
        } else if (types.contains('Back')) {
          coverType = CoverType.back;
        } else if (types.contains('Booklet')) {
          coverType = CoverType.booklet;
        } else if (types.contains('Medium')) {
          coverType = CoverType.medium;
        }

        if (imageUrl != null) {
          results.add(CoverScraperResult(
            source: type,
            coverUrl: imageUrl,
            thumbnailUrl: thumbnailUrl,
            type: coverType,
          ));
        }
      }

      return results;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return [];
      }
      throw _handleDioError(e);
    }
  }

  @override
  Future<LyricScraperResult?> getLyrics(String externalId) async => null;

  @override
  void dispose() {
    _dio.close();
    _coverArtDio.close();
  }

  Future<Response<T>> _rateLimitedRequest<T>(
    Future<Response<T>> Function() request,
  ) async {
    if (_lastRequestTime != null) {
      final elapsed = DateTime.now().difference(_lastRequestTime!);
      if (elapsed < _minInterval) {
        await Future<void>.delayed(_minInterval - elapsed);
      }
    }
    _lastRequestTime = DateTime.now();
    return request();
  }

  MusicScraperItem _parseRecording(Map<String, dynamic> data) {
    final id = data['id'] as String? ?? '';
    final title = data['title'] as String? ?? '';

    String? artist;
    final artistCredit = (data['artist-credit'] as List?)?.cast<Map<String, dynamic>>();
    if (artistCredit != null && artistCredit.isNotEmpty) {
      artist = artistCredit.map((ac) {
        final artistData = ac['artist'] as Map<String, dynamic>?;
        final name = ac['name'] as String? ?? artistData?['name'] as String? ?? '';
        final joinPhrase = ac['joinphrase'] as String? ?? '';
        return '$name$joinPhrase';
      }).join();
    }

    String? album;
    int? year;
    final releases = (data['releases'] as List?)?.cast<Map<String, dynamic>>();
    if (releases != null && releases.isNotEmpty) {
      final firstRelease = releases.first;
      album = firstRelease['title'] as String?;
      final date = firstRelease['date'] as String?;
      if (date != null && date.length >= 4) {
        year = int.tryParse(date.substring(0, 4));
      }
    }

    final lengthMs = data['length'] as int?;
    final score = data['score'] as int?;

    return MusicScraperItem(
      externalId: id,
      source: type,
      title: title,
      artist: artist,
      album: album,
      year: year,
      durationMs: lengthMs,
      score: score != null ? score / 100 : null,
    );
  }

  MusicScraperDetail _parseRecordingDetail(Map<String, dynamic> data) {
    final id = data['id'] as String? ?? '';
    final title = data['title'] as String? ?? '';

    String? artist;
    final artistCredit = (data['artist-credit'] as List?)?.cast<Map<String, dynamic>>();
    if (artistCredit != null && artistCredit.isNotEmpty) {
      artist = artistCredit.map((ac) {
        final artistData = ac['artist'] as Map<String, dynamic>?;
        final name = ac['name'] as String? ?? artistData?['name'] as String? ?? '';
        final joinPhrase = ac['joinphrase'] as String? ?? '';
        return '$name$joinPhrase';
      }).join();
    }

    String? album;
    String? albumArtist;
    int? year;
    int? trackNumber;
    int? discNumber;
    String? releaseDate;
    String? label;

    final releases = (data['releases'] as List?)?.cast<Map<String, dynamic>>();
    if (releases != null && releases.isNotEmpty) {
      final firstRelease = releases.first;
      album = firstRelease['title'] as String?;

      final date = firstRelease['date'] as String?;
      releaseDate = date;
      if (date != null && date.length >= 4) {
        year = int.tryParse(date.substring(0, 4));
      }

      final labelInfo = (firstRelease['label-info'] as List?)?.cast<Map<String, dynamic>>();
      if (labelInfo != null && labelInfo.isNotEmpty) {
        final labelData = labelInfo.first['label'] as Map<String, dynamic>?;
        label = labelData?['name'] as String?;
      }

      final media = (firstRelease['media'] as List?)?.cast<Map<String, dynamic>>();
      if (media != null && media.isNotEmpty) {
        for (var i = 0; i < media.length; i++) {
          final disc = media[i];
          final tracks = (disc['tracks'] as List?)?.cast<Map<String, dynamic>>();
          if (tracks != null) {
            for (final track in tracks) {
              final recording = track['recording'] as Map<String, dynamic>?;
              if (recording?['id'] == id) {
                trackNumber = track['position'] as int?;
                discNumber = i + 1;
                break;
              }
            }
          }
        }
      }

      final releaseArtistCredit = (firstRelease['artist-credit'] as List?)?.cast<Map<String, dynamic>>();
      if (releaseArtistCredit != null && releaseArtistCredit.isNotEmpty) {
        albumArtist = releaseArtistCredit.map((ac) {
          final artistData = ac['artist'] as Map<String, dynamic>?;
          final name = ac['name'] as String? ?? artistData?['name'] as String? ?? '';
          final joinPhrase = ac['joinphrase'] as String? ?? '';
          return '$name$joinPhrase';
        }).join();
      }
    }

    final lengthMs = data['length'] as int?;

    final genres = (data['genres'] as List?)?.cast<Map<String, dynamic>>()
        .map((g) => g['name'] as String?)
        .where((name) => name != null && name.isNotEmpty)
        .cast<String>()
        .toList();

    String? isrc;
    final isrcs = data['isrcs'] as List?;
    if (isrcs != null && isrcs.isNotEmpty) {
      isrc = isrcs.first as String?;
    }

    return MusicScraperDetail(
      externalId: id,
      source: type,
      title: title,
      artist: artist,
      albumArtist: albumArtist,
      album: album,
      year: year,
      trackNumber: trackNumber,
      discNumber: discNumber,
      durationMs: lengthMs,
      genres: genres,
      mbid: id,
      isrc: isrc,
      releaseDate: releaseDate,
      label: label,
    );
  }

  MusicScraperException _handleDioError(DioException e) {
    if (e.response?.statusCode == 401) {
      return MusicScraperAuthException(
        '认证失败',
        source: type,
        cause: e,
      );
    }
    if (e.response?.statusCode == 429) {
      final retryAfter = int.tryParse(
        e.response?.headers.value('retry-after') ?? '',
      );
      return MusicScraperRateLimitException(
        '请求过于频繁，请稍后再试',
        source: type,
        cause: e,
        retryAfter: retryAfter,
      );
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return MusicScraperNetworkException(
        '网络连接失败',
        source: type,
        cause: e,
      );
    }
    return MusicScraperException(
      e.message ?? '未知错误',
      source: type,
      cause: e,
    );
  }
}
