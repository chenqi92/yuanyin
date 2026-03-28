import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/theme.dart';
import '../../domain/entities/music_item.dart';
import '../../../../shared/widgets/gradient_cover.dart';
import '../../../../shared/services/shell_navigation_visibility.dart';
import '../../../../shared/widgets/modern_music_ui.dart';
import '../../../../shared/utils/cover_art_resolver.dart';
import '../../../lyric/presentation/pages/lyrics_page.dart';
import '../../../library/presentation/providers/library_provider.dart';
import '../../../library/presentation/widgets/auto_scrape_dialog.dart';
import '../providers/player_provider.dart';
import '../widgets/queue_panel.dart';

class NowPlayingPage extends ConsumerStatefulWidget {
  const NowPlayingPage({super.key});

  @override
  ConsumerState<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends ConsumerState<NowPlayingPage>
    with ConsumerShellNavigationVisibilityMixin {
  @override
  void initState() {
    super.initState();
    hideShellNavigation();
  }

  double _dragOffset = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerProvider);
    final song = state.currentSong;

    if (song == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(
                  children: [
                    _CircleIconButton(
                      icon: CupertinoIcons.chevron_down,
                      onTap: () {
                        if (Navigator.of(context).canPop()) {
                          context.pop();
                        } else {
                          context.go('/');
                        }
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '暂无播放',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final accent = YYSeedPalette.primary('${song.title}_${song.artist}');
    final dismissProgress = yyClamp(_dragOffset / 240, 0, 1);
    final screenWidth = MediaQuery.of(context).size.width;
    final coverSize = (screenWidth - 72).clamp(260.0, 420.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onVerticalDragUpdate: (details) {
          if (details.delta.dy > 0) {
            setState(() {
              _dragOffset = (_dragOffset + details.delta.dy).clamp(0.0, 320.0);
            });
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
            _NowPlayingBackdrop(song: song, accent: accent),
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
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: Column(
                        children: [
                          const _DragHandle(),
                          const SizedBox(height: 14),
                          _TopBar(
                            sourceLabel: _sourceLabel(song.sourceId),
                            onClose: () => context.pop(),
                          ),
                          const Spacer(),
                          Hero(
                            tag: 'mini-player-cover',
                            child: _CoverArt(
                              song: song,
                              accent: accent,
                              size: coverSize,
                            ),
                          ),
                          const SizedBox(height: 26),
                          _InfoBlock(
                            song: song,
                            isFavorite: state.isFavorite,
                            onFavorite: () => ref
                                .read(playerProvider.notifier)
                                .toggleFavorite(),
                          ),
                          const SizedBox(height: 18),
                          _ProgressSection(
                            position: state.position,
                            duration: state.duration,
                            accent: accent,
                            onChanged: (value) =>
                                ref.read(playerProvider.notifier).seek(value),
                          ),
                          const SizedBox(height: 18),
                          _ControlRow(
                            playMode: state.playMode,
                            isPlaying: state.isPlaying,
                            onShuffle: () => ref
                                .read(playerProvider.notifier)
                                .cyclePlayMode(),
                            onPrevious: () =>
                                ref.read(playerProvider.notifier).previous(),
                            onTogglePlay: () =>
                                ref.read(playerProvider.notifier).togglePlay(),
                            onNext: () =>
                                ref.read(playerProvider.notifier).next(),
                            onRepeat: () => ref
                                .read(playerProvider.notifier)
                                .cyclePlayMode(),
                          ),
                          const SizedBox(height: 18),
                          _UtilityTray(
                            volume: state.volume,
                            queueCount: state.queue.length,
                            onLyrics: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LyricsPage(),
                              ),
                            ),
                            onQueue: () => showQueuePanel(context),
                            onScrape: () async {
                              final changed = await AutoScrapeDialog.show(
                                context,
                                song,
                              );
                              if (changed == true && mounted) {
                                await ref
                                    .read(libraryProvider.notifier)
                                    .refresh();
                                await ref
                                    .read(playerProvider.notifier)
                                    .refreshCurrentSong();
                              }
                            },
                            onVolumeChanged: (value) => ref
                                .read(playerProvider.notifier)
                                .setVolume(value),
                          ),
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

  String _sourceLabel(String? sourceId) {
    if (sourceId == null || sourceId.isEmpty) return '本地音乐库';
    if (sourceId.length <= 12) return sourceId.toUpperCase();
    return '已连接数据源';
  }
}

class _NowPlayingBackdrop extends StatelessWidget {
  final MusicItem song;
  final Color accent;

  const _NowPlayingBackdrop({required this.song, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  yyMix(YYColors.bgBase, accent, 0.34),
                  yyMix(YYColors.bgBase, accent, 0.18),
                  YYColors.bgBase,
                  yyMix(YYColors.bgBase, YYColors.accentSecondary, 0.1),
                ],
              ),
            ),
          ),
        ),
        if (yyResolveCoverCandidates(
          coverUrl: song.coverUrl,
          filePath: song.filePath,
        ).isNotEmpty)
          Positioned.fill(
            child: _BackdropImage(
              coverUrl: song.coverUrl,
              filePath: song.filePath,
            ),
          ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 72, sigmaY: 72),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.24),
                    Colors.black.withValues(alpha: 0.44),
                    Colors.black.withValues(alpha: 0.62),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: -120,
          right: -40,
          child: _GlowOrb(color: accent.withValues(alpha: 0.26), size: 260),
        ),
        Positioned(
          bottom: -100,
          left: -50,
          child: _GlowOrb(
            color: YYColors.accentSecondary.withValues(alpha: 0.14),
            size: 240,
          ),
        ),
      ],
    );
  }
}

