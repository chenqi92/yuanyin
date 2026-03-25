import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../../domain/entities/music_scraper_result.dart';
import '../../domain/entities/scraper_source_entity.dart';
import '../../domain/interfaces/music_scraper.dart';
import 'music_scraper_factory.dart';

/// 音乐刮削管理服务
///
/// 管理多个刮削源，提供统一的搜索、获取元数据、封面、歌词接口
class MusicScraperManagerService {
  static const String _boxName = 'music_scrapers';
  static const String _credentialBoxName = 'music_scraper_credentials';

  Box<dynamic>? _box;
  Box<dynamic>? _credentialBox;
  final Map<String, MusicScraper> _scraperCache = {};

  /// 初始化
  Future<void> init() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<dynamic>(_boxName);
    _credentialBox = await Hive.openBox<dynamic>(_credentialBoxName);
  }

  /// 确保已初始化
  Future<void> _ensureInit() async {
    if (_box == null || !_box!.isOpen) {
      await init();
    }
  }

  // ===== 刮削源 CRUD =====

  /// 获取所有刮削源（按优先级排序）
  Future<List<ScraperSourceEntity>> getSources() async {
    await _ensureInit();

    // 检查是否需要初始化默认源
    if (_box!.isEmpty) {
      await _initDefaultSources();
    } else {
      // 为已有用户添加新的刮削源类型
      await _addMissingDefaultSources();
    }

    final sources = <ScraperSourceEntity>[];
    for (final key in _box!.keys) {
      final data = _box!.get(key);
      if (data != null && data is Map) {
        try {
          final source = ScraperSourceEntity.fromJson(
            Map<String, dynamic>.from(data),
          );
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

    // 按优先级排序
    sources.sort((a, b) => a.priority.compareTo(b.priority));
    return sources;
  }

  /// 初始化默认刮削源
  Future<void> _initDefaultSources() async {
    final defaultTypes = [
      (ScraperType.kugouMusic, true),
      (ScraperType.kuwoMusic, true),
      (ScraperType.miguMusic, true),
      (ScraperType.qqMusic, true),
      (ScraperType.neteaseMusic, true),
      (ScraperType.musicBrainz, false),
    ];

    for (var i = 0; i < defaultTypes.length; i++) {
      final (type, isEnabled) = defaultTypes[i];
      final source = ScraperSourceEntity(
        name: '',
        type: type,
        isEnabled: isEnabled,
        priority: i,
      );
      await _box!.put(source.id, source.toJson());
    }
  }

  /// 为已有用户添加缺失的默认刮削源
  Future<void> _addMissingDefaultSources() async {
    final defaultTypes = [
      (ScraperType.kugouMusic, true),
      (ScraperType.kuwoMusic, true),
      (ScraperType.miguMusic, true),
      (ScraperType.qqMusic, true),
      (ScraperType.neteaseMusic, true),
      (ScraperType.musicBrainz, false),
    ];

    final existingTypes = <ScraperType>{};
    for (final key in _box!.keys) {
      final data = _box!.get(key);
      if (data != null && data is Map) {
        try {
          final source = ScraperSourceEntity.fromJson(
            Map<String, dynamic>.from(data),
          );
          existingTypes.add(source.type);
        } on Exception {
          // 忽略解析错误
        }
      }
    }

    final missingTypesWithEnabled = defaultTypes
        .where((t) => !existingTypes.contains(t.$1))
        .toList();
    if (missingTypesWithEnabled.isEmpty) return;

    var maxPriority = 0;
    for (final key in _box!.keys) {
      final data = _box!.get(key);
      if (data != null && data is Map) {
        final priority = data['priority'] as int? ?? 0;
        if (priority > maxPriority) maxPriority = priority;
      }
    }

    for (var i = 0; i < missingTypesWithEnabled.length; i++) {
      final (type, isEnabled) = missingTypesWithEnabled[i];
      final source = ScraperSourceEntity(
        name: '',
        type: type,
        isEnabled: isEnabled,
        priority: maxPriority + 1 + i,
      );
      await _box!.put(source.id, source.toJson());
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
    if (!MusicScraperFactory.isImplemented(source.type)) return null;

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
      if (!MusicScraperFactory.isImplemented(source.type)) continue;

      final scraper = await getScraper(source.id);
      if (scraper != null) {
        result.add((source, scraper));
      }
    }

    return result;
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

    for (final (source, scraper) in scrapers) {
      try {
        final result = await scraper.search(
          query,
          artist: artist,
          album: album,
          limit: limit,
        );
        if (result.isNotEmpty) {
          results.add(result);
        }
      } on Exception catch (e) {
        debugPrint('[MusicScraperManager] ${source.type.displayName} search failed: $e');
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

    for (final (source, scraper) in scrapers) {
      if (!source.type.supportsCover) continue;

      try {
        final searchResult = await scraper.search(
          title ?? '',
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
        debugPrint('获取封面失败: ${source.type.displayName} - $e');
      }
    }

    return null;
  }

  /// 获取歌词（尝试所有支持歌词的源）
  Future<LyricScraperResult?> getLyrics({
    String? title,
    String? artist,
  }) async {
    if (title == null) return null;

    final scrapers = await getEnabledScrapers();

    for (final (source, scraper) in scrapers) {
      if (!source.type.supportsLyrics) continue;

      try {
        final searchResult = await scraper.search(
          title,
          artist: artist,
          limit: 1,
        );

        if (searchResult.isEmpty) continue;

        final lyrics = await scraper.getLyrics(searchResult.items.first.externalId);
        if (lyrics != null && lyrics.hasLyrics) {
          return lyrics;
        }
      } on Exception catch (e) {
        debugPrint('获取歌词失败: ${source.type.displayName} - $e');
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

    // 1. 搜索并获取详情
    for (final (source, scraper) in scrapers) {
      if (detail != null) break;

      try {
        final searchResult = await scraper.search(
          title,
          artist: artist,
          album: album,
          limit: 1,
        );

        if (searchResult.isNotEmpty) {
          detail = await scraper.getDetail(searchResult.items.first.externalId);
        }
      } on Exception catch (e) {
        errors.add('[${source.type.displayName}] 搜索失败: $e');
      }
    }

    // 2. 获取封面
    if (getCover) {
      for (final (source, scraper) in scrapers) {
        if (cover != null) break;
        if (!source.type.supportsCover) continue;

        try {
          final searchResult = await scraper.search(
            title,
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
          errors.add('[${source.type.displayName}] 获取封面失败: $e');
        }
      }
    }

    // 3. 获取歌词
    if (getLyrics) {
      for (final (source, scraper) in scrapers) {
        if (lyrics != null) break;
        if (!source.type.supportsLyrics) continue;

        try {
          final searchResult = await scraper.search(
            title,
            artist: artist,
            limit: 1,
          );

          if (searchResult.isNotEmpty) {
            lyrics = await scraper.getLyrics(searchResult.items.first.externalId);
          }
        } on Exception catch (e) {
          errors.add('[${source.type.displayName}] 获取歌词失败: $e');
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
    final scrapers = await getEnabledScrapers();

    for (final (source, scraper) in scrapers) {
      if (source.type != ScraperType.acoustId) continue;

      if (scraper is FingerprintScraper) {
        try {
          return await scraper.lookupByFingerprint(fingerprint, duration);
        } on Exception catch (e) {
          debugPrint('AcoustID 查询失败: $e');
        }
      }
    }

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
