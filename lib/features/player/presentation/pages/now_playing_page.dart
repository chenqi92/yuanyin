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
  double _horizontalDrag = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerProvider);
    final song = state.currentSong;

    if (song == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text('暂无播放', style: TextStyle(color: context.yyTextSecondary))),
      );
    }

    final accent = YYSeedPalette.primary(song.title);
    final dismissProgress = (_dragOffset / 300).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (details) {
          if (details.delta.dy > 0 || _dragOffset > 0) {
            setState(() => _dragOffset = (_dragOffset + details.delta.dy).clamp(0, 500));
          }
        },
        onVerticalDragEnd: (details) {
          if (_dragOffset > 180 || (details.primaryVelocity ?? 0) > 1000) {
            context.pop();
            return;
          }
          setState(() => _dragOffset = 0);
        },
        onHorizontalDragUpdate: (details) {
          setState(() => _horizontalDrag += details.delta.dx);
        },
        onHorizontalDragEnd: (details) {
          if (_horizontalDrag.abs() > 80) {
            if (_horizontalDrag > 0) {
              HapticFeedback.mediumImpact();
              ref.read(playerProvider.notifier).previous();
            } else {
              HapticFeedback.mediumImpact();
              ref.read(playerProvider.notifier).next();
            }
          }
          setState(() => _horizontalDrag = 0);
        },
        child: Stack(
          children: [
            // 1. 动态自适应流体背景
            Positioned.fill(
              child: YYScenicBackground(
                accent: accent,
                child: const SizedBox.expand(),
              ),
            ),
            
            // 2. 封面 Aura
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: 1000.ms,
                child: Container(
                  key: ValueKey('aura-${song.id}'),
                  decoration: BoxDecoration(
                    image: song.coverUrl != null 
                      ? DecorationImage(image: NetworkImage(song.coverUrl!), fit: BoxFit.cover, opacity: 0.12)
                      : null,
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 140, sigmaY: 140),
                    child: Container(color: Colors.black.withValues(alpha: 0.3)),
                  ),
                ),
              ),
            ),
            
            // 3. 内容
            SafeArea(
              child: AnimatedSlide(
                duration: 200.ms,
                curve: Curves.easeOutQuart,
                offset: Offset(_horizontalDrag / 1200, _dragOffset / 1200),
                child: AnimatedScale(
                  duration: 200.ms,
                  curve: Curves.easeOutQuart,
                  scale: 1 - dismissProgress * 0.15,
                  child: Opacity(
                    opacity: 1 - dismissProgress * 0.4,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
                      child: Column(
                        children: [
                          _TopBar(label: song.format?.toUpperCase() ?? 'LOSSLESS'),
                          const SizedBox(height: 36),
                          _CoverStage(
                            songId: song.id,
                            title: song.title,
                            coverUrl: song.coverUrl,
                            isPlaying: state.isPlaying,
                            dragOffset: _dragOffset,
                          ),
                          const SizedBox(height: 48),
                          _TrackMeta(
                            title: song.title,
                            artist: song.artist,
                            isFavorite: state.isFavorite,
                            onFavoriteToggle: () {
                              HapticFeedback.mediumImpact();
                              ref.read(playerProvider.notifier).toggleFavorite();
                            },
                          ),
                          const SizedBox(height: 36),
                          _ProgressCluster(
                            position: state.position,
                            duration: state.duration,
                            accent: accent,
                            onChanged: (v) => ref.read(playerProvider.notifier).seek(v),
                          ),
                          const SizedBox(height: 36),
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
                          const SizedBox(height: 44),
                          
                          // Expanded Controls
                          YYPanel(
                            thick: true,
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _ActionChip(
                                      label: '歌词',
                                      icon: CupertinoIcons.quote_bubble_fill,
                                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LyricsPage())),
                                    ),
                                    _ActionChip(
                                      label: '均衡器',
                                      icon: CupertinoIcons.slider_horizontal_3,
                                      onTap: () => context.push('/equalizer'),
                                    ),
                                    _ActionChip(
                                      label: '工具',
                                      icon: CupertinoIcons.wrench_fill,
                                      onTap: () => showAutoScrapeDialog(context, song),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 32),
                                _VolumeControl(
                                  value: state.volume,
                                  onChanged: (v) => ref.read(playerProvider.notifier).setVolume(v),
                                ),
                                const SizedBox(height: 24),
                                _MetaDataRow(song: song),
                              ],
                            ),
                          ),
                          const SizedBox(height: 120),
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
        Container(width: 42, height: 5, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(10))),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              borderRadius: BorderRadius.circular(8),
              child: Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
            ),
            Text('正在播放', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontWeight: FontWeight.w800, fontSize: 13)),
            const Icon(CupertinoIcons.ellipsis_circle_fill, color: Colors.white24, size: 26),
          ],
        ),
      ],
    );
  }
}

