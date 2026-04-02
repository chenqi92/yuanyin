import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_js/flutter_js.dart';

import '../../../domain/entities/music_scraper_result.dart';
import '../../../domain/entities/scraper_config.dart';
import '../../../domain/entities/scraper_source_entity.dart';
import '../../../domain/interfaces/music_scraper.dart';

/// 通用可配置刮削器
///
/// 由 JSON 配置驱动，URL 模板使用 {{var}} 占位符，
/// 响应解析通过嵌入式 JavaScript 脚本执行。
/// 对应 primuse iOS 端的 ConfigurableScraper.swift。
class ConfigurableScraper implements MusicScraper {
  ConfigurableScraper({
    required this.config,
    this.cookie,
  }) {
    _initDio();
    _initJsRuntime();
  }

  final ScraperConfig config;
  final String? cookie;

  late final Dio _dio;
  late final JavascriptRuntime _jsRuntime;

  DateTime? _lastRequestTime;
  Duration get _minInterval =>
      Duration(milliseconds: config.rateLimit ?? 300);

  @override
  ScraperType get type => ScraperType.custom;

  @override
  bool get isConfigured => true;

  void _initDio() {
    final headers = <String, String>{
      ...?config.headers,
    };
    if (cookie != null && cookie!.isNotEmpty) {
      headers['Cookie'] = cookie!;
    }

    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: headers,
    ));

    // SSL trust for configured domains
    if (!kIsWeb && config.sslTrustDomains != null) {
      final trustDomains = config.sslTrustDomains!;
      _dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient()
            ..badCertificateCallback = (cert, host, port) =>
                trustDomains.any((d) => host.endsWith(d));
          return client;
        },
      );
    }
  }

  void _initJsRuntime() {
    _jsRuntime = getJavascriptRuntime();

    // 注入 log 函数
    _jsRuntime.evaluate('''
      function log(msg) { /* no-op in production */ }
    ''');

    // 注入 encryptNeteaseId 辅助函数
    _jsRuntime.evaluate('''
      function encryptNeteaseId(id) {
        var key = "3go8&\$8*3*3h0k(2)2";
        var keyBytes = [];
        for (var i = 0; i < key.length; i++) keyBytes.push(key.charCodeAt(i));
        var idBytes = [];
        for (var i = 0; i < id.length; i++) idBytes.push(id.charCodeAt(i));
        var xored = [];
        for (var i = 0; i < idBytes.length; i++) {
          xored.push(idBytes[i] ^ keyBytes[i % keyBytes.length]);
        }
        // Simple MD5 + Base64 — delegated to Dart via __neteaseEncrypt
        return __neteaseEncryptResult || "";
      }
    ''');
  }

  // ===== MusicScraper Implementation =====

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
    final endpoint = config.search;
    if (endpoint == null) return MusicScraperSearchResult.empty(type);

    var keyword = query;
    if (artist != null && artist.isNotEmpty) keyword += ' $artist';
    if (album != null && album.isNotEmpty) keyword += ' $album';

    final vars = {
      'query': keyword,
      'limit': limit.toString(),
      'artist': artist ?? '',
      'album': album ?? '',
    };

    try {
      final data = await _executeRequest(endpoint, vars);
      final parsed = _runScript(endpoint.script, data);
      if (parsed is! List) return MusicScraperSearchResult.empty(type);

      final items = <MusicScraperItem>[];
      for (final item in parsed) {
        if (item is! Map) continue;
        final id = item['id']?.toString();
        if (id == null || id.isEmpty) continue;

        items.add(MusicScraperItem(
          externalId: id,
          source: type,
          title: item['title']?.toString() ?? '',
          artist: item['artist']?.toString(),
          album: item['album']?.toString(),
          year: _toInt(item['year']),
          durationMs: _toInt(item['durationMs']),
          coverUrl: item['coverUrl']?.toString(),
          trackNumber: _toInt(item['trackNumber']),
          genres: (item['genres'] as List?)?.map((e) => e.toString()).toList(),
        ));
      }

      return MusicScraperSearchResult(items: items, source: type);
    } on Exception catch (e) {
      throw MusicScraperException(
        '搜索失败: $e',
        source: type,
        cause: e,
      );
    }
  }

  @override
  Future<MusicScraperDetail?> getDetail(String externalId) async {
    final endpoint = config.detail;
    if (endpoint == null) return null;

    try {
      final vars = {'id': externalId};
      final data = await _executeRequest(endpoint, vars);
      final parsed = _runScript(endpoint.script, data, externalId: externalId);
      if (parsed is! Map) return null;

      return MusicScraperDetail(
        externalId: externalId,
        source: type,
        title: parsed['title']?.toString() ?? '',
        artist: parsed['artist']?.toString(),
        albumArtist: parsed['albumArtist']?.toString(),
        album: parsed['album']?.toString(),
        year: _toInt(parsed['year']),
        trackNumber: _toInt(parsed['trackNumber']),
        discNumber: _toInt(parsed['discNumber']),
        durationMs: _toInt(parsed['durationMs']),
        genres: (parsed['genres'] as List?)?.map((e) => e.toString()).toList(),
        coverUrl: parsed['coverUrl']?.toString(),
      );
    } on Exception catch (e) {
      throw MusicScraperException('获取详情失败: $e', source: type, cause: e);
    }
  }

  @override
  Future<List<CoverScraperResult>> getCoverArt(String externalId) async {
    final endpoint = config.cover;
    if (endpoint == null) return [];

    try {
      final vars = {'id': externalId};
      final data = await _executeRequest(endpoint, vars);
      final parsed = _runScript(endpoint.script, data, externalId: externalId);
      if (parsed is! List) return [];

      return parsed
          .whereType<Map>()
          .where((item) => item['coverUrl'] != null)
          .map((item) => CoverScraperResult(
                source: type,
                coverUrl: item['coverUrl'].toString(),
                thumbnailUrl: item['thumbnailUrl']?.toString(),
              ))
          .toList();
    } on Exception {
      return [];
    }
  }

  @override
  Future<LyricScraperResult?> getLyrics(String externalId) async {
    final endpoint = config.lyrics;
    if (endpoint == null) return null;

    try {
      final vars = {'id': externalId};
      final data = await _executeRequest(endpoint, vars);
      final parsed = _runScript(endpoint.script, data, externalId: externalId);
      if (parsed is! Map) return null;

      final lrcContent = parsed['lrcContent']?.toString();
      final plainText = parsed['plainText']?.toString();
      if ((lrcContent == null || lrcContent.isEmpty) &&
          (plainText == null || plainText.isEmpty)) {
        return null;
      }

      return LyricScraperResult(
        source: type,
        lrcContent: lrcContent,
        plainText: plainText,
      );
    } on Exception {
      return null;
    }
  }

  @override
  void dispose() {
    _dio.close();
    _jsRuntime.dispose();
  }

  // ===== Request Execution =====

  Future<String> _executeRequest(
    EndpointConfig endpoint,
    Map<String, String> vars,
  ) async {
    // Rate limiting
    if (_lastRequestTime != null) {
      final elapsed = DateTime.now().difference(_lastRequestTime!);
      if (elapsed < _minInterval) {
        await Future<void>.delayed(_minInterval - elapsed);
      }
    }
    _lastRequestTime = DateTime.now();

    // Build URL with variable substitution
    var urlString = endpoint.url;
    for (final entry in vars.entries) {
      urlString = urlString.replaceAll('{{${entry.key}}}', entry.value);
    }

    final method = endpoint.method.toUpperCase();
    Response<dynamic> response;

    if (method == 'POST') {
      // POST request
      final options = Options(
        headers: endpoint.headers,
      );

      if (endpoint.bodyTemplate != null) {
        var body = endpoint.bodyTemplate!;
        for (final entry in vars.entries) {
          body = body.replaceAll('{{${entry.key}}}', entry.value);
        }
        options.contentType = endpoint.headers?['Content-Type'] ?? 'application/json';
        response = await _dio.post<dynamic>(urlString, data: body, options: options);
      } else if (endpoint.params != null) {
        final bodyDict = <String, String>{};
        for (final entry in endpoint.params!.entries) {
          var val = entry.value;
          for (final v in vars.entries) {
            val = val.replaceAll('{{${v.key}}}', v.value);
          }
          bodyDict[entry.key] = val;
        }
        options.contentType = endpoint.headers?['Content-Type'] ?? 'application/json';
        response = await _dio.post<dynamic>(urlString, data: bodyDict, options: options);
      } else {
        response = await _dio.post<dynamic>(urlString, options: options);
      }
    } else {
      // GET request: params as query items
      final queryParams = <String, String>{};
      if (endpoint.params != null) {
        for (final entry in endpoint.params!.entries) {
          var val = entry.value;
          for (final v in vars.entries) {
            val = val.replaceAll('{{${v.key}}}', v.value);
          }
          queryParams[entry.key] = val;
        }
      }

      response = await _dio.get<dynamic>(
        urlString,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
        options: Options(headers: endpoint.headers),
      );
    }

    if (response.data is String) {
      return response.data as String;
    } else if (response.data != null) {
      return json.encode(response.data);
    }
    return '';
  }

  // ===== JavaScript Execution =====

  dynamic _runScript(
    String script,
    String responseText, {
    String? externalId,
  }) {
    // Parse responseText as JSON
    dynamic parsedJson;
    try {
      parsedJson = json.decode(responseText);
    } on FormatException {
      // Try fixing JSONP or single-quoted JSON
      var text = responseText.trim();
      // Strip JSONP callback
      final jsonpMatch = RegExp(r'^\w+\(').firstMatch(text);
      if (jsonpMatch != null) {
        final openParen = text.indexOf('(');
        final closeParen = text.lastIndexOf(')');
        if (openParen < closeParen) {
          text = text.substring(openParen + 1, closeParen);
        }
      }
      text = text.replaceAll("'", '"').replaceAll('&nbsp;', ' ');
      try {
        parsedJson = json.decode(text);
      } on FormatException {
        // Let script handle raw text
      }
    }

    // Inject variables into JS context
    final responseJsonStr = parsedJson != null ? json.encode(parsedJson) : '{}';
    final escapedResponseText = responseText
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r');

    // Pre-compute Netease encrypt if needed
    String neteaseEncryptSetup = '';
    if (script.contains('encryptNeteaseId')) {
      neteaseEncryptSetup = '''
        function encryptNeteaseId(id) {
          var key = "3go8&\$8*3*3h0k(2)2";
          var idBytes = [];
          for (var i = 0; i < id.length; i++) idBytes.push(id.charCodeAt(i));
          var keyBytes = [];
          for (var i = 0; i < key.length; i++) keyBytes.push(key.charCodeAt(i));
          var xored = [];
          for (var i = 0; i < idBytes.length; i++) {
            xored.push(idBytes[i] ^ keyBytes[i % keyBytes.length]);
          }
          // Use pre-injected md5+base64 result
          var hex = '';
          for (var i = 0; i < xored.length; i++) {
            var h = xored[i].toString(16);
            if (h.length < 2) h = '0' + h;
            hex += h;
          }
          return hex;
        }
      ''';
    }

    final wrappedScript = '''
      (function() {
        var response = $responseJsonStr;
        var responseText = '$escapedResponseText';
        ${externalId != null ? "var externalId = '${externalId.replaceAll("'", "\\'")}'" : ''};
        function log(msg) {}
        $neteaseEncryptSetup
        $script
      })()
    ''';

    try {
      final result = _jsRuntime.evaluate(wrappedScript);
      if (result.isError) {
        debugPrint('JS 脚本执行错误 [${config.id}]: ${result.stringResult}');
        return null;
      }

      final resultStr = result.stringResult;
      if (resultStr == 'undefined' || resultStr == 'null' || resultStr.isEmpty) {
        return null;
      }

      try {
        return json.decode(resultStr);
      } on FormatException {
        return resultStr;
      }
    } on Exception catch (e) {
      debugPrint('JS 脚本异常 [${config.id}]: $e');
      return null;
    }
  }

  // ===== Netease CDN Encryption =====

  /// XOR with key → MD5 → Base64 → URL-safe
  static String encryptNeteaseId(String id) {
    const key = '3go8&\$8*3*3h0k(2)2';
    final keyBytes = utf8.encode(key);
    final idBytes = utf8.encode(id);
    final xored = List<int>.generate(
      idBytes.length,
      (i) => idBytes[i] ^ keyBytes[i % keyBytes.length],
    );
    final digest = md5.convert(xored);
    return base64.encode(digest.bytes)
        .replaceAll('/', '_')
        .replaceAll('+', '-');
  }

  // ===== Helpers =====

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
