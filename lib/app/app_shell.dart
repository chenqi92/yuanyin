import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'theme/theme.dart';
import '../features/player/presentation/widgets/mini_player.dart';

/// 全局容器 — 实现 UI 规范 §3.1 的视觉层级
///
/// 三层结构：
/// 1. (底层) Tab 页内容
/// 2. (中间层) Mini 播放器
/// 3. (顶层) 底部导航 TabBar（Liquid Glass 厚玻璃）
class AppShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: YYColors.bgBase,
      body: Stack(
        children: [
          // 层 1: Tab 内容
          navigationShell,

          // 层 2+3: Mini Player + TabBar（合体区域）
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
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
    );
  }
}

class _BottomArea extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabTap;

  const _BottomArea({
    required this.currentIndex,
    required this.onTabTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: YYBlur.thick, sigmaY: YYBlur.thick),
        child: Container(
          decoration: BoxDecoration(
            // 多层渐变模拟厚玻璃深度
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                YYColors.bgGlassThick,
                Color.alphaBlend(
                  Colors.black.withValues(alpha: 0.08),
                  YYColors.bgGlassThick,
                ),
              ],
            ),
            // 顶部高光边 — 模拟 Liquid Glass 光线折射
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.12),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 顶部微光条
                Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.0),
                        Colors.white.withValues(alpha: 0.08),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
                // Mini Player
                const MiniPlayer(),
                // Separator
                Container(
                  height: 0.5,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  color: Colors.white.withValues(alpha: 0.06),
                ),
                // TabBar
                _TabBar(
                  currentIndex: currentIndex,
                  onTap: onTabTap,
                ),
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
                  // 选中指示器 — 小型 Glass 胶囊
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.symmetric(
                      horizontal: isActive ? 16 : 0,
                      vertical: isActive ? 6 : 0,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? YYColors.accentPrimary.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: isActive
                          ? Border.all(
                              color: YYColors.accentPrimary.withValues(alpha: 0.2),
                              width: 0.5,
                            )
                          : null,
                    ),
                    child: Icon(
                      isActive ? tab.activeIcon : tab.icon,
                      size: 22,
                      color: isActive
                          ? YYColors.accentPrimary
                          : YYColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tab.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                      color: isActive
                          ? YYColors.accentPrimary
                          : YYColors.textTertiary,
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
