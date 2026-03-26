import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/theme.dart';
import '../../../../shared/widgets/gradient_cover.dart';
import 'queue_panel.dart';
import '../providers/player_provider.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      onLongPress: () {
        HapticFeedback.mediumImpact();
        showQueuePanel(context);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Hero(
                tag: 'mini-player-cover',
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
                        fontSize: 14,
                        letterSpacing: -0.2,
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
          const SizedBox(height: 10),
          // Progress bar as a very thin line at the bottom
          Stack(
            children: [
              Container(
                height: 2,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              FractionallySizedBox(
                widthFactor: state.progress.clamp(0.0, 1.0),
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: YYColors.accentPrimary,
                    borderRadius: BorderRadius.circular(1),
                    boxShadow: [
                      BoxShadow(
                        color: YYColors.accentPrimary.withValues(alpha: 0.3),
                        blurRadius: 4,
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
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: primary 
            ? Colors.transparent 
            : Colors.white.withValues(alpha: 0.05),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            icon,
            color: primary ? YYColors.accentPrimary : context.yyTextPrimary,
            size: primary ? 22 : 18,
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
      duration: const Duration(seconds: 20),
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
              offset: const Offset(0, 4),
              blurRadius: 12,
              color: Colors.black.withValues(alpha: 0.4),
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
