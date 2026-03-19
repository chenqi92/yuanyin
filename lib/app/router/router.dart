import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app_shell.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/library/presentation/pages/library_page.dart';
import '../../features/search/presentation/pages/search_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/player/presentation/pages/now_playing_page.dart';
import '../../features/sources/presentation/pages/sources_page.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// 猿音路由配置 — 4 Tab + 全屏播放页 + 子页面
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
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
      ),
    ),
    // 源管理页
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/sources',
      builder: (context, state) => const SourcesPage(),
    ),
    // 底部 Tab 路由
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
        // Tab 2: 搜索
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/search',
              builder: (context, state) => const SearchPage(),
            ),
          ],
        ),
        // Tab 3: 设置
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
