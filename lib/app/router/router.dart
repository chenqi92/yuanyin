import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app_shell.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/library/presentation/pages/library_page.dart';
import '../../features/search/presentation/pages/search_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/player/presentation/pages/now_playing_page.dart';
import '../../features/player/presentation/pages/equalizer_page.dart';
import '../../features/sources/presentation/pages/sources_page.dart';
import '../../features/favorites/presentation/pages/favorites_page.dart';
import '../../features/library/presentation/pages/play_stats_page.dart';
import '../../features/library/presentation/pages/scraper_sources_page.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Primuse 路由配置 — 3 Tab + 全屏播放页 + 子页面
final goRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    // 全屏播放页 — 顶层路由（覆盖 TabBar）
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/player',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const NowPlayingPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );

          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.08),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    ),
    // 搜索页 — 顶层路由（覆盖 TabBar），无过渡动画
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/search',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const SearchPage(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: const Duration(milliseconds: 200),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    ),
    // 源管理页
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/sources',
      builder: (context, state) => const SourcesPage(),
    ),
    // 刮削源管理页
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/scraper-sources',
      builder: (context, state) => const ScraperSourcesPage(),
    ),
    // 收藏页
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/favorites',
      builder: (context, state) => const FavoritesPage(),
    ),
    // 均衡器页
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/equalizer',
      builder: (context, state) => const EqualizerPage(),
    ),
    // 播放统计页
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/stats',
      builder: (context, state) => const PlayStatsPage(),
    ),
    // 底部 Tab 路由 — 3 Tab: 首页 / 音乐库 / 设置
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return AppShell(navigationShell: navigationShell);
      },
      branches: [
        // Tab 0: 首页
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const HomePage(),
            ),
          ],
        ),
        // Tab 1: 音乐库
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/library',
              builder: (context, state) => const LibraryPage(),
            ),
          ],
        ),
        // Tab 2: 设置
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsPage(),
            ),
          ],
        ),
      ],
    ),
  ],
);
