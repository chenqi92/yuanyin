import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/theme.dart';
import '../../../../shared/widgets/gradient_cover.dart';
import '../providers/player_provider.dart';

/// 迷你播放器 — v2 自适应亮暗主题
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerProvider);
    if (!state.hasSong) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pri = isDark ? YYColors.textPrimary : YYLightColors.textPrimary;
    final sub = isDark ? YYColors.textSecondary : YYLightColors.textSecondary;
    final sep = isDark ? YYColors.separator : YYLightColors.separator;

    final song = state.currentSong!;
    final progress = state.duration.inMilliseconds > 0
        ? (state.position.inMilliseconds / state.duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onTap: () => context.push('/player'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 2,
            child: Stack(
              children: [
                Container(color: sep),
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(decoration: const BoxDecoration(gradient: YYColors.accentGradient)),
                ),
              ],
            ),
          ),
          Container(
            height: YYSizes.miniPlayerHeight,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Hero(
                  tag: 'cover',
                  child: _RotatingCover(seed: song.title, coverUrl: song.coverUrl, isPlaying: state.isPlaying),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(song.title,
                          style: TextStyle(color: pri, fontSize: 14, fontWeight: FontWeight.w500),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(song.artist,
                          style: TextStyle(color: sub, fontSize: 12),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => ref.read(playerProvider.notifier).togglePlay(),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      gradient: YYColors.accentGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        state.isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                        key: ValueKey(state.isPlaying),
                        color: Colors.white, size: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => ref.read(playerProvider.notifier).next(),
                  child: Icon(CupertinoIcons.forward_fill, color: sub, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RotatingCover extends StatefulWidget {
  final String seed;
  final String? coverUrl;
  final bool isPlaying;
  const _RotatingCover({required this.seed, this.coverUrl, required this.isPlaying});

  @override
  State<_RotatingCover> createState() => _RotatingCoverState();
}

class _RotatingCoverState extends State<_RotatingCover> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(seconds: 12), vsync: this);
    if (widget.isPlaying) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant _RotatingCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.rotate(
        angle: _controller.value * 2 * pi,
        child: child,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(YYRadius.coverSmall),
        child: SizedBox(
          width: YYSizes.miniCoverSize,
          height: YYSizes.miniCoverSize,
          child: GradientCover(seed: widget.seed, coverUrl: widget.coverUrl, size: YYSizes.miniCoverSize),
        ),
      ),
    );
  }
}