class _CoverStage extends StatelessWidget {
  final String songId;
  final String title;
  final String? coverUrl;
  final bool isPlaying;
  final double dragOffset;

  const _CoverStage({required this.songId, required this.title, this.coverUrl, required this.isPlaying, required this.dragOffset});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width * 0.86;
    
    return Hero(
      tag: 'track-cover-$songId',
      child: AnimatedContainer(
        duration: 800.ms,
        curve: Curves.elasticOut,
        padding: EdgeInsets.all(isPlaying ? 0 : 24),
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(YYRadius.coverLarge),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.7), blurRadius: 50, offset: Offset(0, 25 + dragOffset * 0.1)),
            ],
            border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 0.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(YYRadius.coverLarge),
            child: GradientCover(seed: title, coverUrl: coverUrl, size: size, borderRadius: YYRadius.coverLarge),
          ),
        ),
      ),
    );
  }
}

class _TrackMeta extends StatelessWidget {
  final String title, artist;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  const _TrackMeta({required this.title, required this.artist, required this.isFavorite, required this.onFavoriteToggle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1.5)),
              const SizedBox(height: 8),
              Text(artist, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.45))),
            ],
          ),
        ),
        IconButton(
          onPressed: onFavoriteToggle,
          icon: Icon(isFavorite ? CupertinoIcons.heart_fill : CupertinoIcons.heart, color: isFavorite ? YYColors.heartRed : Colors.white24, size: 34),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms, delay: 300.ms).slideY(begin: 0.15);
  }
}

class _ProgressCluster extends StatelessWidget {
  final Duration position, duration;
  final Color accent;
  final ValueChanged<Duration> onChanged;

  const _ProgressCluster({required this.position, required this.duration, required this.accent, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final current = duration.inMilliseconds == 0 ? 0.0 : position.inMilliseconds / duration.inMilliseconds;

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 5,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7, pressedElevation: 15),
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
            thumbColor: Colors.white,
          ),
          child: Slider(value: current.clamp(0, 1), onChanged: (v) => onChanged(Duration(milliseconds: (duration.inMilliseconds * v).round()))),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_format(position), style: _timeStyle),
              Text(_format(duration), style: _timeStyle),
            ],
          ),
        ),
      ],
    );
  }

  String _format(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  TextStyle get _timeStyle => const TextStyle(color: Colors.white30, fontSize: 13, fontWeight: FontWeight.w900, fontFeatures: [FontFeature.tabularFigures()]);
}

class _ControlRow extends StatelessWidget {
  final Color accent;
  final PlayMode playMode;
  final bool isPlaying;
  final VoidCallback onCycleMode, onPrevious, onTogglePlay, onNext, onQueue;

  const _ControlRow({required this.accent, required this.playMode, required this.isPlaying, required this.onCycleMode, required this.onPrevious, required this.onTogglePlay, required this.onNext, required this.onQueue});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(onPressed: onCycleMode, icon: Icon(_modeIcon, color: Colors.white24, size: 26)),
        Row(
          children: [
            IconButton(onPressed: onPrevious, icon: const Icon(CupertinoIcons.backward_fill, color: Colors.white, size: 44)),
            const SizedBox(width: 36),
            GestureDetector(
              onTap: onTogglePlay,
              child: Container(
                width: 84, height: 84,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Icon(isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill, color: Colors.black, size: 44),
              ),
            ),
            const SizedBox(width: 36),
            IconButton(onPressed: onNext, icon: const Icon(CupertinoIcons.forward_fill, color: Colors.white, size: 44)),
          ],
        ),
        IconButton(onPressed: onQueue, icon: const Icon(CupertinoIcons.list_bullet, color: Colors.white24, size: 26)),
      ],
    );
  }

  IconData get _modeIcon => playMode == PlayMode.shuffle ? CupertinoIcons.shuffle : (playMode == PlayMode.single ? CupertinoIcons.repeat_1 : CupertinoIcons.repeat);
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
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 24),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
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
        const Icon(CupertinoIcons.volume_down, color: Colors.white24, size: 18),
        Expanded(child: Slider(value: value, onChanged: onChanged, activeColor: Colors.white38, inactiveColor: Colors.white10)),
        const Icon(CupertinoIcons.volume_up, color: Colors.white24, size: 18),
      ],
    );
  }
}

class _MetaDataRow extends StatelessWidget {
  final dynamic song;
  const _MetaDataRow({required this.song});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _Tag(text: song.album),
          const SizedBox(width: 10),
          if (song.format != null) _Tag(text: song.format!.toUpperCase()),
          const SizedBox(width: 10),
          if (song.bitrateText.isNotEmpty) _Tag(text: song.bitrateText),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag({required this.text});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(6)),
    child: Text(text, style: const TextStyle(color: Colors.white30, fontSize: 11, fontWeight: FontWeight.w800)),
  );
}

extension on BuildContext {
  TextTheme get yyTextTheme => Theme.of(this).textTheme;
}
