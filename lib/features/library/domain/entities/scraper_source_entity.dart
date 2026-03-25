import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:uuid/uuid.dart';

/// 刮削源类型
enum ScraperType {
  musicBrainz('MusicBrainz', 'musicbrainz'),
  acoustId('AcoustID', 'acoustid'),
  neteaseMusic('网易云音乐', 'netease'),
  qqMusic('QQ音乐', 'qqmusic'),
  kugouMusic('酷狗音乐', 'kugou'),
  kuwoMusic('酷我音乐', 'kuwo'),
  miguMusic('咪咕音乐', 'migu'),
  musicTagWeb('Music Tag Web', 'musictagweb');

  const ScraperType(this.displayName, this.id);

  /// 显示名称
  final String displayName;

  /// 唯一标识符
  final String id;

  /// 图标
  IconData get icon => switch (this) {
        ScraperType.musicBrainz => Icons.album_rounded,
        ScraperType.acoustId => Icons.fingerprint_rounded,
        ScraperType.neteaseMusic => Icons.cloud_rounded,
        ScraperType.qqMusic => Icons.music_note_rounded,
        ScraperType.kugouMusic => Icons.graphic_eq_rounded,
        ScraperType.kuwoMusic => Icons.headphones_rounded,
        ScraperType.miguMusic => Icons.library_music_rounded,
        ScraperType.musicTagWeb => Icons.dns_rounded,
      };

  /// 主题色
  Color get themeColor => switch (this) {
        ScraperType.musicBrainz => const Color(0xFFBA478F),
        ScraperType.acoustId => const Color(0xFF5BC0DE),
        ScraperType.neteaseMusic => const Color(0xFFE60026),
        ScraperType.qqMusic => const Color(0xFF31C27C),
        ScraperType.kugouMusic => const Color(0xFF2196F3),
        ScraperType.kuwoMusic => const Color(0xFFFF6600),
        ScraperType.miguMusic => const Color(0xFFFF0653),
        ScraperType.musicTagWeb => const Color(0xFF6366F1),
      };

  /// 描述
  String get description => switch (this) {
        ScraperType.musicBrainz => '开放音乐数据库，支持元数据和封面查询',
        ScraperType.acoustId => '声纹识别服务，需要 API Key',
        ScraperType.neteaseMusic => '国内音乐平台，支持歌词和封面',
        ScraperType.qqMusic => '国内音乐平台，支持歌词和封面',
        ScraperType.kugouMusic => '国内音乐平台，歌词库丰富',
        ScraperType.kuwoMusic => '国内音乐平台，支持歌词和封面',
        ScraperType.miguMusic => '中国移动旗下音乐平台，无损音源丰富',
        ScraperType.musicTagWeb => '自托管音乐刮削服务，需配置服务器地址',
      };

  /// 是否支持元数据
  bool get supportsMetadata => [
        ScraperType.musicBrainz,
        ScraperType.neteaseMusic,
        ScraperType.qqMusic,
        ScraperType.kugouMusic,
        ScraperType.kuwoMusic,
        ScraperType.miguMusic,
        ScraperType.musicTagWeb,
      ].contains(this);

  /// 是否支持封面
  bool get supportsCover => [
        ScraperType.musicBrainz,
        ScraperType.neteaseMusic,
        ScraperType.qqMusic,
        ScraperType.kugouMusic,
        ScraperType.kuwoMusic,
        ScraperType.miguMusic,
        ScraperType.musicTagWeb,
      ].contains(this);

  /// 是否支持歌词
  bool get supportsLyrics => [
        ScraperType.neteaseMusic,
        ScraperType.qqMusic,
        ScraperType.kugouMusic,
        ScraperType.kuwoMusic,
        ScraperType.miguMusic,
        ScraperType.musicTagWeb,
      ].contains(this);

  /// 是否支持声纹识别
  bool get supportsFingerprint => this == ScraperType.acoustId;

  /// 是否需要 API Key
  bool get requiresApiKey => [
        ScraperType.acoustId,
      ].contains(this);

  /// 是否需要 Cookie（可选）
  bool get supportsCookie => [
        ScraperType.neteaseMusic,
        ScraperType.qqMusic,
      ].contains(this);

  /// 是否需要服务器地址
  bool get requiresServerUrl => this == ScraperType.musicTagWeb;

  /// 从 id 获取类型
  static ScraperType fromId(String id) => ScraperType.values.firstWhere(
        (t) => t.id == id,
        orElse: () => ScraperType.musicBrainz,
      );
}

/// 刮削源实体
class ScraperSourceEntity {
  ScraperSourceEntity({
    String? id,
    required this.name,
    required this.type,
    this.isEnabled = true,
    this.priority = 0,
    this.apiKey,
    this.cookie,
    this.extraConfig,
  }) : id = id ?? const Uuid().v4();

  factory ScraperSourceEntity.fromJson(Map<String, dynamic> json) =>
      ScraperSourceEntity(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        type: ScraperType.fromId(json['type'] as String? ?? 'musicbrainz'),
        isEnabled: json['isEnabled'] as bool? ?? true,
        priority: json['priority'] as int? ?? 0,
        apiKey: json['apiKey'] as String?,
        cookie: json['cookie'] as String?,
        extraConfig: json['extraConfig'] != null
            ? Map<String, dynamic>.from(json['extraConfig'] as Map)
            : null,
      );

  /// 唯一标识符
  final String id;

  /// 显示名称
  final String name;

