import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'theme/theme.dart';
import '../features/player/presentation/widgets/mini_player.dart';
import '../shared/widgets/keyboard_shortcuts.dart';

/// 全局容器 — 三层：Tab 内容 + MiniPlayer + TabBar
class AppShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? YYColors.bgBase : YYLightColors.bgBase;

    return KeyboardShortcuts(
      child: Scaffold(
        backgroundColor: bg,
        body: Stack(
          children: [
            navigationShell,
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: _BottomArea(
                currentIndex: navigationShell.currentIndex,
                onTabTap: (index) => navigationShell.goBranch(
                  index,
                  initialLocation: index == navigationShell.currentIndex,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomArea extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabTap;

  const _BottomArea({required this.currentIndex, required this.onTabTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? YYColors.bgBase : YYLightColors.bgBase;
    final sep = isDark ? YYColors.separator : YYLightColors.separator;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          decoration: BoxDecoration(
            color: bg.withValues(alpha: 0.85),
            border: Border(top: BorderSide(color: sep, width: 0.5)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MiniPlayer(),
                _TabBar(currentIndex: currentIndex, onTap: onTabTap),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _TabBar({required this.currentIndex, required this.onTap});

  static const _tabs = [
    _TabItem(icon: CupertinoIcons.house, activeIcon: CupertinoIcons.house_fill, label: '首页'),
    _TabItem(icon: CupertinoIcons.square_grid_2x2, activeIcon: CupertinoIcons.square_grid_2x2_fill, label: '音乐库'),
    _TabItem(icon: CupertinoIcons.search, activeIcon: CupertinoIcons.search, label: '搜索'),
    _TabItem(icon: CupertinoIcons.gear, activeIcon: CupertinoIcons.gear_solid, label: '设置'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tri = isDark ? YYColors.textTertiary : YYLightColors.textTertiary;

    return SizedBox(
      height: YYSizes.tabBarHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_tabs.length, (i) {
          final tab = _tabs[i];
          final isActive = currentIndex == i;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isActive ? tab.activeIcon : tab.icon,
                    size: 22,
                    color: isActive ? YYColors.accentPrimary : tri,
                  ),
                  const SizedBox(height: 3),
                  Text(tab.label, style: TextStyle(
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    color: isActive ? YYColors.accentPrimary : tri,
                  )),
                  const SizedBox(height: 3),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: isActive ? 4 : 0,
                    height: isActive ? 4 : 0,
                    decoration: const BoxDecoration(
                      color: YYColors.accentPrimary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _TabItem({required this.icon, required this.activeIcon, required this.label});
}
