import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/theme.dart';
import '../../../../shared/widgets/glass_widgets.dart';
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
    final dismissProgress = yyClamp(_dragOffset / 240, 0, 1);
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor: Colors.black, // Dark background for the blur to pop
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (details) {
          if (details.delta.dy > 0) {
            setState(() => _dragOffset = (_dragOffset + details.delta.dy).clamp(0, 320));
          }
        },
        onVerticalDragEnd: (details) {
          if (_dragOffset > 140 || (details.primaryVelocity ?? 0) > 1000) {
            context.pop();
            return;
          }
          setState(() => _dragOffset = 0);
        },
        child: Stack(
          children: [
            // Dynamic Blurred Background
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                child: Hero(
                  tag: 'playing-bg-${song.title}',
                  child: Container(
                    key: ValueKey(song.title),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      image: song.coverUrl != null 
                        ? DecorationImage(
                            image: NetworkImage(song.coverUrl!),
                            fit: BoxFit.cover,
                            opacity: 0.4,
                          )
                        : null,
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: YYBlur.playerBg, sigmaY: YYBlur.playerBg),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.4),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            // Content
            SafeArea(
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutQuart,
                offset: Offset(0, _dragOffset / 900),
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutQuart,
                  scale: 1 - dismissProgress * 0.05,
                  child: Opacity(
                    opacity: 1 - dismissProgress * 0.2,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: Column(
                        children: [
                          _TopBar(
                            label: song.format?.toUpperCase() ?? 'LOSSLESS',
                          ),
                          const SizedBox(height: 24),
                          _CoverStage(
                            title: song.title,
                            coverUrl: song.coverUrl,
                            isPlaying: state.isPlaying,
                          ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95)),
                          const SizedBox(height: 36),
                          _TrackMeta(
                            title: song.title,
                            artist: song.artist,
                            isFavorite: state.isFavorite,
                            onFavoriteToggle: () {
                              HapticFeedback.mediumImpact();
                              ref.read(playerProvider.notifier).toggleFavorite();
                            },
                          ),
                          const SizedBox(height: 28),
                          _ProgressCluster(
                            position: state.position,
                            duration: state.duration,
                            accent: accent,
                            onChanged: (value) => ref.read(playerProvider.notifier).seek(value),
                          ),
                          const SizedBox(height: 32),
                          _ControlRow(
                            accent: accent,
                            playMode: state.playMode,
                            isPlaying: state.isPlaying,
                            onCycleMode: () {
                              HapticFeedback.selectionClick();
                              ref.read(playerProvider.notifier).cyclePlayMode();
                            },
                            onPrevious: () {
                              HapticFeedback.lightImpact();
                              ref.read(playerProvider.notifier).previous();
                            },
                            onTogglePlay: () {
                              HapticFeedback.mediumImpact();
                              ref.read(playerProvider.notifier).togglePlay();
                            },
                            onNext: () {
                              HapticFeedback.lightImpact();
                              ref.read(playerProvider.notifier).next();
                            },
                            onQueue: () {
                              HapticFeedback.lightImpact();
                              showQueuePanel(context);
                            },
                          ),
                          const SizedBox(height: 36),
                          
                          // Expanded Glass Panel for extra controls
                          GlassPanel(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(CupertinoIcons.waveform, color: YYColors.accentPrimary, size: 18),
                                    const SizedBox(width: 8),
                                    Text('音频引擎与工具', style: context.yyTextTheme.titleLarge),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    _ActionChip(
                                      label: '歌词',
                                      icon: CupertinoIcons.quote_bubble,
                                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LyricsPage())),
                                    ),
                                    _ActionChip(
                                      label: '均衡器',
                                      icon: CupertinoIcons.slider_horizontal_3,
                                      onTap: () => context.push('/equalizer'),
                                    ),
                                    _ActionChip(
                                      label: '自动刮削',
                                      icon: CupertinoIcons.wand_and_stars,
                                      onTap: () => showAutoScrapeDialog(context, song),
                                    ),
                                    _ActionChip(
                                      label: '修改信息',
                                      icon: CupertinoIcons.pencil_circle,
                                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ManualMusicScraperPage(musicItem: song))),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                _VolumeControl(
                                  value: state.volume,
                                  onChanged: (v) => ref.read(playerProvider.notifier).setVolume(v),
                                ),
                                const SizedBox(height: 24),
                                _MetaDataRow(song: song),
                              ],
                            ),
                          ),
                          const SizedBox(height: 40),
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

class _TopBar extends StatelessWidget {
  final String label;

