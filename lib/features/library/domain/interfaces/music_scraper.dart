import '../entities/music_scraper_result.dart';
import '../entities/scraper_source_entity.dart';

/// 音乐刮削器接口
abstract class MusicScraper {
  /// 刮削源类型
  ScraperType get type;

  /// 是否已配置（有必要的凭证）
  bool get isConfigured;

  /// 测试连接
  Future<bool> testConnection();

  /// 搜索音乐
  ///
  /// [query] 搜索关键词
  /// [artist] 艺术家过滤（可选）
  /// [album] 专辑过滤（可选）
  /// [page] 页码
  /// [limit] 每页数量
  Future<MusicScraperSearchResult> search(
    String query, {
    String? artist,
    String? album,
    int page = 1,
    int limit = 20,
  });

  /// 获取音乐详情
  ///
  /// [externalId] 外部 ID（如 MusicBrainz Recording ID、网易云歌曲 ID）
  Future<MusicScraperDetail?> getDetail(String externalId);

  /// 获取封面列表
  ///
  /// [externalId] 外部 ID
  /// 返回可用的封面列表（可能有多个分辨率/类型）
  Future<List<CoverScraperResult>> getCoverArt(String externalId);

  /// 获取歌词
  ///
  /// [externalId] 外部 ID
  Future<LyricScraperResult?> getLyrics(String externalId);

  /// 释放资源
  void dispose();
}

/// 声纹识别刮削器接口
abstract class FingerprintScraper extends MusicScraper {
  /// 通过声纹查找
  ///
  /// [fingerprint] Chromaprint 指纹字符串
  /// [duration] 音频时长（秒）
  Future<FingerprintResult?> lookupByFingerprint(
    String fingerprint,
    int duration,
  );
}

/// 刮削器异常
class MusicScraperException implements Exception {
  const MusicScraperException(
    this.message, {
    this.source,
    this.cause,
  });

  /// 错误信息
  final String message;

  /// 来源
  final ScraperType? source;

  /// 原始异常
  final Object? cause;

  @override
  String toString() {
    final sourceStr = source != null ? '[${source!.displayName}] ' : '';
    return 'MusicScraperException: $sourceStr$message';
  }
}

/// 认证错误
class MusicScraperAuthException extends MusicScraperException {
  const MusicScraperAuthException(
    super.message, {
    super.source,
    super.cause,
  });
}

/// 速率限制错误
class MusicScraperRateLimitException extends MusicScraperException {
  const MusicScraperRateLimitException(
    super.message, {
    super.source,
    super.cause,
    this.retryAfter,
  });

  /// 建议的重试等待时间（秒）
  final int? retryAfter;
}

/// 网络错误
class MusicScraperNetworkException extends MusicScraperException {
  const MusicScraperNetworkException(
    super.message, {
    super.source,
    super.cause,
  });
}

/// 未找到错误
class MusicScraperNotFoundException extends MusicScraperException {
  const MusicScraperNotFoundException(
    super.message, {
    super.source,
    super.cause,
  });
}