  /// 刮削源类型
  final ScraperType type;

  /// 是否启用
  final bool isEnabled;

  /// 优先级（数值越小优先级越高）
  final int priority;

  /// API Key
  final String? apiKey;

  /// Cookie（网易云、QQ音乐可选）
  final String? cookie;

  /// 额外配置
  final Map<String, dynamic>? extraConfig;

  /// 获取显示名称
  String get displayName => name.isNotEmpty ? name : type.displayName;

  /// 是否已配置（有必要的凭证）
  bool get isConfigured => switch (type) {
        ScraperType.musicBrainz => true,
        ScraperType.acoustId => apiKey != null && apiKey!.isNotEmpty,
        ScraperType.neteaseMusic => true,
        ScraperType.qqMusic => true,
        ScraperType.kugouMusic => true,
        ScraperType.kuwoMusic => true,
        ScraperType.miguMusic => true,
        ScraperType.musicTagWeb => _isMusicTagWebConfigured,
      };

  /// Music Tag Web 是否已配置
  bool get _isMusicTagWebConfigured {
    final serverUrl = extraConfig?['serverUrl'] as String?;
    return serverUrl != null && serverUrl.isNotEmpty;
  }

  /// 获取 Music Tag Web 服务器地址
  String? get serverUrl => extraConfig?['serverUrl'] as String?;

  /// 获取请求间隔（秒）
  int get requestInterval =>
      extraConfig?['requestInterval'] as int? ??
      switch (type) {
        ScraperType.musicBrainz => 1,
        ScraperType.neteaseMusic => 1,
        ScraperType.qqMusic => 1,
        _ => 0,
      };

  ScraperSourceEntity copyWith({
    String? id,
    String? name,
    ScraperType? type,
    bool? isEnabled,
    int? priority,
    String? apiKey,
    String? cookie,
    Map<String, dynamic>? extraConfig,
  }) =>
      ScraperSourceEntity(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        isEnabled: isEnabled ?? this.isEnabled,
        priority: priority ?? this.priority,
        apiKey: apiKey ?? this.apiKey,
        cookie: cookie ?? this.cookie,
        extraConfig: extraConfig ?? this.extraConfig,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.id,
        'isEnabled': isEnabled,
        'priority': priority,
        'apiKey': apiKey,
        'cookie': cookie,
        'extraConfig': extraConfig,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScraperSourceEntity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Hive 持久化的刮削源管理
class ScraperSourcesService {
  static const _boxName = 'scraper_sources';
  Box? _box;

  Future<Box> _getBox() async {
    _box ??= await Hive.openBox(_boxName);
    return _box!;
  }

  Future<List<ScraperSourceEntity>> loadAll() async {
    final box = await _getBox();
    final raw = box.get('sources');
    if (raw == null) return _defaults();
    final list = (raw as List).cast<Map>();
    final sources = list
        .map((m) => ScraperSourceEntity.fromJson(Map<String, dynamic>.from(m)))
        .toList();
    // 补充新增的默认源
    _addMissingDefaults(sources);
    return sources;
  }

  Future<void> saveAll(List<ScraperSourceEntity> sources) async {
    final box = await _getBox();
    await box.put('sources', sources.map((s) => s.toJson()).toList());
  }

  /// 默认启用的刮削源
  List<ScraperSourceEntity> _defaults() => [
        ScraperSourceEntity(name: '', type: ScraperType.kugouMusic, priority: 0),
        ScraperSourceEntity(name: '', type: ScraperType.kuwoMusic, priority: 1),
        ScraperSourceEntity(name: '', type: ScraperType.miguMusic, priority: 2),
        ScraperSourceEntity(name: '', type: ScraperType.qqMusic, priority: 3),
        ScraperSourceEntity(name: '', type: ScraperType.neteaseMusic, priority: 4),
        ScraperSourceEntity(
            name: '', type: ScraperType.musicBrainz, priority: 5, isEnabled: false),
      ];

  /// 为已有用户补充新增的刮削源类型
  void _addMissingDefaults(List<ScraperSourceEntity> sources) {
    final existingTypes = sources.map((s) => s.type).toSet();
    final defaultTypes = [
      ScraperType.kugouMusic,
      ScraperType.kuwoMusic,
      ScraperType.miguMusic,
      ScraperType.qqMusic,
      ScraperType.neteaseMusic,
      ScraperType.musicBrainz,
    ];

    var maxPriority = sources.isEmpty
        ? 0
        : sources.map((s) => s.priority).reduce((a, b) => a > b ? a : b);

    for (final type in defaultTypes) {
      if (!existingTypes.contains(type)) {
        maxPriority++;
        sources.add(ScraperSourceEntity(
          name: '',
          type: type,
          isEnabled: type != ScraperType.musicBrainz,
          priority: maxPriority,
        ));
      }
    }
  }
}

/// 音乐刮削凭证
class ScraperCredential {
  const ScraperCredential({
    this.apiKey,
    this.cookie,
  });

  factory ScraperCredential.fromJson(Map<String, dynamic> json) =>
      ScraperCredential(
        apiKey: json['apiKey'] as String?,
        cookie: json['cookie'] as String?,
      );

  final String? apiKey;
  final String? cookie;

  bool get isEmpty =>
      (apiKey == null || apiKey!.isEmpty) &&
      (cookie == null || cookie!.isEmpty);

  Map<String, dynamic> toJson() => {
        'apiKey': apiKey,
        'cookie': cookie,
      };
}
