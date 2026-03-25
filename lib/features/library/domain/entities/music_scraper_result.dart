import 'scraper_source_entity.dart';

/// 音乐搜索结果
class MusicScraperSearchResult {
  const MusicScraperSearchResult({
    required this.items,
    required this.source,
    this.page = 1,
    this.totalPages = 1,
    this.totalResults = 0,
  });

  factory MusicScraperSearchResult.empty([ScraperType? source]) =>
      MusicScraperSearchResult(
        items: const [],
        source: source ?? ScraperType.musicBrainz,
      );

  /// 搜索结果列表
  final List<MusicScraperItem> items;

  /// 来源类型
  final ScraperType source;

  /// 当前页码
  final int page;

  /// 总页数
  final int totalPages;

  /// 总结果数
  final int totalResults;

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;
  bool get hasMore => page < totalPages;
}

/// 音乐搜索结果项
class MusicScraperItem {
  const MusicScraperItem({
    required this.externalId,
    required this.source,
    required this.title,
    this.artist,
    this.album,
    this.year,
    this.durationMs,
    this.coverUrl,
    this.score,
    this.trackNumber,
    this.genres,
  });

  /// 外部 ID（MusicBrainz Recording ID、网易云歌曲 ID 等）
  final String externalId;

  /// 来源类型
  final ScraperType source;

  /// 标题
  final String title;

  /// 艺术家
  final String? artist;

  /// 专辑
  final String? album;

  /// 年份
  final int? year;

  /// 时长（毫秒）
  final int? durationMs;

  /// 封面 URL
  final String? coverUrl;

  /// 匹配分数（0-1，用于声纹识别）
  final double? score;

  /// 音轨号
  final int? trackNumber;

  /// 流派列表
  final List<String>? genres;

  /// 格式化时长
  String get durationText {
    if (durationMs == null) return '';
    final duration = Duration(milliseconds: durationMs!);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// 流派文本
  String get genresText => genres?.join(' / ') ?? '';

  /// 匹配分数文本
  String get scoreText => score != null ? '${(score! * 100).toStringAsFixed(0)}%' : '';
}

/// 音乐详情
class MusicScraperDetail {
  const MusicScraperDetail({
    required this.externalId,
    required this.source,
    required this.title,
    this.artist,
    this.albumArtist,
    this.album,
    this.year,
    this.trackNumber,
    this.discNumber,
    this.totalTracks,
    this.totalDiscs,
    this.durationMs,
    this.genres,
    this.coverUrl,
    this.mbid,
    this.isrc,
    this.releaseDate,
    this.label,
    this.composer,
    this.lyricist,
  });

  /// 外部 ID
  final String externalId;

  /// 来源类型
  final ScraperType source;

  /// 标题
  final String title;

  /// 艺术家
  final String? artist;

  /// 专辑艺术家
  final String? albumArtist;

  /// 专辑
  final String? album;

  /// 年份
  final int? year;

  /// 音轨号
  final int? trackNumber;

  /// 碟号
  final int? discNumber;

  /// 总音轨数
  final int? totalTracks;

  /// 总碟数
  final int? totalDiscs;

  /// 时长（毫秒）
  final int? durationMs;

  /// 流派列表
  final List<String>? genres;

  /// 封面 URL
  final String? coverUrl;

  /// MusicBrainz ID
  final String? mbid;

  /// ISRC 码
  final String? isrc;

  /// 发行日期
  final String? releaseDate;

  /// 唱片公司
  final String? label;

  /// 作曲家
  final String? composer;

  /// 作词家
  final String? lyricist;

  /// 格式化时长
  String get durationText {
    if (durationMs == null) return '';
    final duration = Duration(milliseconds: durationMs!);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// 流派文本
  String get genresText => genres?.join(' / ') ?? '';

  /// 音轨信息文本
  String get trackInfo {
    if (trackNumber == null) return '';
    if (totalTracks != null) {
      return '$trackNumber/$totalTracks';
    }
    return trackNumber.toString();
  }

  /// 碟号信息文本
  String get discInfo {
    if (discNumber == null) return '';
    if (totalDiscs != null) {
      return '$discNumber/$totalDiscs';
    }
    return discNumber.toString();
  }
}

/// 歌词结果
class LyricScraperResult {
  const LyricScraperResult({
    required this.source,
    this.lrcContent,
    this.plainText,
    this.translation,
    this.title,
    this.artist,
  });

