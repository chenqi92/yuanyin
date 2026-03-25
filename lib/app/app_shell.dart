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
                // iOS: 仅显示 mini player（tab bar 由原生 UITabBarController 渲染）
                // 非 iOS: 显示 mini player + Flutter Material NavigationBar
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
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
                        ? _ShellBottomArea(
                            key: const ValueKey('shell-navigation-visible'),
                            hasSong: hasSong,
                            isIOS: isIOS,
                            child: isIOS
                                // iOS: 不渲染 tab bar（原生 UITabBarController 管理）
                                ? const SizedBox.shrink()
                                // 非 iOS: 保留 Flutter Material NavigationBar
                                : _BottomNavigation(
                                    currentIndex:
                                        widget.navigationShell.currentIndex,
                                    onTap: (index) {
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
                                  ),
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

class _ShellBottomArea extends StatelessWidget {
  final bool hasSong;
  final bool isIOS;
  final Widget child;

  const _ShellBottomArea({
    super.key,
    required this.hasSong,
    required this.isIOS,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasSong)
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: _MiniPlayerDock(),
          ),
        child,
      ],
    );

    if (isIOS) {
      return content;
    }

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: content,
    );
  }
}

class _MiniPlayerDock extends StatelessWidget {
  const _MiniPlayerDock();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.yyBgElevated.withValues(
          alpha: context.isDark ? 0.96 : 0.99,
        ),
        borderRadius: BorderRadius.circular(YYRadius.lg),
        border: Border.all(
          color: context.isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: YYShadows.cardSubtle,
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: const MiniPlayer(),
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
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final nav = YYAdaptiveTabBar(
      destinations: _tabs,
      currentIndex: currentIndex,
      onTap: onTap,
    );

    if (isIOS) {
      return nav;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.yyBgElevated.withValues(
          alpha: context.isDark ? 0.98 : 0.99,
        ),
        borderRadius: BorderRadius.circular(YYRadius.xl),
        border: Border.all(
          color: context.isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: YYShadows.cardSubtle,
      ),
      child: nav,
    );
  }
}
