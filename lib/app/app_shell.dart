import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/player/presentation/providers/player_provider.dart';
import '../features/player/presentation/widgets/mini_player.dart';
import '../shared/services/native_tab_bar_service.dart';
import '../shared/services/shell_navigation_visibility.dart';
import '../shared/widgets/keyboard_shortcuts.dart';
import '../shared/widgets/modern_music_ui.dart';
import '../shared/widgets/native_tab_bar.dart';
import 'theme/theme.dart';

class AppShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int? _lastNativeIndex;
  bool? _lastNativeVisibility;

  void _syncNativeTabBar({
    required bool isIOS,
    required int currentIndex,
    required bool visible,
  }) {
    if (!isIOS) {
      _lastNativeIndex = null;
      _lastNativeVisibility = null;
      return;
    }

    // iOS: native tab bar 管理自身选中状态，Flutter 只控制可见性
    final needsVisibilitySync = _lastNativeVisibility != visible;
    if (!needsVisibilitySync) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (needsVisibilitySync) {
        NativeTabBarService.instance.setTabBarVisible(visible);
        _lastNativeVisibility = visible;
      }
      if (visible) {
        NativeTabBarService.instance.refreshMetrics();
      }
    });
  }

  StreamSubscription<int>? _tabSub;

  @override
  void initState() {
    super.initState();
    // 初始化原生 tab bar 服务（注册 method channel handler）
    NativeTabBarService.instance.initialize();
    // 监听原生 UITabBarController 的 tab 选择（仅 iOS）
    _tabSub = NativeTabBarService.instance.onTabSelected.listen(_handleNativeTabSelected);
  }

  @override
  void dispose() {
    _tabSub?.cancel();
    super.dispose();
  }

  void _handleNativeTabSelected(int index) {
    // index 3 = 搜索 Tab → 由 native UISearchController 处理，Flutter 不做跳转
    if (index == 3) return;

    ShellNavigationVisibility.instance.reset();
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSong = ref.watch(
      playerProvider.select((state) => state.currentSong != null),
    );

    return KeyboardShortcuts(
      child: ValueListenableBuilder<int>(
        valueListenable: ShellNavigationVisibility.instance.listenable,
        builder: (context, hiddenDepth, _) {
          final showNavigation = hiddenDepth == 0;
          final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

          _syncNativeTabBar(
            isIOS: isIOS,
            currentIndex: widget.navigationShell.currentIndex,
            visible: showNavigation,
          );

          return Scaffold(
            backgroundColor: context.yyBgBase,
            body: Stack(
              children: [
                Positioned.fill(
                  child: YYScenicBackground(child: widget.navigationShell),
                ),
                // Bottom Area: Mini Player + Navigation
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeOutQuart,
                    switchOutCurve: Curves.easeInQuart,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 1),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: showNavigation
                        ? _UnifiedGlassDock(
                            key: const ValueKey('shell-navigation-visible'),
                            hasSong: hasSong,
                            isIOS: isIOS,
                            currentIndex: widget.navigationShell.currentIndex,
                            onTabTap: (index) {
                              if (index == 3) {
                                context.push('/search');
                                return;
                              }
                              ShellNavigationVisibility.instance.reset();
                              widget.navigationShell.goBranch(
                                index,
                                initialLocation: index ==
                                    widget.navigationShell.currentIndex,
                              );
                            },
                          )
                        : const SizedBox.shrink(
                            key: ValueKey('shell-navigation-hidden'),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _UnifiedGlassDock extends StatelessWidget {
  final bool hasSong;
  final bool isIOS;
  final int currentIndex;
  final ValueChanged<int> onTabTap;

  const _UnifiedGlassDock({
    super.key,
    required this.hasSong,
    required this.isIOS,
    required this.currentIndex,
    required this.onTabTap,
  });

  @override
  Widget build(BuildContext context) {
    // iOS: Only Mini Player is Flutter-side (Tab Bar is native)
    if (isIOS) {
      if (!hasSong) return const SizedBox.shrink();
      
      return Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
        child: GlassContainer(
          thick: true,
          borderRadius: BorderRadius.circular(YYRadius.xl),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: const MiniPlayer(),
        ),
      );
    }

    // Non-iOS: Unified Mini Player + Bottom Nav
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: GlassContainer(
        thick: true,
        borderRadius: BorderRadius.circular(YYRadius.xl),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasSong) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: MiniPlayer(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Divider(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ],
            _BottomNavigation(
              currentIndex: currentIndex,
              onTap: onTabTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNavigation({required this.currentIndex, required this.onTap});

  static const _tabs = [
    YYTabDestination(
      icon: CupertinoIcons.house,
      selectedIcon: CupertinoIcons.house_fill,
      label: '首页',
      sfSymbol: 'house',
      selectedSFSymbol: 'house.fill',
    ),
    YYTabDestination(
      icon: CupertinoIcons.square_stack_3d_down_right,
      selectedIcon: CupertinoIcons.square_stack_3d_down_right_fill,
      label: '音乐库',
      sfSymbol: 'square.stack.3d.down.right',
      selectedSFSymbol: 'square.stack.3d.down.right.fill',
    ),
    YYTabDestination(
      icon: CupertinoIcons.slider_horizontal_3,
      selectedIcon: CupertinoIcons.slider_horizontal_3,
      label: '设置',
      sfSymbol: 'slider.horizontal.3',
      selectedSFSymbol: 'slider.horizontal.3',
    ),
    YYTabDestination(
      icon: CupertinoIcons.search,
      selectedIcon: CupertinoIcons.search,
      label: '搜索',
      sfSymbol: 'magnifyingglass',
      selectedSFSymbol: 'magnifyingglass',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return YYAdaptiveTabBar(
      destinations: _tabs,
      currentIndex: currentIndex,
      onTap: onTap,
    );
  }
}
