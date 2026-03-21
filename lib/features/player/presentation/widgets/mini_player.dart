import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
      onTap: () => context.push('/player'),
      onLongPress: () => showQueuePanel(context),
      child: SizedBox(
        height: YYSizes.miniPlayerHeight,
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Hero(
                    tag: 'mini-player-cover',
                    child: _RotatingCover(
                      seed: '${song.title}_${song.artist}',
                      coverUrl: song.coverUrl,
                      isPlaying: state.isPlaying,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.yyTextPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          song.album.isEmpty
                              ? song.artist
                              : '${song.artist} · ${song.album}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.yyTextSecondary,
                            fontSize: 11,
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
                    onTap: () => ref.read(playerProvider.notifier).togglePlay(),
                  ),
                  const SizedBox(width: 6),
                  _MiniControl(
                    icon: CupertinoIcons.list_bullet_below_rectangle,
                    onTap: () => showQueuePanel(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(YYRadius.full),
              child: LinearProgressIndicator(
                value: state.progress,
                minHeight: 3,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation<Color>(
                  YYSeedPalette.primary(song.title),
                ),
              ),
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
    return Material(
      color: Colors.transparent,
      child: Ink(
        width: primary ? 34 : 32,
        height: primary ? 34 : 32,
        decoration: BoxDecoration(
          gradient: primary && context.isDark ? YYColors.accentGradient : null,
          color: primary
              ? primary && !context.isDark
                    ? YYColors.accentPrimary
                    : null
              : context.yyBgSurface.withValues(
                  alpha: context.isDark ? 0.22 : 0.34,
                ),
          borderRadius: BorderRadius.circular(YYRadius.full),
          border: Border.all(
            color: primary
                ? Colors.transparent
                : context.isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(YYRadius.full),
          child: Icon(
            icon,
            color: primary ? Colors.white : context.yyTextPrimary,
            size: primary ? 17 : 16,
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
      duration: const Duration(seconds: 16),
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
        padding: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: YYSeedPalette.gradient(widget.seed),
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, 10),
              blurRadius: 24,
              spreadRadius: -16,
              color: Colors.black.withValues(alpha: 0.55),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.5),
          child: GradientCover(
            seed: widget.seed,
            coverUrl: widget.coverUrl,
            size: YYSizes.miniCoverSize,
            borderRadius: 12.5,
          ),
        ),
      ),
    );
  }
}