  /// 来源类型
  final ScraperType source;

  /// LRC 格式歌词
  final String? lrcContent;

  /// 纯文本歌词
  final String? plainText;

  /// 翻译歌词
  final String? translation;

  /// 歌曲标题
  final String? title;

  /// 艺术家
  final String? artist;

  /// 是否有有效歌词
  bool get hasLyrics =>
      (lrcContent != null && lrcContent!.isNotEmpty) ||
      (plainText != null && plainText!.isNotEmpty);

  /// 是否为 LRC 格式
  bool get isLrc => lrcContent != null && lrcContent!.isNotEmpty;

  /// 是否有翻译
  bool get hasTranslation => translation != null && translation!.isNotEmpty;

  /// 获取合并的歌词内容（原文 + 翻译）
  String? get mergedLyrics {
    if (!hasLyrics) return null;
    if (!hasTranslation) return lrcContent ?? plainText;
    return lrcContent ?? plainText;
  }
}

/// 封面结果
class CoverScraperResult {
  const CoverScraperResult({
    required this.source,
    required this.coverUrl,
    this.thumbnailUrl,
    this.width,
    this.height,
    this.type = CoverType.front,
    this.comment,
  });

  /// 来源类型
  final ScraperType source;

  /// 封面 URL
  final String coverUrl;

  /// 缩略图 URL
  final String? thumbnailUrl;

  /// 宽度
  final int? width;

  /// 高度
  final int? height;

  /// 封面类型
  final CoverType type;

  /// 备注
  final String? comment;

  /// 分辨率文本
  String get resolutionText {
    if (width == null || height == null) return '';
    return '${width}x$height';
  }
}

/// 封面类型
enum CoverType {
  front('封面'),
  back('背面'),
  booklet('内页'),
  medium('光盘'),
  other('其他');

  const CoverType(this.displayName);
  final String displayName;
}

/// 声纹识别结果
class FingerprintResult {
  const FingerprintResult({
    required this.fingerprint,
    required this.duration,
    required this.matches,
  });

  /// 创建空结果
  factory FingerprintResult.empty({
    String fingerprint = '',
    int duration = 0,
  }) =>
      FingerprintResult(
        fingerprint: fingerprint,
        duration: duration,
        matches: const [],
      );

  /// Chromaprint 指纹
  final String fingerprint;

  /// 音频时长（秒）
  final int duration;

  /// 匹配结果列表
  final List<FingerprintMatch> matches;

  bool get isEmpty => matches.isEmpty;
  bool get isNotEmpty => matches.isNotEmpty;

  /// 获取最佳匹配
  FingerprintMatch? get bestMatch => matches.isNotEmpty ? matches.first : null;
}

/// 声纹匹配结果
class FingerprintMatch {
  const FingerprintMatch({
    required this.recordingId,
    required this.score,
    this.title,
    this.artist,
    this.album,
    this.releaseId,
    this.year,
  });

  /// MusicBrainz Recording ID
  final String recordingId;

  /// 匹配分数（0-1）
  final double score;

  /// 标题
  final String? title;

  /// 艺术家
  final String? artist;

  /// 专辑
  final String? album;

  /// MusicBrainz Release ID
  final String? releaseId;

  /// 年份
  final int? year;

  /// 分数百分比文本
  String get scorePercent => '${(score * 100).toStringAsFixed(0)}%';
}

/// 综合刮削结果（包含所有可获取的数据）
class MusicScrapeResult {
  const MusicScrapeResult({
    this.detail,
    this.cover,
    this.lyrics,
    this.fingerprint,
    this.errors = const [],
  });

  /// 元数据详情
  final MusicScraperDetail? detail;

  /// 封面
  final CoverScraperResult? cover;

  /// 歌词
  final LyricScraperResult? lyrics;

  /// 声纹识别结果
  final FingerprintResult? fingerprint;

  /// 错误列表（各源的错误）
  final List<String> errors;

  bool get hasDetail => detail != null;
  bool get hasCover => cover != null;
  bool get hasLyrics => lyrics?.hasLyrics ?? false;
  bool get hasFingerprint => fingerprint?.isNotEmpty ?? false;
  bool get hasErrors => errors.isNotEmpty;

  /// 是否有任何数据
  bool get hasAnyData => hasDetail || hasCover || hasLyrics || hasFingerprint;
}
