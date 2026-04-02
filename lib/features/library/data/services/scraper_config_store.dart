import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/scraper_config.dart';

/// 管理用户导入的 JSON 刮削源配置文件
///
/// 配置文件存储在应用沙盒 Documents/ScraperConfigs/ 目录中。
/// 对应 primuse iOS 端的 ScraperConfigStore.swift。
class ScraperConfigStore {
  ScraperConfigStore._();
  static final ScraperConfigStore instance = ScraperConfigStore._();

  final Map<String, ScraperConfig> _cache = {};
  Directory? _configDir;
  bool _loaded = false;

  /// 初始化（懒加载）
  Future<void> _ensureInit() async {
    if (_loaded) return;
    final docDir = await getApplicationDocumentsDirectory();
    _configDir = Directory('${docDir.path}/ScraperConfigs');
    if (!await _configDir!.exists()) {
      await _configDir!.create(recursive: true);
    }
    await _loadAll();
    _loaded = true;
  }

  /// 获取所有已导入的配置
  Future<List<ScraperConfig>> getAllConfigs() async {
    await _ensureInit();
    return _cache.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  /// 根据 ID 获取配置
  Future<ScraperConfig?> getConfig(String id) async {
    await _ensureInit();
    return _cache[id];
  }

  /// 同步获取（仅在已初始化后使用）
  ScraperConfig? getConfigSync(String id) => _cache[id];

  /// 检查配置是否存在
  Future<bool> exists(String id) async {
    await _ensureInit();
    return _cache.containsKey(id);
  }

  /// 从 JSON 字符串导入配置
  Future<ScraperConfig> importFromJSON(String jsonString) async {
    await _ensureInit();

    Map<String, dynamic> jsonData;
    try {
      jsonData = json.decode(jsonString) as Map<String, dynamic>;
    } on FormatException catch (e) {
      throw ScraperConfigValidationException('JSON 格式无效: ${e.message}');
    }

    final config = ScraperConfig.fromJson(jsonData);
    _validate(config);

    // 保存到文件
    final file = File('${_configDir!.path}/${config.id}.json');
    await file.writeAsString(jsonString, encoding: utf8);

    // 更新缓存
    _cache[config.id] = config;
    return config;
  }

  /// 从 URL 下载并导入配置
  Future<ScraperConfig> importFromURL(String url) async {
    await _ensureInit();

    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ));
      final response = await dio.get<String>(url);
      if (response.data == null || response.data!.isEmpty) {
        throw ScraperConfigValidationException('下载的内容为空');
      }
      return importFromJSON(response.data!);
    } on DioException catch (e) {
      throw ScraperConfigValidationException(
        '下载失败: ${e.message ?? "网络错误"}',
      );
    }
  }

  /// 删除配置
  Future<void> delete(String id) async {
    await _ensureInit();
    _cache.remove(id);
    final file = File('${_configDir!.path}/$id.json');
    if (await file.exists()) {
      await file.delete();
    }
  }

  // ===== Private =====

  Future<void> _loadAll() async {
    if (_configDir == null) return;
    try {
      final files = _configDir!.listSync();
      for (final entity in files) {
        if (entity is File && entity.path.endsWith('.json')) {
          try {
            final content = await entity.readAsString();
            final jsonData = json.decode(content) as Map<String, dynamic>;
            final config = ScraperConfig.fromJson(jsonData);
            _cache[config.id] = config;
          } on Exception catch (e) {
            debugPrint('加载刮削配置失败: ${entity.path} - $e');
          }
        }
      }
    } on Exception catch (e) {
      debugPrint('扫描刮削配置目录失败: $e');
    }
  }

  void _validate(ScraperConfig config) {
    if (config.id.isEmpty) {
      throw ScraperConfigValidationException('配置 ID 不能为空');
    }
    if (config.name.isEmpty) {
      throw ScraperConfigValidationException('配置名称不能为空');
    }
    if (config.capabilities.isEmpty) {
      throw ScraperConfigValidationException('配置必须声明至少一种能力');
    }
    if (config.search == null &&
        config.detail == null &&
        config.cover == null &&
        config.lyrics == null) {
      throw ScraperConfigValidationException('配置必须定义至少一个端点');
    }
  }
}