class _BackdropImage extends StatelessWidget {
  final String? coverUrl;
  final String? filePath;

  const _BackdropImage({this.coverUrl, this.filePath});

  @override
  Widget build(BuildContext context) {
    final provider = yyBuildCoverImageProvider(coverUrl, filePath: filePath);
    if (provider == null) {
      return const SizedBox.shrink();
    }

    return Image(
      image: provider,
      fit: BoxFit.cover,
      errorBuilder: (_, error, stackTrace) => const SizedBox.shrink(),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;

  const _GlowOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 42, sigmaY: 42),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color,
                color.withValues(alpha: 0.04),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 52,
        height: 5,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(YYRadius.full),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String sourceLabel;
  final VoidCallback onClose;

  const _TopBar({required this.sourceLabel, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(YYRadius.full),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.waveform_path_badge_plus,
                color: Colors.white,
                size: 14,
              ),
              const SizedBox(width: 8),
              Text(
                sourceLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        _CircleIconButton(icon: CupertinoIcons.chevron_down, onTap: onClose),
      ],
    );
  }
}

class _CoverArt extends StatelessWidget {
  final MusicItem song;
  final Color accent;
  final double size;

  const _CoverArt({
    required this.song,
    required this.accent,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.18),
            blurRadius: 44,
            spreadRadius: -6,
            offset: const Offset(0, 22),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 50,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: SizedBox(
          width: size,
          height: size,
          child: GradientCover(
            seed: '${song.title}_${song.artist}',
            coverUrl: song.coverUrl,
            filePath: song.filePath,
            size: size,
            borderRadius: 34,
          ),
        ),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  final MusicItem song;
  final bool isFavorite;
  final VoidCallback onFavorite;

  const _InfoBlock({
    required this.song,
    required this.isFavorite,
    required this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (song.format != null) _InfoChip(label: song.format!.toUpperCase()),
      if (song.bitrateText.isNotEmpty) _InfoChip(label: song.bitrateText),
      if (song.sampleRate != null)
        _InfoChip(label: '${(song.sampleRate! / 1000).toStringAsFixed(1)} kHz'),
      if (song.year != null) _InfoChip(label: '${song.year}'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    song.album,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.52),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _CircleIconButton(
              icon: isFavorite
                  ? CupertinoIcons.heart_fill
                  : CupertinoIcons.heart,
              color: isFavorite ? YYColors.heartRed : Colors.white,
              onTap: onFavorite,
            ),
          ],
        ),
        if (chips.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: chips),
        ],
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;

  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(YYRadius.full),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.84),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _ProgressSection extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final Color accent;
  final ValueChanged<Duration> onChanged;

  const _ProgressSection({
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
    final remaining = duration - position;

    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            activeTrackColor: accent,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.16),
            thumbColor: Colors.white,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: current.clamp(0.0, 1.0),
            onChanged: totalMs == 0
                ? null
                : (value) {
                    onChanged(
                      Duration(milliseconds: (totalMs * value).round()),
                    );
                  },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _format(position),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.54),
                  fontSize: 12,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                '-${_format(remaining.isNegative ? Duration.zero : remaining)}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.54),
                  fontSize: 12,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ControlRow extends StatelessWidget {
  final PlayMode playMode;
  final bool isPlaying;
  final VoidCallback onShuffle;
  final VoidCallback onPrevious;
  final VoidCallback onTogglePlay;
  final VoidCallback onNext;
  final VoidCallback onRepeat;

  const _ControlRow({
    required this.playMode,
    required this.isPlaying,
    required this.onShuffle,
    required this.onPrevious,
    required this.onTogglePlay,
    required this.onNext,
    required this.onRepeat,
  });

  @override
  Widget build(BuildContext context) {
    final isShuffleActive = playMode == PlayMode.shuffle;
    final isRepeatActive = playMode == PlayMode.single;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _CircleIconButton(
          icon: CupertinoIcons.shuffle,
          color: isShuffleActive ? YYColors.accentPrimary : Colors.white,
          onTap: onShuffle,
        ),
        _CircleIconButton(
          icon: CupertinoIcons.backward_fill,
          color: Colors.white,
          size: 24,
          diameter: 54,
          onTap: onPrevious,
        ),
        GestureDetector(
          onTap: onTogglePlay,
          child: Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              gradient: YYColors.accentGradient,
              shape: BoxShape.circle,
              boxShadow: YYShadows.accentGlow(YYColors.accentPrimary),
            ),
            child: Icon(
              isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
              color: Colors.white,
              size: 34,
            ),
          ),
        ),
        _CircleIconButton(
          icon: CupertinoIcons.forward_fill,
          color: Colors.white,
          size: 24,
          diameter: 54,
          onTap: onNext,
        ),
        _CircleIconButton(
          icon: playMode == PlayMode.single
              ? CupertinoIcons.repeat_1
              : CupertinoIcons.repeat,
          color: isRepeatActive ? YYColors.accentPrimary : Colors.white,
          onTap: onRepeat,
        ),
      ],
    );
  }
}

