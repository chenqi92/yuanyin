import 'dart:async';

import 'package:bonsoir/bonsoir.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../../domain/entities/source_entity.dart';

final _log = Logger(printer: SimplePrinter());

/// 发现的设备信息
class DiscoveredDevice {
  const DiscoveredDevice({
    required this.name,
    required this.host,
    required this.port,
    required this.type,
    this.serviceType,
    this.txtRecords,
  });

  final String name;
  final String host;
  final int port;
  final SourceType type;
  final String? serviceType;
  final Map<String, String>? txtRecords;

  @override
  String toString() => 'DiscoveredDevice($name, $host:$port, $type)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredDevice &&
          runtimeType == other.runtimeType &&
          host == other.host &&
          port == other.port;

  @override
  int get hashCode => host.hashCode ^ port.hashCode;
}

/// 网络发现状态
class NetworkDiscoveryState {
  const NetworkDiscoveryState({
    this.devices = const [],
    this.isDiscovering = false,
    this.lastDiscoveryTime,
    this.error,
  });

  final List<DiscoveredDevice> devices;
  final bool isDiscovering;
  final DateTime? lastDiscoveryTime;
  final String? error;

  NetworkDiscoveryState copyWith({
    List<DiscoveredDevice>? devices,
    bool? isDiscovering,
    DateTime? lastDiscoveryTime,
    String? error,
  }) =>
      NetworkDiscoveryState(
        devices: devices ?? this.devices,
        isDiscovering: isDiscovering ?? this.isDiscovering,
        lastDiscoveryTime: lastDiscoveryTime ?? this.lastDiscoveryTime,
        error: error,
      );
}

/// 网络发现服务 Provider
final networkDiscoveryProvider =
    StateNotifierProvider<NetworkDiscoveryNotifier, NetworkDiscoveryState>(
  (ref) => NetworkDiscoveryNotifier(),
);

/// 网络发现服务
/// 使用 bonsoir 包通过原生 API 发现局域网设备：
/// - iOS/macOS: Apple Bonjour
/// - Android: Network Service Discovery (NSD)
/// - Windows: Windows DNS-SD
/// - Linux: Avahi
class NetworkDiscoveryNotifier extends StateNotifier<NetworkDiscoveryState> {
  NetworkDiscoveryNotifier() : super(const NetworkDiscoveryState());

  /// mDNS 服务类型映射
  static const _serviceTypes = {
    '_smb._tcp': SourceType.smb,
    '_webdav._tcp': SourceType.webdav,
    '_webdavs._tcp': SourceType.webdav,
    '_http._tcp': null, // 通用 HTTP，需要进一步判断
    '_https._tcp': null,
    // NAS 设备专用服务
    '_diskstation._tcp': SourceType.synology,
    '_synology._tcp': SourceType.synology,
  };

  final Map<String, BonsoirDiscovery> _discoveries = {};
  final Map<String, StreamSubscription<BonsoirDiscoveryEvent>> _subscriptions = {};
  Timer? _discoveryTimer;

  /// 开始发现
  Future<void> startDiscovery() async {
    if (state.isDiscovering) return;

    // 先停止任何现有的发现
    await stopDiscovery();

    state = state.copyWith(isDiscovering: true, devices: [], error: null);
    _log.i('NetworkDiscovery: 开始发现局域网设备 (使用原生 API)');

    try {
      final devices = <DiscoveredDevice>{};

      // 为每个服务类型创建发现实例
      for (final entry in _serviceTypes.entries) {
        final serviceType = entry.key;
        final sourceType = entry.value;

        try {
          final discovery = BonsoirDiscovery(type: serviceType);
          await discovery.initialize();

          // 监听发现事件
          // ignore: cancel_subscriptions - 已在 _subscriptions 中管理
          final subscription = discovery.eventStream?.listen(
            (event) => _handleDiscoveryEvent(event, serviceType, sourceType, devices),
          );

          if (subscription != null) {
            _subscriptions[serviceType] = subscription;
          }

          await discovery.start();
          _discoveries[serviceType] = discovery;

          _log.d('NetworkDiscovery: 开始监听服务类型 $serviceType');
        } on Exception catch (e) {
          _log.w('NetworkDiscovery: 初始化 $serviceType 发现失败: $e');
        }
      }

      // 设置超时，在一段时间后停止发现并更新状态
      _discoveryTimer = Timer(const Duration(seconds: 10), _finishDiscovery);
    } on Exception catch (e) {
      _log.e('NetworkDiscovery: 发现失败: $e');
      state = state.copyWith(
        isDiscovering: false,
        error: e.toString(),
      );
    }
  }

