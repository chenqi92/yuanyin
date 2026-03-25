import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NativeTabBarMetrics {
  const NativeTabBarMetrics({
    required this.tabBarHeight,
    required this.safeAreaBottom,
  });

  final double tabBarHeight;
  final double safeAreaBottom;

  double get totalHeight => tabBarHeight;

  NativeTabBarMetrics copyWith({double? tabBarHeight, double? safeAreaBottom}) {
    return NativeTabBarMetrics(
      tabBarHeight: tabBarHeight ?? this.tabBarHeight,
      safeAreaBottom: safeAreaBottom ?? this.safeAreaBottom,
    );
  }
}

class NativeTabBarService {
  NativeTabBarService._();

  static final NativeTabBarService instance = NativeTabBarService._();

  static const _channelName = 'yy/native_tab_bar_service';

  MethodChannel? _channel;
  bool _initialized = false;

  final _tabSelectedController = StreamController<int>.broadcast();
  final _searchQueryController = StreamController<String>.broadcast();
  final ValueNotifier<NativeTabBarMetrics> _metrics = ValueNotifier(
    const NativeTabBarMetrics(tabBarHeight: 49, safeAreaBottom: 34),
  );

  /// 原生 UISearchController 的搜索查询流
  Stream<String> get onSearchQuery => _searchQueryController.stream;

  bool get _isIOS => !kIsWeb && Platform.isIOS;

  Stream<int> get onTabSelected => _tabSelectedController.stream;

  ValueListenable<NativeTabBarMetrics> get metrics => _metrics;

  NativeTabBarMetrics get currentMetrics => _metrics.value;

  void initialize() {
    if (!_isIOS || _initialized) return;

    _channel = const MethodChannel(_channelName);
    _channel!.setMethodCallHandler(_handleMethodCall);
    _initialized = true;
  }

  Future<void> setSelectedIndex(int index) async {
    if (!_isIOS || _channel == null) return;

    try {
      await _channel!.invokeMethod<void>('setSelectedIndex', index);
    } catch (error) {
      debugPrint('NativeTabBarService.setSelectedIndex failed: $error');
    }
  }

  Future<void> setTabBarVisible(bool visible) async {
    if (!_isIOS || _channel == null) return;

    try {
      await _channel!.invokeMethod<void>('setTabBarVisible', visible);
    } catch (error) {
      debugPrint('NativeTabBarService.setTabBarVisible failed: $error');
    }
  }

  Future<double> getTabBarHeight() async {
    if (!_isIOS || _channel == null) {
      return currentMetrics.tabBarHeight;
    }

    try {
      final result = await _channel!.invokeMethod<double>('getTabBarHeight');
      final value = result ?? currentMetrics.tabBarHeight;
      _metrics.value = currentMetrics.copyWith(tabBarHeight: value);
      return value;
    } catch (error) {
      debugPrint('NativeTabBarService.getTabBarHeight failed: $error');
      return currentMetrics.tabBarHeight;
    }
  }

  Future<double> getSafeAreaBottom() async {
    if (!_isIOS || _channel == null) {
      return currentMetrics.safeAreaBottom;
    }

    try {
      final result = await _channel!.invokeMethod<double>('getSafeAreaBottom');
      final value = result ?? currentMetrics.safeAreaBottom;
      _metrics.value = currentMetrics.copyWith(safeAreaBottom: value);
      return value;
    } catch (error) {
      debugPrint('NativeTabBarService.getSafeAreaBottom failed: $error');
      return currentMetrics.safeAreaBottom;
    }
  }

  Future<void> refreshMetrics() async {
    await Future.wait([getTabBarHeight(), getSafeAreaBottom()]);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    debugPrint('[NativeTabBarService] Received: ${call.method}, args: ${call.arguments}');
    switch (call.method) {
      case 'onTabSelected':
        final index = call.arguments as int;
        debugPrint('[NativeTabBarService] Tab selected: $index');
        _tabSelectedController.add(index);
        return null;
      case 'onSearchQuery':
        // 原生 UISearchController 转发的搜索查询
        final query = call.arguments as String? ?? '';
        debugPrint('[NativeTabBarService] Search query: $query');
        _searchQueryController.add(query);
        return null;
      case 'onMetricsChanged':
        final args = Map<dynamic, dynamic>.from(
          call.arguments as Map<dynamic, dynamic>,
        );
        _metrics.value = currentMetrics.copyWith(
          tabBarHeight: (args['tabBarHeight'] as num?)?.toDouble(),
          safeAreaBottom: (args['safeAreaBottom'] as num?)?.toDouble(),
        );
        return null;
      default:
        debugPrint('[NativeTabBarService] Unknown method: ${call.method}');
        return null;
    }
  }
}