  const _TopBar({required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 5,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(YYRadius.full),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 0.5),
              ),
              child: Text(
                label,
                style: context.yyTextTheme.labelSmall?.copyWith(color: Colors.white, fontSize: 10),
              ),
            ),
            Text(
              '正在从 NAS 播放',
              style: context.yyTextTheme.labelMedium?.copyWith(color: Colors.white.withValues(alpha: 0.5)),
            ),
            const Icon(CupertinoIcons.ellipsis_circle, color: Colors.white, size: 20),
          ],
        ),
      ],
    );
  }
}

class _CoverStage extends StatelessWidget {
  final String title;
  final String? coverUrl;
  final bool isPlaying;

  const _CoverStage({
    required this.title,
    required this.coverUrl,
    required this.isPlaying,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width * 0.82;
    
    return AnimatedScale(
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      scale: isPlaying ? 1.0 : 0.9,
      child: Hero(
        tag: 'mini-player-cover',
        child: Container(
          width: size,
          height: size,
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
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  const _TrackMeta({
    required this.title,
    required this.artist,
    required this.isFavorite,
    required this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
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
                style: context.yyTextTheme.headlineLarge?.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                artist,
                style: context.yyTextTheme.titleLarge?.copyWith(
                  color: context.yyTextSecondary,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        IconButton(
          onPressed: onFavoriteToggle,
          icon: Icon(
            isFavorite ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
            color: isFavorite ? YYColors.heartRed : Colors.white,
            size: 28,
          ),
        ),
      ],
    );
  }
}

class _ProgressCluster extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final Color accent;
  final ValueChanged<Duration> onChanged;

  const _ProgressCluster({
    required this.position,
    required this.duration,
    required this.accent,
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
    final current = totalMs == 0 ? 0.0 : position.inMilliseconds / totalMs;

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4, pressedElevation: 8),
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
            thumbColor: Colors.white,
            overlayColor: Colors.white.withValues(alpha: 0.1),
          ),
          child: Slider(
            value: current.clamp(0, 1),
            onChanged: totalMs == 0 ? null : (value) {
              onChanged(Duration(milliseconds: (totalMs * value).round()));
            },
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_format(position), style: _timeStyle(context)),
            Text(_format(duration), style: _timeStyle(context)),
          ],
        ),
      ],
    );
  }

  TextStyle _timeStyle(BuildContext context) => TextStyle(
    color: Colors.white.withValues(alpha: 0.4),
    fontSize: 12,
    fontWeight: FontWeight.w600,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
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

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: onCycleMode,
          icon: Icon(_modeIcon, color: Colors.white.withValues(alpha: 0.6), size: 22),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: onPrevious,
              icon: const Icon(CupertinoIcons.backward_fill, color: Colors.white, size: 36),
            ),
            const SizedBox(width: 24),
            GestureDetector(
              onTap: onTogglePlay,
              child: Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                  color: Colors.black,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(width: 24),
            IconButton(
              onPressed: onNext,
              icon: const Icon(CupertinoIcons.forward_fill, color: Colors.white, size: 36),
            ),
          ],
        ),
        IconButton(
          onPressed: onQueue,
          icon: const Icon(CupertinoIcons.list_bullet, color: Colors.white.withValues(alpha: 0.6), size: 22),
        ),
      ],
    );
  }

  IconData get _modeIcon {
    switch (playMode) {
      case PlayMode.loop: return CupertinoIcons.repeat;
      case PlayMode.single: return CupertinoIcons.repeat_1;
      case PlayMode.shuffle: return CupertinoIcons.shuffle;
    }
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionChip({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(YYRadius.full),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _VolumeControl extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _VolumeControl({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(CupertinoIcons.volume_down, color: Colors.white.withValues(alpha: 0.4), size: 16),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              activeTrackColor: Colors.white.withValues(alpha: 0.6),
              inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
            ),
            child: Slider(value: value, onChanged: onChanged),
          ),
        ),
        Icon(CupertinoIcons.volume_up, color: Colors.white.withValues(alpha: 0.4), size: 16),
      ],
    );
  }
}

class _MetaDataRow extends StatelessWidget {
  final dynamic song;

  const _MetaDataRow({required this.song});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Tag(text: song.album),
        if (song.format != null) _Tag(text: song.format!.toUpperCase()),
        if (song.bitrateText.isNotEmpty) _Tag(text: song.bitrateText),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

extension on BuildContext {
  TextTheme get yyTextTheme => Theme.of(this).textTheme;
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
