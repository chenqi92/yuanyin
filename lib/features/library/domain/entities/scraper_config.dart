/// JSON 刮削源配置模型
///
/// 与 primuse iOS 端共享相同的 JSON 格式。
/// 用户通过粘贴 JSON 或 URL 导入自定义刮削源。
class ScraperConfig {
  const ScraperConfig({
    required this.id,
    required this.name,
    required this.version,
    this.icon,
    this.color,
    this.rateLimit,
    this.headers,
    required this.capabilities,
    this.sslTrustDomains,
    this.search,
    this.detail,
    this.cover,
    this.lyrics,
  });

  factory ScraperConfig.fromJson(Map<String, dynamic> json) => ScraperConfig(
        id: json['id'] as String,
        name: json['name'] as String,
        version: json['version'] as int? ?? 1,
        icon: json['icon'] as String?,
        color: json['color'] as String?,
        rateLimit: json['rateLimit'] as int?,
        headers: (json['headers'] as Map?)?.map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        ),
        capabilities: (json['capabilities'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        sslTrustDomains: (json['sslTrustDomains'] as List?)
            ?.map((e) => e.toString())
            .toList(),
        search: json['search'] != null
            ? EndpointConfig.fromJson(
                json['search'] as Map<String, dynamic>)
            : null,
        detail: json['detail'] != null
            ? EndpointConfig.fromJson(
                json['detail'] as Map<String, dynamic>)
            : null,
        cover: json['cover'] != null
            ? EndpointConfig.fromJson(
                json['cover'] as Map<String, dynamic>)
            : null,
        lyrics: json['lyrics'] != null
            ? EndpointConfig.fromJson(
                json['lyrics'] as Map<String, dynamic>)
            : null,
      );

  final String id;
  final String name;
  final int version;
  final String? icon;
  final String? color;
  final int? rateLimit; // 请求间隔（毫秒）
  final Map<String, String>? headers;
  final List<String> capabilities; // ["metadata", "cover", "lyrics"]
  final List<String>? sslTrustDomains;

  final EndpointConfig? search;
  final EndpointConfig? detail;
  final EndpointConfig? cover;
  final EndpointConfig? lyrics;

  bool get supportsMetadata => capabilities.contains('metadata');
  bool get supportsCover => capabilities.contains('cover');
  bool get supportsLyrics => capabilities.contains('lyrics');

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'version': version,
        if (icon != null) 'icon': icon,
        if (color != null) 'color': color,
        if (rateLimit != null) 'rateLimit': rateLimit,
        if (headers != null) 'headers': headers,
        'capabilities': capabilities,
        if (sslTrustDomains != null) 'sslTrustDomains': sslTrustDomains,
        if (search != null) 'search': search!.toJson(),
        if (detail != null) 'detail': detail!.toJson(),
        if (cover != null) 'cover': cover!.toJson(),
        if (lyrics != null) 'lyrics': lyrics!.toJson(),
      };
}

/// API 端点配置
class EndpointConfig {
  const EndpointConfig({
    required this.url,
    required this.method,
    this.params,
    this.headers,
    this.bodyTemplate,
    required this.script,
  });

  factory EndpointConfig.fromJson(Map<String, dynamic> json) => EndpointConfig(
        url: json['url'] as String,
        method: json['method'] as String? ?? 'GET',
        params: (json['params'] as Map?)?.map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        ),
        headers: (json['headers'] as Map?)?.map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        ),
        bodyTemplate: json['bodyTemplate'] as String?,
        script: json['script'] as String,
      );

  final String url; // URL 模板，支持 {{var}} 占位符
  final String method; // "GET" 或 "POST"
  final Map<String, String>? params;
  final Map<String, String>? headers; // 端点特定的 headers
  final String? bodyTemplate; // POST body 模板
  final String script; // JavaScript 解析脚本

  Map<String, dynamic> toJson() => {
        'url': url,
        'method': method,
        if (params != null) 'params': params,
        if (headers != null) 'headers': headers,
        if (bodyTemplate != null) 'bodyTemplate': bodyTemplate,
        'script': script,
      };
}

/// 配置校验异常
class ScraperConfigValidationException implements Exception {
  const ScraperConfigValidationException(this.message);
  final String message;

  @override
  String toString() => 'ScraperConfigValidationException: $message';
}
