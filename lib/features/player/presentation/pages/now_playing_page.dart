import 'dart:math';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/theme.dart';
import '../../../../shared/widgets/gradient_cover.dart';
import '../providers/player_provider.dart';

/// 全屏播放页 (UI 规范 §3.3)
///
/// 极致沉浸感 — 封面主色调背景模糊 + 大封面 + 完整控制
class NowPlayingPage extends ConsumerWidget {
  const NowPlayingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final song = playerState.currentSong;
    final screenWidth = MediaQuery.of(context).size.width;
    final coverSize = screenWidth * 0.80;

    if (song == null) {
      return const Scaffold(
        backgroundColor: YYColors.bgBase,
        body: Center(child: Text('暂无播放', style: TextStyle(color: YYColors.textSecondary))),
      );
    }

    // 基于歌曲名生成背景主色
    final hash = '${song.title}_${song.artist}'.hashCode;
    final random = Random(hash);
    final hue = random.nextDouble() * 360;
    final bgColor = HSLColor.fromAHSL(1.0, hue, 0.6, 0.25).toColor();

    return Scaffold(
      backgroundColor: YYColors.bgBase,
      body: Stack(
        children: [
          // 背景：封面主色调模糊 + 黑色遮罩
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [bgColor, YYColors.bgBase],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: YYBlur.playerBg, sigmaY: YYBlur.playerBg),
              child: Container(color: Colors.black.withValues(alpha: 0.4)),
            ),
          ),

