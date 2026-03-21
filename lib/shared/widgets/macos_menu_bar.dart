import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/player/presentation/providers/player_provider.dart';

/// macOS 原生菜单栏
///
/// 提供标准的 macOS 菜单栏：Primuse、文件、播放、帮助
class MacOSMenuBar extends ConsumerWidget {
  final Widget child;
  const MacOSMenuBar({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_isMacOS) return child;

    return PlatformMenuBar(
      menus: [
        // 应用菜单
        PlatformMenu(
          label: 'Primuse',
          menus: [
            PlatformMenuItemGroup(members: [
              PlatformMenuItem(
                label: '关于 Primuse',
                onSelected: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'Primuse',
                    applicationVersion: '0.1.0',
                    applicationLegalese: '© 2024 KKape',
                  );
                },
              ),
            ]),
            PlatformMenuItemGroup(members: [
              PlatformMenuItem(
                label: '偏好设置…',
                shortcut: const SingleActivator(LogicalKeyboardKey.comma, meta: true),
                onSelected: () {
                  // 导航到设置页
                },
              ),
            ]),
            PlatformMenuItemGroup(members: [
              PlatformMenuItem(
                label: '退出 Primuse',
                shortcut: const SingleActivator(LogicalKeyboardKey.keyQ, meta: true),
                onSelected: () => SystemNavigator.pop(),
              ),
            ]),
          ],
        ),
        // 播放菜单
        PlatformMenu(
          label: '播放',
          menus: [
            PlatformMenuItemGroup(members: [
              PlatformMenuItem(
                label: '播放/暂停',
                shortcut: const SingleActivator(LogicalKeyboardKey.space),
                onSelected: () => ref.read(playerProvider.notifier).togglePlay(),
              ),
              PlatformMenuItem(
                label: '下一首',
                shortcut: const SingleActivator(LogicalKeyboardKey.arrowRight, meta: true),
                onSelected: () => ref.read(playerProvider.notifier).next(),
              ),
              PlatformMenuItem(
                label: '上一首',
                shortcut: const SingleActivator(LogicalKeyboardKey.arrowLeft, meta: true),
                onSelected: () => ref.read(playerProvider.notifier).previous(),
              ),
            ]),
            PlatformMenuItemGroup(members: [
              PlatformMenuItem(
                label: '增大音量',
                shortcut: const SingleActivator(LogicalKeyboardKey.arrowUp, meta: true),
                onSelected: () {
                  final state = ref.read(playerProvider);
                  ref.read(playerProvider.notifier).setVolume((state.volume + 0.1).clamp(0.0, 1.0));
                },
              ),
              PlatformMenuItem(
                label: '减小音量',
                shortcut: const SingleActivator(LogicalKeyboardKey.arrowDown, meta: true),
                onSelected: () {
                  final state = ref.read(playerProvider);
                  ref.read(playerProvider.notifier).setVolume((state.volume - 0.1).clamp(0.0, 1.0));
                },
              ),
            ]),
          ],
        ),
        // 帮助菜单
        PlatformMenu(
          label: '帮助',
          menus: [
            PlatformMenuItem(
              label: 'Primuse 帮助',
              onSelected: () {},
            ),
          ],
        ),
      ],
      child: child,
    );
  }

  static bool get _isMacOS {
    try { return Platform.isMacOS; } catch (_) { return false; }
  }
}
