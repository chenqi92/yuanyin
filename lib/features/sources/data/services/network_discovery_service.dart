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
  });

  final String name;
  final String host;
  final int port;
  final SourceType type;
  final String? serviceType;

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

/// 网络发现服务（bonsoir v5 API）
class NetworkDiscoveryNotifier extends StateNotifier<NetworkDiscoveryState> {
  NetworkDiscoveryNotifier() : super(const NetworkDiscoveryState());

  /// mDNS 服务类型映射
  static const _serviceTypes = {
    '_smb._tcp': SourceType.smb,
    '_webdav._tcp': SourceType.webdav,
    '_webdavs._tcp': SourceType.webdav,
    '_http._tcp': null,
    '_https._tcp': null,
    '_diskstation._tcp': SourceType.synology,
    '_synology._tcp': SourceType.synology,
  };

  final Map<String, BonsoirDiscovery> _discoveries = {};
  final Map<String, StreamSubscription<BonsoirDiscoveryEvent>> _subscriptions = {};
  Timer? _discoveryTimer;
  final Set<DiscoveredDevice> _deviceSet = {};

  /// 开始发现
  Future<void> startDiscovery() async {
    if (state.isDiscovering) return;
    await stopDiscovery();

    _deviceSet.clear();
    state = state.copyWith(isDiscovering: true, devices: [], error: null);
    _log.i('NetworkDiscovery: 开始发现局域网设备');

    try {
      for (final entry in _serviceTypes.entries) {
        final serviceType = entry.key;
        final sourceType = entry.value;

        try {
          final discovery = BonsoirDiscovery(type: serviceType);
          await discovery.ready;

          // ignore: cancel_subscriptions
          final subscription = discovery.eventStream?.listen(
            (event) => _handleEvent(event, serviceType, sourceType),
            onError: (error) {
              _log.w('NetworkDiscovery: $serviceType 流错误: $error');
              // DefunctConnection 等平台错误不阻断整体发现流程
            },
          );

          if (subscription != null) {
            _subscriptions[serviceType] = subscription;
          }

          await discovery.start();
          _discoveries[serviceType] = discovery;
          _log.d('NetworkDiscovery: 开始监听 $serviceType');
        } catch (e) {
          _log.w('NetworkDiscovery: 初始化 $serviceType 失败: $e');
        }
      }

      _discoveryTimer = Timer(const Duration(seconds: 10), _finishDiscovery);
    } catch (e) {
      _log.e('NetworkDiscovery: 发现失败: $e');
      state = state.copyWith(isDiscovering: false, error: e.toString());
    }
  }

  /// 处理发现事件（bonsoir v5 使用 type 枚举）
  void _handleEvent(
    BonsoirDiscoveryEvent event,
    String serviceType,
    SourceType? sourceType,
  ) {
    final service = event.service;

    switch (event.type) {
      case BonsoirDiscoveryEventType.discoveryServiceFound:
        _log.d('NetworkDiscovery: 发现服务 ${service?.name} ($serviceType)');
        // 需要 resolve 获取 IP
        final discovery = _discoveries[serviceType];
        if (discovery != null && service != null && discovery is ServiceResolver) {
          (discovery as ServiceResolver).resolveService(service);
        }

      case BonsoirDiscoveryEventType.discoveryServiceResolved:
        if (service == null || service is! ResolvedBonsoirService) return;
        final host = service.host;
        final port = service.port;
        final name = service.name;

        if (host != null && host.isNotEmpty) {
          final type = sourceType ?? _guessSourceType(name, port);
          if (type != null) {
            final device = DiscoveredDevice(
              name: name,
              host: host,
              port: port,
              type: type,
              serviceType: serviceType,
            );
            if (_deviceSet.add(device)) {
              _log.i('NetworkDiscovery: 解析设备 $device');
              state = state.copyWith(devices: _deviceSet.toList());
            }
          }
        }

      case BonsoirDiscoveryEventType.discoveryServiceLost:
        if (service == null) return;
        _log.d('NetworkDiscovery: 服务离线 ${service.name}');
        // 尝试用名称匹配移除
        _deviceSet.removeWhere((d) => d.name == service.name);
        state = state.copyWith(devices: _deviceSet.toList());

      default:
        break;
    }
  }

  void _finishDiscovery() {
    _log.i('NetworkDiscovery: 发现完成，共 ${state.devices.length} 个设备');
    state = state.copyWith(
      isDiscovering: false,
      lastDiscoveryTime: DateTime.now(),
    );
  }

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
