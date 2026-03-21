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

    final needsIndexSync = _lastNativeIndex != currentIndex;
    final needsVisibilitySync = _lastNativeVisibility != visible;
    if (!needsIndexSync && !needsVisibilitySync) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (needsVisibilitySync) {
        NativeTabBarService.instance.setTabBarVisible(visible);
        _lastNativeVisibility = visible;
      }
      if (needsIndexSync) {
        NativeTabBarService.instance.setSelectedIndex(currentIndex);
        _lastNativeIndex = currentIndex;
      }
      if (visible) {
        NativeTabBarService.instance.refreshMetrics();
      }
    });
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
            body: YYScenicBackground(child: widget.navigationShell),
            bottomNavigationBar: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SizeTransition(
                    sizeFactor: animation,
                    axisAlignment: -1,
                    child: child,
                  ),
                );
              },
              child: showNavigation
                  ? _ShellBottomArea(
                      key: const ValueKey('shell-navigation-visible'),
                      hasSong: hasSong,
                      isIOS: isIOS,
                      child: _BottomNavigation(
                        currentIndex: widget.navigationShell.currentIndex,
                        onTap: (index) {
                          ShellNavigationVisibility.instance.reset();
                          widget.navigationShell.goBranch(
                            index,
                            initialLocation:
                                index == widget.navigationShell.currentIndex,
                          );
                        },
                      ),
                    )
                  : const SizedBox.shrink(
                      key: ValueKey('shell-navigation-hidden'),
                    ),
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
      icon: CupertinoIcons.search,
      selectedIcon: CupertinoIcons.search,
      label: '搜索',
      sfSymbol: 'magnifyingglass',
      selectedSFSymbol: 'magnifyingglass',
    ),
    YYTabDestination(
      icon: CupertinoIcons.slider_horizontal_3,
      selectedIcon: CupertinoIcons.slider_horizontal_3,
      label: '设置',
      sfSymbol: 'slider.horizontal.3',
      selectedSFSymbol: 'slider.horizontal.3',
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