  /// 处理发现事件（bonsoir v6 使用 sealed class pattern matching）
  void _handleDiscoveryEvent(
    BonsoirDiscoveryEvent event,
    String serviceType,
    SourceType? sourceType,
    Set<DiscoveredDevice> devices,
  ) {
    switch (event) {
      case BonsoirDiscoveryServiceFoundEvent():
        _log.d('NetworkDiscovery: 发现服务 ${event.service.name} ($serviceType)');
        // 服务发现后需要解析获取 IP 和端口
        final discovery = _discoveries[serviceType];
        if (discovery == null) return;
        event.service.resolve(discovery.serviceResolver);

      case BonsoirDiscoveryServiceResolvedEvent():
        final service = event.service;
        final host = service.host;
        final port = service.port;
        final name = service.name;

        if (host != null && host.isNotEmpty) {
          // 确定源类型
          final type = sourceType ?? _guessSourceType(name, port);
          if (type != null) {
            // 转换 TXT 记录
            Map<String, String>? txtRecords;
            final attributes = service.attributes;
            if (attributes.isNotEmpty) {
              txtRecords = Map<String, String>.from(attributes);
            }

            final device = DiscoveredDevice(
              name: name,
              host: host,
              port: port,
              type: type,
              serviceType: serviceType,
              txtRecords: txtRecords,
            );

            // 避免重复
            if (devices.add(device)) {
              _log.i('NetworkDiscovery: 解析设备 $device');
              state = state.copyWith(devices: devices.toList());
            }
          }
        }

      case BonsoirDiscoveryServiceLostEvent():
        _log.d('NetworkDiscovery: 服务离线 ${event.service.name}');
        final host = event.service.host;
        final port = event.service.port;
        if (host != null) {
          devices.removeWhere((d) => d.host == host && d.port == port);
          state = state.copyWith(devices: devices.toList());
        }

      default:
        break;
    }
  }

  /// 完成发现
  void _finishDiscovery() {
    _log.i('NetworkDiscovery: 发现完成，共 ${state.devices.length} 个设备');
    state = state.copyWith(
      isDiscovering: false,
      lastDiscoveryTime: DateTime.now(),
    );
  }

  /// 停止发现
  Future<void> stopDiscovery() async {
    _discoveryTimer?.cancel();
    _discoveryTimer = null;

    for (final subscription in _subscriptions.values) {
      await subscription.cancel();
    }
    _subscriptions.clear();

    for (final discovery in _discoveries.values) {
      try {
        await discovery.stop();
      } on Exception catch (e) {
        _log.w('NetworkDiscovery: 停止发现失败: $e');
      }
    }
    _discoveries.clear();

    if (state.isDiscovering) {
      state = state.copyWith(isDiscovering: false);
    }
  }

  /// 根据名称和端口猜测源类型
  SourceType? _guessSourceType(String name, int port) {
    final nameLower = name.toLowerCase();

    if (nameLower.contains('synology') || nameLower.contains('diskstation')) {
      return SourceType.synology;
    }

    return switch (port) {
      5001 || 5000 => SourceType.synology,
      445 => SourceType.smb,
      443 || 80 => SourceType.webdav,
      _ => null,
    };
  }

  @override
  void dispose() {
    unawaited(stopDiscovery());
    super.dispose();
  }
}
