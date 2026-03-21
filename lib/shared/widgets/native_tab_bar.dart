import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../app/theme/theme.dart';

class YYTabDestination {
  const YYTabDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.sfSymbol,
    required this.selectedSFSymbol,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String sfSymbol;
  final String selectedSFSymbol;

  Map<String, dynamic> toMap() => {
    'icon': sfSymbol,
    'selectedIcon': selectedSFSymbol,
    'label': label,
  };
}

class YYAdaptiveTabBar extends StatefulWidget {
  const YYAdaptiveTabBar({
    super.key,
    required this.destinations,
    required this.currentIndex,
    required this.onTap,
  });

  final List<YYTabDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  State<YYAdaptiveTabBar> createState() => _YYAdaptiveTabBarState();
}

class _YYAdaptiveTabBarState extends State<YYAdaptiveTabBar> {
  MethodChannel? _channel;
  bool? _lastIsDark;

  bool get _useNativeIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  double _nativeIOSHeight(BuildContext context) {
    return 49 + MediaQuery.viewPaddingOf(context).bottom;
  }

  @override
  void didUpdateWidget(covariant YYAdaptiveTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_useNativeIOS) {
      if (oldWidget.currentIndex != widget.currentIndex) {
        _channel?.invokeMethod<void>(
          'updateSelectedIndex',
          widget.currentIndex,
        );
      }

      final isDark = Theme.of(context).brightness == Brightness.dark;
      if (_lastIsDark != isDark) {
        _lastIsDark = isDark;
        _channel?.invokeMethod<void>('updateTheme', isDark);
      }
    }
  }

  void _onPlatformViewCreated(int viewId) {
    final channel = MethodChannel('yy/native_tab_bar_$viewId');
    _channel = channel;
    _lastIsDark = Theme.of(context).brightness == Brightness.dark;
    channel.setMethodCallHandler((call) async {
      if (call.method != 'onTabTap') return;
      final index = call.arguments as int;
      if (index != widget.currentIndex) {
        widget.onTap(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_useNativeIOS) {
      return SizedBox(
        height: _nativeIOSHeight(context),
        child: UiKitView(
          viewType: 'yy/native_tab_bar',
          creationParamsCodec: const StandardMessageCodec(),
          creationParams: <String, dynamic>{
            'selectedIndex': widget.currentIndex,
            'isDark': Theme.of(context).brightness == Brightness.dark,
            'items': widget.destinations.map((item) => item.toMap()).toList(),
          },
          onPlatformViewCreated: _onPlatformViewCreated,
          hitTestBehavior: PlatformViewHitTestBehavior.opaque,
        ),
      );
    }

    return NavigationBarTheme(
      data: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: Colors.transparent,
        indicatorColor: YYColors.accentPrimary.withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            color: states.contains(WidgetState.selected)
                ? context.yyTextPrimary
                : context.yyTextTertiary,
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w600,
          );
        }),
      ),
      child: NavigationBar(
        selectedIndex: widget.currentIndex,
        onDestinationSelected: widget.onTap,
        height: 64,
        shadowColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: widget.destinations.map((item) {
          return NavigationDestination(
            icon: Icon(item.icon, size: 22),
            selectedIcon: Icon(item.selectedIcon, size: 22),
            label: item.label,
          );
        }).toList(),
      ),
    );
  }
}
