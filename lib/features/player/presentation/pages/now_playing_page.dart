import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/theme.dart';
import '../../../../shared/widgets/gradient_cover.dart';
import '../../../../shared/widgets/modern_music_ui.dart';
import '../providers/player_provider.dart';
import '../widgets/queue_panel.dart';
import '../../../lyric/presentation/pages/lyrics_page.dart';
import '../../../library/presentation/widgets/auto_scrape_dialog.dart';
import '../../../library/presentation/pages/manual_music_scraper_page.dart';

class NowPlayingPage extends ConsumerStatefulWidget {
  const NowPlayingPage({super.key});

  @override
  ConsumerState<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends ConsumerState<NowPlayingPage> {
  double _dragOffset = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerProvider);
    final song = state.currentSong;

    if (song == null) {
      return Scaffold(
        backgroundColor: context.yyBgBase,
        body: Center(
          child: Text(
            '暂无播放',
            style: TextStyle(color: context.yyTextSecondary),
          ),
        ),
      );
    }

    final accent = YYSeedPalette.primary(song.title);
    final accentSoft = YYSeedPalette.secondary(song.title);
    final dismissProgress = yyClamp(_dragOffset / 240, 0, 1);
    final nextSong = state.queue.length > 1 && state.queueIndex + 1 < state.queue.length
        ? state.queue[state.queueIndex + 1]
        : null;
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor: context.yyBgBase,
      body: GestureDetector(
        onVerticalDragUpdate: (details) {
          if (details.delta.dy > 0) {
            setState(() => _dragOffset = (_dragOffset + details.delta.dy).clamp(0, 320));
          }
        },
        onVerticalDragEnd: (details) {
          if (_dragOffset > 140 || (details.primaryVelocity ?? 0) > 1100) {
            context.pop();
            return;
          }
          setState(() => _dragOffset = 0);
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      context.yyBgBase,
                      Color.alphaBlend(
                        accent.withValues(alpha: isDark ? 0.10 : 0.06),
                        context.yyBgBase,
                      ),
                      context.yyBgBase,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -120,
              right: -40,
              child: _Glow(size: 280, color: accent, isDark: isDark),
            ),
            Positioned(
              bottom: 60,
              left: -30,
              child: _Glow(size: 240, color: accentSoft, isDark: isDark),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      (isDark ? Colors.black : Colors.white).withValues(alpha: isDark ? 0.10 : 0.05),
                      Colors.transparent,
                      (isDark ? Colors.black : Colors.white).withValues(alpha: isDark ? 0.32 : 0.20),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                offset: Offset(0, _dragOffset / 900),
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  scale: 1 - dismissProgress * 0.05,
                  child: Opacity(
                    opacity: 1 - dismissProgress * 0.18,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                      child: Column(
                        children: [
                          _TopBar(
                            label: song.format?.toUpperCase() ?? 'NOW PLAYING',
                          ),
                          const SizedBox(height: 12),
                          _CoverStage(
                            title: song.title,
                            coverUrl: song.coverUrl,
                          ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.04),
                          const SizedBox(height: 26),
                          _TrackMeta(
                            title: song.title,
                            artist: song.artist,
                            album: song.album,
                            isFavorite: state.isFavorite,
                            accent: accent,
                            onFavoriteToggle: () => ref.read(playerProvider.notifier).toggleFavorite(),
                          ),
                          const SizedBox(height: 22),
                          _ProgressCluster(
                            position: state.position,
                            duration: state.duration,
                            onChanged: (value) => ref.read(playerProvider.notifier).seek(value),
                          ),
                          const SizedBox(height: 24),
                          _ControlRow(
                            accent: accent,
                            playMode: state.playMode,
                            isPlaying: state.isPlaying,
                            onCycleMode: () => ref.read(playerProvider.notifier).cyclePlayMode(),
                            onPrevious: () => ref.read(playerProvider.notifier).previous(),
                            onTogglePlay: () => ref.read(playerProvider.notifier).togglePlay(),
                            onNext: () => ref.read(playerProvider.notifier).next(),
                            onQueue: () => showQueuePanel(context),
                          ),
                          const SizedBox(height: 24),
                          YYPanel(
                            padding: const EdgeInsets.all(18),
                            color: context.yyBgElevated.withValues(alpha: 0.78),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '播放面板',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    YYPillButton(
                                      label: '歌词',
                                      icon: CupertinoIcons.quote_bubble,
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const LyricsPage(),
                                        ),
                                      ),
                                    ),
                                    YYPillButton(
                                      label: '均衡器',
                                      icon: CupertinoIcons.slider_horizontal_3,
                                      onTap: () => context.push('/equalizer'),
                                    ),
                                    YYPillButton(
                                      label: '队列',
                                      icon: CupertinoIcons.list_bullet,
                                      onTap: () => showQueuePanel(context),
                                    ),
                                    YYPillButton(
                                      label: '自动刮削',
                                      icon: CupertinoIcons.sparkles,
                                      onTap: () => AutoScrapeDialog.show(
                                        context,
                                        song,
                                      ),
                                    ),
                                    YYPillButton(
                                      label: '手动刮削',
                                      icon: CupertinoIcons.search,
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ManualMusicScraperPage(
                                            music: song,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                Row(
                                  children: [
                                    Icon(
                                      CupertinoIcons.volume_down,
                                      color: context.yyTextTertiary,
                                      size: 16,
                                    ),
                                    Expanded(
                                      child: Slider(
                                        value: state.volume,
                                        min: 0,
                                        max: 1,
                                        onChanged: (value) {
                                          ref.read(playerProvider.notifier).setVolume(value);
                                        },
                                      ),
                                    ),
                                    Icon(
                                      CupertinoIcons.volume_up,
                                      color: context.yyTextTertiary,
                                      size: 16,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    YYTag(
                                      text: song.album,
                                      color: accentSoft,
                                    ),
                                    if ((song.format ?? '').isNotEmpty)
                                      YYTag(
                                        text: song.format!.toUpperCase(),
                                        color: accent,
                                      ),
                                    if (song.bitrateText.isNotEmpty)
                                      YYTag(
                                        text: song.bitrateText,
                                        color: YYColors.accentSecondary,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (nextSong != null) ...[
                            const SizedBox(height: 18),
                            YYSectionTitle(
                              title: '接下来播放',
                              subtitle: '无需展开队列也能知道下一首',
                            ),
                            YYTrackRow(
                              song: nextSong,
                              onTap: () => showQueuePanel(context),
                              subtitle: '${nextSong.artist} · ${nextSong.album}',
                              trailing: Icon(
                                CupertinoIcons.list_bullet,
                                color: context.yyTextTertiary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final double size;
  final Color color;
  final bool isDark;

  const _Glow({
    required this.size,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: isDark ? 0.26 : 0.14),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String label;

  const _TopBar({required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => context.pop(),
          child: Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: context.yyTextTertiary.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(YYRadius.full),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            YYTag(text: label, color: YYColors.accentSecondary),
            const Spacer(),
            Text(
              '上滑队列 · 下滑收起',
              style: TextStyle(
                color: context.yyTextTertiary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CoverStage extends StatelessWidget {
  final String title;
  final String? coverUrl;

  const _CoverStage({
    required this.title,
    required this.coverUrl,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width - 72;
    final isDark = context.isDark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            (isDark ? Colors.white : Colors.black).withValues(alpha: isDark ? 0.06 : 0.03),
            (isDark ? Colors.white : Colors.black).withValues(alpha: isDark ? 0.01 : 0.005),
          ],
        ),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: isDark ? 0.08 : 0.05),
        ),
      ),
      child: Hero(
        tag: 'mini-player-cover',
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(YYRadius.coverLarge),
            boxShadow: YYShadows.coverFloat,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(YYRadius.coverLarge),
            child: GradientCover(
              seed: title,
              coverUrl: coverUrl,
              size: size,
              borderRadius: YYRadius.coverLarge,
            ),
          ),
        ),
      ),
    );
  }
}

class _TrackMeta extends StatelessWidget {
  final String title;
  final String artist;
  final String album;
  final bool isFavorite;
  final Color accent;
  final VoidCallback onFavoriteToggle;

  const _TrackMeta({
    required this.title,
    required this.artist,
    required this.album,
    required this.isFavorite,
    required this.accent,
    required this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                artist,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: context.yyTextSecondary,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                album,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: onFavoriteToggle,
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: isDark ? 0.06 : 0.04),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: isDark ? 0.08 : 0.05),
              ),
            ),
            child: Icon(
              isFavorite ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
              color: isFavorite ? YYColors.heartRed : context.yyTextPrimary,
              size: 24,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressCluster extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onChanged;

  const _ProgressCluster({
    required this.position,
    required this.duration,
    required this.onChanged,
  });

  String _format(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = duration.inMilliseconds;
    final current = totalMs == 0
        ? 0.0
        : position.inMilliseconds / totalMs;

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(
            value: current.clamp(0, 1),
            onChanged: totalMs == 0
                ? null
                : (value) {
                    onChanged(
                      Duration(milliseconds: (totalMs * value).round()),
                    );
                  },
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _format(position),
              style: TextStyle(
                color: context.yyTextTertiary,
                fontSize: 12,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              _format(duration),
              style: TextStyle(
                color: context.yyTextTertiary,
                fontSize: 12,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ControlRow extends StatelessWidget {
  final Color accent;
  final PlayMode playMode;
  final bool isPlaying;
  final VoidCallback onCycleMode;
  final VoidCallback onPrevious;
  final VoidCallback onTogglePlay;
  final VoidCallback onNext;
  final VoidCallback onQueue;

  const _ControlRow({
    required this.accent,
    required this.playMode,
    required this.isPlaying,
    required this.onCycleMode,
    required this.onPrevious,
    required this.onTogglePlay,
    required this.onNext,
    required this.onQueue,
  });

  IconData get _modeIcon {
    switch (playMode) {
      case PlayMode.loop:
        return CupertinoIcons.repeat;
      case PlayMode.single:
        return CupertinoIcons.repeat_1;
      case PlayMode.shuffle:
        return CupertinoIcons.shuffle;
    }
  }

  String get _modeLabel {
    switch (playMode) {
      case PlayMode.loop:
        return '列表循环';
      case PlayMode.single:
        return '单曲循环';
      case PlayMode.shuffle:
        return '随机';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Row(
      children: [
        GestureDetector(
          onTap: onCycleMode,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: isDark ? 0.06 : 0.04),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Icon(_modeIcon, color: accent, size: 22),
                const SizedBox(height: 6),
                Text(
                  _modeLabel,
                  style: TextStyle(
                    color: context.yyTextTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _RoundControl(
                icon: CupertinoIcons.backward_fill,
                size: 54,
                onTap: onPrevious,
              ),
              _RoundControl(
                icon: isPlaying
                    ? CupertinoIcons.pause_fill
                    : CupertinoIcons.play_fill,
                size: 84,
                primary: true,
                onTap: onTogglePlay,
              ),
              _RoundControl(
                icon: CupertinoIcons.forward_fill,
                size: 54,
                onTap: onNext,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: onQueue,
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: isDark ? 0.06 : 0.04),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              CupertinoIcons.list_bullet_below_rectangle,
              color: context.yyTextPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _RoundControl extends StatelessWidget {
  final IconData icon;
  final double size;
  final bool primary;
  final VoidCallback onTap;

  const _RoundControl({
    required this.icon,
    required this.size,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: primary ? YYColors.accentGradient : null,
          color: primary ? null : (isDark ? Colors.white : Colors.black).withValues(alpha: isDark ? 0.06 : 0.04),
          shape: BoxShape.circle,
          boxShadow: primary ? YYShadows.accentGlow(YYColors.accentPrimary) : null,
        ),
        child: Icon(
          icon,
          color: primary ? Colors.white : context.yyTextPrimary,
          size: primary ? 30 : 22,
        ),
      ),
    );
  }
}
