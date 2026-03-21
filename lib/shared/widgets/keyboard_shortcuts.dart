import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/player/presentation/providers/player_provider.dart';

/// macOS 快捷键支持
///
/// 空格: 播放/暂停
/// Cmd+→: 下一首
/// Cmd+←: 上一首
/// Cmd+↑: 音量增
/// Cmd+↓: 音量减
class KeyboardShortcuts extends ConsumerWidget {
  final Widget child;
  const KeyboardShortcuts({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 仅 macOS 激活
    if (!_isMacOS) return child;

    return Shortcuts(
      shortcuts: {
        // 空格播放/暂停
        const SingleActivator(LogicalKeyboardKey.space): const _PlayPauseIntent(),
        // Cmd+Right 下一首
        const SingleActivator(LogicalKeyboardKey.arrowRight, meta: true): const _NextTrackIntent(),
        // Cmd+Left 上一首
        const SingleActivator(LogicalKeyboardKey.arrowLeft, meta: true): const _PrevTrackIntent(),
        // Cmd+Up 音量增
        const SingleActivator(LogicalKeyboardKey.arrowUp, meta: true): const _VolumeUpIntent(),
        // Cmd+Down 音量减
        const SingleActivator(LogicalKeyboardKey.arrowDown, meta: true): const _VolumeDownIntent(),
      },
      child: Actions(
        actions: {
          _PlayPauseIntent: CallbackAction<_PlayPauseIntent>(
            onInvoke: (_) => ref.read(playerProvider.notifier).togglePlay(),
          ),
          _NextTrackIntent: CallbackAction<_NextTrackIntent>(
            onInvoke: (_) => ref.read(playerProvider.notifier).next(),
          ),
          _PrevTrackIntent: CallbackAction<_PrevTrackIntent>(
            onInvoke: (_) => ref.read(playerProvider.notifier).previous(),
          ),
          _VolumeUpIntent: CallbackAction<_VolumeUpIntent>(
            onInvoke: (_) {
              final state = ref.read(playerProvider);
              final newVol = (state.volume + 0.1).clamp(0.0, 1.0);
              ref.read(playerProvider.notifier).setVolume(newVol);
              return null;
            },
          ),
          _VolumeDownIntent: CallbackAction<_VolumeDownIntent>(
            onInvoke: (_) {
              final state = ref.read(playerProvider);
              final newVol = (state.volume - 0.1).clamp(0.0, 1.0);
              ref.read(playerProvider.notifier).setVolume(newVol);
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: child,
        ),
      ),
    );
  }

  static bool get _isMacOS {
    try { return Platform.isMacOS; } catch (_) { return false; }
  }
}

class _PlayPauseIntent extends Intent { const _PlayPauseIntent(); }
class _NextTrackIntent extends Intent { const _NextTrackIntent(); }
class _PrevTrackIntent extends Intent { const _PrevTrackIntent(); }
class _VolumeUpIntent extends Intent { const _VolumeUpIntent(); }
class _VolumeDownIntent extends Intent { const _VolumeDownIntent(); }
