import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/theme.dart';
import '../../../../shared/widgets/gradient_cover.dart';
import 'queue_panel.dart';
import '../providers/player_provider.dart';

class MiniPlayer extends ConsumerStatefulWidget {
  const MiniPlayer({super.key});

  @override
  ConsumerState<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends ConsumerState<MiniPlayer> {
  double _dragOffset = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerProvider);
    final song = state.currentSong;

    if (song == null) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        context.push('/player');
      },
      onHorizontalDragUpdate: (details) {
        setState(() => _dragOffset += details.delta.dx);
      },
      onHorizontalDragEnd: (details) {
        if (_dragOffset.abs() > 60) {
          if (_dragOffset > 0) {
            HapticFeedback.mediumImpact();
            ref.read(playerProvider.notifier).previous();
          } else {
            HapticFeedback.mediumImpact();
            ref.read(playerProvider.notifier).next();
          }
        }
        setState(() => _dragOffset = 0);
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        showQueuePanel(context);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(_dragOffset * 0.4, 0, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Hero(
                  tag: 'track-cover-${song.id}',
                  child: _RotatingCover(
                    seed: '${song.title}_${song.artist}',
                    coverUrl: song.coverUrl,
                    isPlaying: state.isPlaying,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.yyTextTheme.titleMedium?.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.yyTextTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                          color: context.yyTextSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _MiniControl(
                  icon: state.isPlaying
                      ? CupertinoIcons.pause_fill
                      : CupertinoIcons.play_fill,
                  primary: true,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    ref.read(playerProvider.notifier).togglePlay();
                  },
                ),
                const SizedBox(width: 8),
                _MiniControl(
                  icon: CupertinoIcons.list_bullet,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    showQueuePanel(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Minimalist Glowing Progress Line
            Stack(
              children: [
                Container(
                  height: 1.5,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: state.progress.clamp(0.0, 1.0),
                  child: Container(
                    height: 1.5,
                    decoration: BoxDecoration(
                      color: YYColors.accentPrimary,
                      borderRadius: BorderRadius.circular(1),
                      boxShadow: [
                        BoxShadow(
                          color: YYColors.accentPrimary.withValues(alpha: 0.4),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniControl extends StatelessWidget {
  final IconData icon;
  final bool primary;
  final VoidCallback onTap;

  const _MiniControl({
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: primary 
            ? Colors.transparent 
            : Colors.white.withValues(alpha: 0.04),
          shape: BoxShape.circle,
          border: primary ? null : Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Center(
          child: Icon(
            icon,
            color: primary ? YYColors.accentPrimary : context.yyTextPrimary,
            size: primary ? 24 : 18,
          ),
        ),
      ),
    );
  }
}

class _RotatingCover extends StatefulWidget {
  final String seed;
  final String? coverUrl;
  final bool isPlaying;

  const _RotatingCover({
    required this.seed,
    this.coverUrl,
    required this.isPlaying,
  });

  @override
  State<_RotatingCover> createState() => _RotatingCoverState();
}

class _RotatingCoverState extends State<_RotatingCover>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 25),
      vsync: this,
    );
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _RotatingCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat();
    }
    if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _controller.value * 2 * math.pi,
          child: child,
        );
      },
      child: Container(
        width: YYSizes.miniCoverSize,
        height: YYSizes.miniCoverSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(YYRadius.coverSmall),
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, 6),
              blurRadius: 14,
              color: Colors.black.withValues(alpha: 0.5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(YYRadius.coverSmall),
          child: GradientCover(
            seed: widget.seed,
            coverUrl: widget.coverUrl,
            size: YYSizes.miniCoverSize,
            borderRadius: YYRadius.coverSmall,
          ),
        ),
      ),
    );
  }
}

extension on BuildContext {
  TextTheme get yyTextTheme => Theme.of(this).textTheme;
}