class _UtilityTray extends StatelessWidget {
  final double volume;
  final int queueCount;
  final VoidCallback onLyrics;
  final VoidCallback onQueue;
  final VoidCallback onScrape;
  final ValueChanged<double> onVolumeChanged;

  const _UtilityTray({
    required this.volume,
    required this.queueCount,
    required this.onLyrics,
    required this.onQueue,
    required this.onScrape,
    required this.onVolumeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: _TrayAction(
                icon: CupertinoIcons.quote_bubble_fill,
                label: '歌词',
                onTap: onLyrics,
              ),
            ),
            Expanded(
              child: _TrayAction(
                icon: CupertinoIcons.list_bullet,
                label: '队列',
                badge: queueCount > 0 ? '$queueCount' : null,
                onTap: onQueue,
              ),
            ),
            Expanded(
              child: _TrayAction(
                icon: CupertinoIcons.sparkles,
                label: '刮削',
                onTap: onScrape,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        YYLiquidGlass(
          thin: true,
          radius: 24,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          color: Colors.white.withValues(alpha: 0.05),
          child: Row(
            children: [
              Icon(
                CupertinoIcons.speaker_fill,
                color: Colors.white.withValues(alpha: 0.58),
                size: 14,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 5,
                    ),
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.14),
                    thumbColor: Colors.white,
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 12,
                    ),
                  ),
                  child: Slider(
                    value: volume,
                    min: 0,
                    max: 1,
                    onChanged: onVolumeChanged,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                CupertinoIcons.speaker_3_fill,
                color: Colors.white.withValues(alpha: 0.58),
                size: 16,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrayAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final VoidCallback onTap;

  const _TrayAction({
    required this.icon,
    required this.label,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(YYRadius.full),
      onPressed: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              YYLiquidGlass(
                thin: true,
                radius: YYRadius.full,
                padding: EdgeInsets.zero,
                color: Colors.white.withValues(alpha: 0.05),
                child: SizedBox(
                  width: 58,
                  height: 58,
                  child: Icon(icon, color: Colors.white, size: 19),
                ),
              ),
              if (badge != null)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: YYColors.accentPrimary,
                      borderRadius: BorderRadius.circular(YYRadius.full),
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double diameter;
  final double size;

  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.color = Colors.white,
    this.diameter = 46,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Icon(icon, color: color, size: size),
        ),
      ),
    );
  }
}
