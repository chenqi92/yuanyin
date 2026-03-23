/// 数据源类型
enum SourceType {
  /// 本地文件系统（沙盒内或通过文件选择器授权的目录）
  local,

  /// SMB/CIFS 网络共享
  smb,

  /// WebDAV
  webdav,

  /// Synology DSM
  synology,

  /// QNAP
  qnap,

  /// Jellyfin
  jellyfin,

  /// Emby
  emby,

  /// Plex
  plex,
}

/// 数据源连接状态
enum SourceStatus {
  disconnected,
  connecting,
  connected,
  error,
}

/// 数据源实体
class SourceEntity {
  final String id;
  final String name;
  final SourceType type;
  final String path;
  final String? host;
  final int? port;
  final String? username;
  final String? password;
  final bool useSsl;
  final bool autoConnect;
  final SourceStatus status;
  final int songCount;
  final DateTime? lastScanTime;
  final String? errorMessage;
  final String? deviceToken;

  const SourceEntity({
    required this.id,
    required this.name,
    required this.type,
    required this.path,
    this.host,
    this.port,
    this.username,
    this.password,
    this.useSsl = false,
    this.autoConnect = true,
    this.status = SourceStatus.disconnected,
    this.songCount = 0,
    this.lastScanTime,
    this.errorMessage,
    this.deviceToken,
  });

  SourceEntity copyWith({
    String? name,
    String? path,
    String? host,
    int? port,
    String? username,
    String? password,
    bool? useSsl,
    bool? autoConnect,
    SourceStatus? status,
    int? songCount,
    DateTime? lastScanTime,
    String? errorMessage,
    String? deviceToken,
  }) {
    return SourceEntity(
      id: id,
      name: name ?? this.name,
      type: type,
      path: path ?? this.path,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      useSsl: useSsl ?? this.useSsl,
      autoConnect: autoConnect ?? this.autoConnect,
      status: status ?? this.status,
      songCount: songCount ?? this.songCount,
      lastScanTime: lastScanTime ?? this.lastScanTime,
      errorMessage: errorMessage,
      deviceToken: deviceToken ?? this.deviceToken,
    );
  }

  /// 显示用的类型名
  String get typeDisplayName {
    switch (type) {
      case SourceType.local:
        return '本地文件';
      case SourceType.smb:
        return 'SMB/CIFS';
      case SourceType.webdav:
        return 'WebDAV';
      case SourceType.synology:
        return 'Synology';
      case SourceType.qnap:
        return 'QNAP';
      case SourceType.jellyfin:
        return 'Jellyfin';
      case SourceType.emby:
        return 'Emby';
      case SourceType.plex:
        return 'Plex';
    }
  }

  /// 序列化到 Map（Hive 存储）
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.index,
      'path': path,
      'host': host,
      'port': port,
      'username': username,
      'password': password,
      'useSsl': useSsl,
      'autoConnect': autoConnect,
      'songCount': songCount,
      'lastScanTime': lastScanTime?.millisecondsSinceEpoch,
      'errorMessage': errorMessage,
      'deviceToken': deviceToken,
    };
  }

  factory SourceEntity.fromMap(Map<dynamic, dynamic> map) {
    return SourceEntity(
      id: map['id'] as String,
      name: map['name'] as String,
      type: SourceType.values[map['type'] as int],
      path: map['path'] as String,
      host: map['host'] as String?,
      port: map['port'] as int?,
      username: map['username'] as String?,
      password: map['password'] as String?,
      useSsl: map['useSsl'] as bool? ?? false,
      autoConnect: map['autoConnect'] as bool? ?? true,
      songCount: map['songCount'] as int? ?? 0,
      lastScanTime: map['lastScanTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastScanTime'] as int)
          : null,
      errorMessage: map['errorMessage'] as String?,
      deviceToken: map['deviceToken'] as String?,
    );
  }
}
