import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../../domain/entities/music_scraper_result.dart';
import '../../domain/entities/scraper_source_entity.dart';
import '../../domain/interfaces/music_scraper.dart';
import 'music_scraper_factory.dart';
import 'scraper_config_store.dart';

/// 音乐刮削管理服务
///
/// 管理多个刮削源，提供统一的搜索、获取元数据、封面、歌词接口。
/// 默认仅启用开源刮削器（MusicBrainz + LRCLIB）。
/// 用户可通过导入 JSON 配置添加自定义刮削源。
class MusicScraperManagerService {
  static const String _boxName = 'music_scrapers';
  static const String _credentialBoxName = 'music_scraper_credentials';
  static const String _settingsBoxName = 'music_scraper_settings';

  Box<dynamic>? _box;
  Box<dynamic>? _credentialBox;
  Box<dynamic>? _settingsBox;
  final Map<String, MusicScraper> _scraperCache = {};

  /// 初始化
  Future<void> init() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<dynamic>(_boxName);
    _credentialBox = await Hive.openBox<dynamic>(_credentialBoxName);
    _settingsBox = await Hive.openBox<dynamic>(_settingsBoxName);
    // 确保 ScraperConfigStore 也已初始化
    await ScraperConfigStore.instance.getAllConfigs();
  }

  /// 确保已初始化
  Future<void> _ensureInit() async {
    if (_box == null || !_box!.isOpen) {
      await init();
    }
  }

  // ===== 设置 =====

  /// 仅填充缺失字段（默认 true）
  bool get onlyFillMissingFields {
    return _settingsBox?.get('onlyFillMissingFields', defaultValue: true) as bool? ?? true;
  }

  set onlyFillMissingFields(bool value) {
    _settingsBox?.put('onlyFillMissingFields', value);
  }

  // ===== 标题清洗 =====

  /// 清洗标题以提升搜索匹配率
  /// 移除括号内容、编号前缀、破折号后缀等
  /// 参考 primuse ScraperManager.cleanTitle
  static String cleanTitle(String title) {
    var result = title;
    // 移除各种括号及内容
    result = result.replaceAll(RegExp(r'\([^)]*\)'), '');
    result = result.replaceAll(RegExp(r'（[^）]*）'), '');
    result = result.replaceAll(RegExp(r'\[[^\]]*\]'), '');
    result = result.replaceAll(RegExp(r'【[^】]*】'), '');
    // 移除破折号后的内容
    final dashMatch = RegExp(r'\s*[–—-]\s+').firstMatch(result);
    if (dashMatch != null) {
      result = result.substring(0, dashMatch.start);
    }
    result = result.trim();
    // 移除开头的数字编号（如 "01. "）
    result = result.replaceAll(RegExp(r'^\d+[.\s]+'), '');
    return result.trim();
  }

  // ===== 刮削源 CRUD =====

  /// 获取所有刮削源（按优先级排序）
  Future<List<ScraperSourceEntity>> getSources() async {
    await _ensureInit();

    // 检查是否需要初始化默认源
    if (_box!.isEmpty) {
      await _initDefaultSources();
    }

    final sources = <ScraperSourceEntity>[];
    for (final key in _box!.keys) {
      final data = _box!.get(key);
      if (data != null && data is Map) {
        try {
          final source = ScraperSourceEntity.fromJson(
            Map<String, dynamic>.from(data),
          );

          // 过滤掉引用了已不存在配置的 custom 源
          if (source.type == ScraperType.custom && source.configId != null) {
            final config = ScraperConfigStore.instance.getConfigSync(source.configId!);
            if (config == null) continue; // 配置已被删除
          }

          // 跳过不再支持的旧类型（迁移兼容）
          if (source.type != ScraperType.musicBrainz &&
              source.type != ScraperType.lrclib &&
              source.type != ScraperType.custom) {
            continue;
          }

          // 加载凭证
          final credential = await getCredential(source.id);
          if (credential != null && !credential.isEmpty) {
            sources.add(source.copyWith(
              apiKey: credential.apiKey ?? source.apiKey,
              cookie: credential.cookie ?? source.cookie,
            ));
          } else {
            sources.add(source);
          }
        } on Exception catch (e) {
          debugPrint('解析刮削源配置失败: $key - $e');
        }
      }
    }

    // 确保内置源存在
    await _ensureBuiltInSources(sources);

    // 按优先级排序
    sources.sort((a, b) => a.priority.compareTo(b.priority));
    return sources;
  }

  /// 初始化默认刮削源（仅开源源）
  Future<void> _initDefaultSources() async {
    final defaultSources = [
      (ScraperType.musicBrainz, true),
      (ScraperType.lrclib, true),
    ];

    for (var i = 0; i < defaultSources.length; i++) {
      final (type, isEnabled) = defaultSources[i];
      final source = ScraperSourceEntity(
        name: '',
        type: type,
        isEnabled: isEnabled,
        priority: i,
      );
      await _box!.put(source.id, source.toJson());
    }
  }

  /// 确保内置源存在（用于从旧版本迁移的用户）
  Future<void> _ensureBuiltInSources(List<ScraperSourceEntity> existingSources) async {
    final existingTypes = existingSources.map((s) => s.type).toSet();
    final builtInTypes = [ScraperType.musicBrainz, ScraperType.lrclib];

    var maxPriority = existingSources.isEmpty
        ? -1
        : existingSources.map((s) => s.priority).reduce((a, b) => a > b ? a : b);

    for (final type in builtInTypes) {
      if (!existingTypes.contains(type)) {
        maxPriority++;
        final source = ScraperSourceEntity(
          name: '',
          type: type,
          isEnabled: true,
          priority: maxPriority,
        );
        await _box!.put(source.id, source.toJson());
        existingSources.add(source);
      }
    }
  }

  /// 获取单个刮削源
  Future<ScraperSourceEntity?> getSource(String id) async {
    await _ensureInit();

    final data = _box!.get(id);
    if (data == null || data is! Map) return null;

    try {
      final source = ScraperSourceEntity.fromJson(
        Map<String, dynamic>.from(data),
      );
      final credential = await getCredential(id);
      if (credential != null && !credential.isEmpty) {
        return source.copyWith(
          apiKey: credential.apiKey ?? source.apiKey,
          cookie: credential.cookie ?? source.cookie,
        );
      }
      return source;
    } on Exception catch (e) {
      debugPrint('解析刮削源配置失败: $id - $e');
      return null;
    }
  }

  /// 添加刮削源
  Future<ScraperSourceEntity> addSource(ScraperSourceEntity source) async {
    await _ensureInit();

    final sources = await getSources();
    final newPriority = sources.isEmpty ? 0 : sources.last.priority + 1;
    final newSource = source.copyWith(priority: newPriority);

    // 保存配置（不含敏感信息）
    await _box!.put(newSource.id, newSource.toJson()
      ..remove('apiKey')
      ..remove('cookie'));

    // 保存凭证
    if (source.apiKey != null || source.cookie != null) {
      await saveCredential(
        newSource.id,
        ScraperCredential(
          apiKey: source.apiKey,
          cookie: source.cookie,
        ),
      );
    }

    _scraperCache.remove(newSource.id);
    return newSource;
  }

  /// 更新刮削源
  Future<void> updateSource(ScraperSourceEntity source) async {
    await _ensureInit();

    await _box!.put(source.id, source.toJson()
      ..remove('apiKey')
      ..remove('cookie'));

    if (source.apiKey != null || source.cookie != null) {
      await saveCredential(
        source.id,
        ScraperCredential(
          apiKey: source.apiKey,
          cookie: source.cookie,
        ),
      );
    }

    _scraperCache.remove(source.id);
  }

  /// 删除刮削源
  Future<void> removeSource(String id) async {
    await _ensureInit();

    await _box!.delete(id);
    await removeCredential(id);

    _scraperCache[id]?.dispose();
    _scraperCache.remove(id);
  }

  /// 切换启用状态
  Future<void> toggleSource(String id, {required bool isEnabled}) async {
    final source = await getSource(id);
    if (source != null) {
      await updateSource(source.copyWith(isEnabled: isEnabled));
    }
  }

  /// 调整优先级顺序
  Future<void> reorderSources(List<String> orderedIds) async {
    await _ensureInit();

    for (var i = 0; i < orderedIds.length; i++) {
      final source = await getSource(orderedIds[i]);
      if (source != null) {
        await updateSource(source.copyWith(priority: i));
      }
    }
  }

  // ===== 凭证管理 =====

  /// 保存凭证
  Future<void> saveCredential(String sourceId, ScraperCredential credential) async {
    await _ensureInit();
    await _credentialBox!.put(sourceId, json.encode(credential.toJson()));
  }

  /// 获取凭证
  Future<ScraperCredential?> getCredential(String sourceId) async {
    await _ensureInit();
    final value = _credentialBox!.get(sourceId) as String?;
    if (value == null) return null;
    try {
      return ScraperCredential.fromJson(
        json.decode(value) as Map<String, dynamic>,
      );
    } on Exception {
      return null;
    }
  }

  /// 删除凭证
  Future<void> removeCredential(String sourceId) async {
    await _ensureInit();
    await _credentialBox!.delete(sourceId);
  }

  // ===== 刮削器访问 =====

  /// 获取刮削器实例
  Future<MusicScraper?> getScraper(String sourceId) async {
    if (_scraperCache.containsKey(sourceId)) {
      return _scraperCache[sourceId];
    }

    final source = await getSource(sourceId);
    if (source == null || !source.isConfigured) return null;

    try {
      final scraper = MusicScraperFactory.create(source);
      _scraperCache[sourceId] = scraper;
      return scraper;
    } on Exception catch (e) {
      debugPrint('创建刮削器失败: ${source.type} - $e');
      return null;
    }
  }

  /// 获取所有已启用且已配置的刮削器
  Future<List<(ScraperSourceEntity, MusicScraper)>> getEnabledScrapers() async {
    final sources = await getSources();
    final result = <(ScraperSourceEntity, MusicScraper)>[];

    for (final source in sources) {
      if (!source.isEnabled) continue;
      if (!source.isConfigured) continue;

      final scraper = await getScraper(source.id);
      if (scraper != null) {
        result.add((source, scraper));
      }
    }

    return result;
  }

  /// 清除刮削器缓存（设置变更后调用）
  void invalidateCache() {
    for (final scraper in _scraperCache.values) {
      scraper.dispose();
    }
    _scraperCache.clear();
  }

  // ===== 统一刮削接口 =====

  /// 搜索音乐（按优先级尝试所有已启用的源）
  Future<List<MusicScraperSearchResult>> search(
    String query, {
    String? artist,
    String? album,
    int limit = 20,
  }) async {
    final scrapers = await getEnabledScrapers();
    final results = <MusicScraperSearchResult>[];
    final cleanedQuery = cleanTitle(query);

    for (final (source, scraper) in scrapers) {
      try {
        final result = await scraper.search(
          cleanedQuery,
          artist: artist,
          album: album,
          limit: limit,
        );
        if (result.isNotEmpty) {
          results.add(result);
        }
      } on Exception catch (e) {
        debugPrint('[MusicScraperManager] ${source.displayName} search failed: $e');
      }
    }

    return results;
  }

  /// 获取音乐详情
  Future<MusicScraperDetail?> getDetail(
    String externalId,
    ScraperType sourceType,
  ) async {
    final sources = await getSources();
    final source = sources.where((s) => s.type == sourceType).firstOrNull;
    if (source == null) return null;

    final scraper = await getScraper(source.id);
    if (scraper == null) return null;

    try {
      return await scraper.getDetail(externalId);
    } on Exception catch (e) {
      debugPrint('获取详情失败: $sourceType - $e');
      return null;
    }
  }

  /// 获取封面（尝试所有支持封面的源）
  Future<CoverScraperResult?> getCover({
    String? title,
    String? artist,
    String? album,
  }) async {
    if (title == null && artist == null && album == null) return null;

    final scrapers = await getEnabledScrapers();
    final cleanedTitle = title != null ? cleanTitle(title) : null;

    for (final (source, scraper) in scrapers) {
      if (!source.effectiveSupportsCover) continue;

      try {
        final searchResult = await scraper.search(
          cleanedTitle ?? '',
          artist: artist,
          album: album,
          limit: 1,
        );

        if (searchResult.isEmpty) continue;

        final covers = await scraper.getCoverArt(searchResult.items.first.externalId);
        if (covers.isNotEmpty) {
          return covers.first;
        }

        final item = searchResult.items.first;
        if (item.coverUrl != null) {
          return CoverScraperResult(
            source: source.type,
            coverUrl: item.coverUrl!,
          );
        }
      } on Exception catch (e) {
        debugPrint('获取封面失败: ${source.displayName} - $e');
      }
    }

    return null;
  }

  /// 获取歌词（尝试所有支持歌词的源）
  Future<LyricScraperResult?> getLyrics({
    String? title,
    String? artist,
    String? album,
    Duration? duration,
  }) async {
    if (title == null) return null;

    final scrapers = await getEnabledScrapers();
    final cleanedTitle = cleanTitle(title);

    for (final (source, scraper) in scrapers) {
      if (!source.effectiveSupportsLyrics) continue;

      try {
        // LRCLIB 特殊处理：直接查找
        if (source.type == ScraperType.lrclib && artist != null) {
          try {
            final lrclibScraper = scraper as dynamic;
            final lyricsResult = await lrclibScraper.fetchLyrics(
              title: cleanedTitle,
              artist: artist,
              album: album,
              duration: duration,
            );
            if (lyricsResult != null && lyricsResult.hasLyrics) {
              return lyricsResult as LyricScraperResult;
            }
          } on Exception {
            // fallback to standard search flow
          }
        }

        final searchResult = await scraper.search(
          cleanedTitle,
          artist: artist,
          limit: 1,
        );

        if (searchResult.isEmpty) continue;

        final lyrics = await scraper.getLyrics(searchResult.items.first.externalId);
        if (lyrics != null && lyrics.hasLyrics) {
          return lyrics;
        }
      } on Exception catch (e) {
        debugPrint('获取歌词失败: ${source.displayName} - $e');
      }
    }

    return null;
  }

  /// 综合刮削（获取所有可用数据）
  Future<MusicScrapeResult> scrape({
    required String title,
    String? artist,
    String? album,
    bool getCover = true,
    bool getLyrics = true,
  }) async {
    MusicScraperDetail? detail;
    CoverScraperResult? cover;
    LyricScraperResult? lyrics;
    final errors = <String>[];

    final scrapers = await getEnabledScrapers();
    final cleanedTitle = cleanTitle(title);

    // 1. 搜索并获取详情
    for (final (source, scraper) in scrapers) {
      if (detail != null) break;
      if (!source.effectiveSupportsMetadata) continue;

      try {
        final searchResult = await scraper.search(
          cleanedTitle,
          artist: artist,
          album: album,
          limit: 15,
        );

        if (searchResult.isNotEmpty) {
          detail = await scraper.getDetail(searchResult.items.first.externalId);
        }
      } on Exception catch (e) {
        errors.add('[${source.displayName}] 搜索失败: $e');
      }
    }

    // 2. 获取封面
    if (getCover) {
      for (final (source, scraper) in scrapers) {
        if (cover != null) break;
        if (!source.effectiveSupportsCover) continue;

        try {
          // 如果详情中已有封面且来源相同，直接使用
          if (detail != null && detail!.coverUrl != null && detail!.source == source.type) {
            cover = CoverScraperResult(
              source: source.type,
              coverUrl: detail!.coverUrl!,
            );
            break;
          }

          final searchResult = await scraper.search(
            cleanedTitle,
            artist: artist,
            album: album,
            limit: 1,
          );

          if (searchResult.isNotEmpty) {
            final item = searchResult.items.first;
            final covers = await scraper.getCoverArt(item.externalId);
            if (covers.isNotEmpty) {
              cover = covers.first;
            } else if (item.coverUrl != null) {
              cover = CoverScraperResult(
                source: source.type,
                coverUrl: item.coverUrl!,
              );
            }
          }
        } on Exception catch (e) {
          errors.add('[${source.displayName}] 获取封面失败: $e');
        }
      }
    }

    // 3. 获取歌词
    if (getLyrics) {
      for (final (source, scraper) in scrapers) {
        if (lyrics != null) break;
        if (!source.effectiveSupportsLyrics) continue;

        try {
          // LRCLIB 特殊处理
          if (source.type == ScraperType.lrclib && artist != null) {
            try {
              final lrclibScraper = scraper as dynamic;
              final lyricsResult = await lrclibScraper.fetchLyrics(
                title: cleanedTitle,
                artist: artist,
                album: album,
              );
              if (lyricsResult != null && lyricsResult.hasLyrics) {
                lyrics = lyricsResult as LyricScraperResult;
                break;
              }
            } on Exception {
              // fallback
            }
          }

          final searchResult = await scraper.search(
            cleanedTitle,
            artist: artist,
            limit: 1,
          );

          if (searchResult.isNotEmpty) {
            lyrics = await scraper.getLyrics(searchResult.items.first.externalId);
          }
        } on Exception catch (e) {
          errors.add('[${source.displayName}] 获取歌词失败: $e');
        }
      }
    }

    return MusicScrapeResult(
      detail: detail,
      cover: cover,
      lyrics: lyrics,
      errors: errors,
    );
  }

  /// 通过音频指纹查找音乐信息
  Future<FingerprintResult?> lookupByFingerprint(
    String fingerprint,
    int duration,
  ) async {
    // 当前无内置指纹服务
    return null;
  }

  /// 释放资源
  void dispose() {
    for (final scraper in _scraperCache.values) {
      scraper.dispose();
    }
    _scraperCache.clear();
  }
}