          // 主内容
          SafeArea(
            child: Column(
              children: [
                // 顶部栏
                _TopBar(sourceName: song.format ?? '猿音'),

                const Spacer(flex: 1),

                // 大封面 (Hero 动画)
                Hero(
                  tag: 'album_cover',
                  child: AnimatedScale(
                    scale: playerState.isPlaying ? 1.0 : 0.9,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(YYRadius.coverLarge),
                        boxShadow: YYShadows.coverFloat,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                          width: 0.5,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(YYRadius.coverLarge),
                        child: GradientCover(
                          seed: '${song.title}_${song.artist}',
                          size: coverSize,
                          borderRadius: YYRadius.coverLarge,
                        ),
                      ),
                    ),
                  ),
                ),

                const Spacer(flex: 1),

                // 歌曲信息
                _SongInfo(
                  title: song.title,
                  artist: song.artist,
                  isFavorite: playerState.isFavorite,
                  onFavoriteToggle: () =>
                      ref.read(playerProvider.notifier).toggleFavorite(),
                ),

                const SizedBox(height: 20),

                // 进度条
                _ProgressBar(
                  position: playerState.position,
                  duration: playerState.duration,
                  onSeek: (pos) =>
                      ref.read(playerProvider.notifier).seek(pos),
                ),

                const SizedBox(height: 16),

                // 主控区
                _MainControls(
                  isPlaying: playerState.isPlaying,
                  playMode: playerState.playMode,
                  onTogglePlay: () =>
                      ref.read(playerProvider.notifier).togglePlay(),
                  onNext: () => ref.read(playerProvider.notifier).next(),
                  onPrevious: () =>
                      ref.read(playerProvider.notifier).previous(),
                  onCycleMode: () =>
                      ref.read(playerProvider.notifier).cyclePlayMode(),
                ),

                const SizedBox(height: 24),

                // 底部操作栏
                const _BottomActions(),

                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 顶部栏 — 下拉指示条 + 来源标识
class _TopBar extends StatelessWidget {
  final String sourceName;
  const _TopBar({required this.sourceName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: [
          // 下拉指示条
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 来源信息
          Text(
            'Playing from $sourceName',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: YYColors.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// 歌曲信息区
class _SongInfo extends StatelessWidget {
  final String title;
  final String artist;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  const _SongInfo({
    required this.title,
    required this.artist,
    required this.isFavorite,
    required this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: YYColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  artist,
                  style: const TextStyle(
                    fontSize: 17,
                    color: YYColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // 收藏按钮（带弹跳动效）
          GestureDetector(
            onTap: onFavoriteToggle,
            child: Icon(
              isFavorite ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
              size: 28,
              color: isFavorite ? YYColors.heartRed : YYColors.textSecondary,
            )
                .animate(target: isFavorite ? 1 : 0)
                .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.3, 1.3),
                  duration: 150.ms,
                )
                .then()
                .scale(
                  begin: const Offset(1.3, 1.3),
                  end: const Offset(1, 1),
                  duration: 150.ms,
                  curve: Curves.elasticOut,
                ),
          ),
        ],
      ),
    );
  }
}

/// 进度条 (2px 极细)
class _ProgressBar extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  const _ProgressBar({
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          // 进度条主体
          GestureDetector(
            onHorizontalDragUpdate: (details) {
              final box = context.findRenderObject() as RenderBox;
              final width = box.size.width - 64; // padding
              final ratio = (details.localPosition.dx / width).clamp(0.0, 1.0);
              onSeek(Duration(
                  milliseconds:
                      (duration.inMilliseconds * ratio).round()));
            },
            child: Container(
              height: 24,
              alignment: Alignment.center,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // 背景轨道
                  Container(
                    height: YYSizes.progressBarHeight,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  // 已播放
                  FractionallySizedBox(
                    widthFactor: progress.clamp(0.0, 1.0),
                    child: Container(
                      height: YYSizes.progressBarHeight,
                      decoration: BoxDecoration(
                        color: YYColors.accentPrimary,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          // 时间标签
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(position),
                style: const TextStyle(
                  fontSize: 12,
                  color: YYColors.textTertiary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                _formatDuration(duration),
                style: const TextStyle(
                  fontSize: 12,
                  color: YYColors.textTertiary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 主控区 — 循环/上一首/播放暂停/下一首/随机
class _MainControls extends StatelessWidget {
  final bool isPlaying;
  final PlayMode playMode;
  final VoidCallback onTogglePlay;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onCycleMode;

  const _MainControls({
    required this.isPlaying,
    required this.playMode,
    required this.onTogglePlay,
    required this.onNext,
    required this.onPrevious,
    required this.onCycleMode,
  });

  IconData _playModeIcon() {
    switch (playMode) {
      case PlayMode.loop:
        return CupertinoIcons.repeat;
      case PlayMode.single:
        return CupertinoIcons.repeat_1;
      case PlayMode.shuffle:
        return CupertinoIcons.shuffle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 播放模式
          GestureDetector(
            onTap: onCycleMode,
            child: Icon(
              _playModeIcon(),
              size: 24,
              color: playMode == PlayMode.loop
                  ? YYColors.textSecondary
                  : YYColors.accentPrimary,
            ),
          ),

          // 上一首
          GestureDetector(
            onTap: onPrevious,
            child: const Icon(
              CupertinoIcons.backward_fill,
              size: YYSizes.playButtonMedium,
              color: YYColors.textPrimary,
            ),
          ),

          // 播放/暂停（大尺寸）
          GestureDetector(
            onTap: onTogglePlay,
            child: Container(
              width: YYSizes.playButtonLarge,
              height: YYSizes.playButtonLarge,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: YYColors.textPrimary,
              ),
              child: Icon(
                isPlaying
                    ? CupertinoIcons.pause_fill
                    : CupertinoIcons.play_fill,
                size: 30,
                color: YYColors.bgBase,
              ),
            ),
          ),

          // 下一首
          GestureDetector(
            onTap: onNext,
            child: const Icon(
              CupertinoIcons.forward_fill,
              size: YYSizes.playButtonMedium,
              color: YYColors.textPrimary,
            ),
          ),

          // 随机播放 (作为独立按钮)
          GestureDetector(
            onTap: onCycleMode,
            child: Icon(
              CupertinoIcons.shuffle,
              size: 24,
              color: playMode == PlayMode.shuffle
                  ? YYColors.accentPrimary
                  : YYColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 底部操作栏 — 歌词入口/队列入口
class _BottomActions extends StatelessWidget {
  const _BottomActions();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 歌词入口
          GestureDetector(
            onTap: () {
              // TODO: 歌词页
            },
            child: const Icon(
              CupertinoIcons.quote_bubble,
              size: 22,
              color: YYColors.textSecondary,
            ),
          ),

          // 音频引擎指示
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Hi-Res',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: YYColors.textTertiary,
                letterSpacing: 0.5,
              ),
            ),
          ),

          // 队列入口
          GestureDetector(
            onTap: () {
              // TODO: 队列页
            },
            child: const Icon(
              CupertinoIcons.list_bullet,
              size: 22,
              color: YYColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
