import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/l10n/strings.dart';
import '../../../../app/theme/theme.dart';
import '../../../../shared/widgets/gradient_cover.dart';
import '../../../../shared/widgets/song_actions_sheet.dart';
import '../../../library/presentation/providers/library_provider.dart';
import '../../../library/data/services/music_database_service.dart';
import '../../../player/domain/entities/music_item.dart';
import '../../../player/presentation/providers/player_provider.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    final player = ref.watch(playerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            // ── 页头 ──
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_greeting(), style: TextStyle(
                    color: context.yyTextTertiary, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(S.of(context).appName, style: TextStyle(
                    color: context.yyTextPrimary, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                ])),
                if (library.allSongs.isNotEmpty) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: YYColors.accentPrimary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10)),
                  child: Text('${library.stats.songCount} 首', style: TextStyle(
                    color: YYColors.accentPrimary, fontSize: 13, fontWeight: FontWeight.w700))),
              ]),
            )),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── Hero 播放卡片 ──
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _HeroCard(player: player),
            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.03)),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── 音乐库统计条 ──
            if (library.allSongs.isNotEmpty)
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _StatsBar(stats: library.stats),
              )),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── 快捷访问 2x2 毛玻璃卡片 ──
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _QuickAccessGrid(
                stats: library.stats,
                recentCount: library.recentPlays.length,
                hasSongs: library.allSongs.isNotEmpty,
                onShuffle: () {
                  final songs = List<MusicItem>.from(library.allSongs)..shuffle();
                  if (songs.isNotEmpty) ref.read(playerProvider.notifier).playSong(songs.first, queue: songs);
                },
              ),
            )),

            // ── 最近播放 ──
            if (library.recentPlays.isNotEmpty) ...[
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 20, 0, 14),
                child: _SectionHeader('最近播放', onMore: () => context.push('/library?tab=recent')),
              )),
              SliverToBoxAdapter(child: SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: library.recentPlays.take(8).length,
                  itemBuilder: (_, i) {
                    final song = library.recentPlays[i];
                    return _RecentCard(song: song, queue: library.recentPlays)
                        .animate().fadeIn(delay: (50 * i).ms);
                  },
                ),
              )),
            ],

            // ── 为你推荐（随机 5 首）──
            if (library.allSongs.length >= 5) ...[
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 20, 0, 14),
                child: _SectionHeader('为你推荐', color: YYColors.accentSecondary,
                    onMore: () => context.push('/library?tab=songs')),
              )),
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _PopularList(songs: library.allSongs),
              )),
            ],

            // ── 浏览分类（横向胶囊）──
            if (library.allSongs.isNotEmpty) ...[
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 20, 0, 14),
                child: _SectionHeader('浏览音乐库'),
              )),
              SliverToBoxAdapter(child: SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _CategoryChip('全部歌曲', CupertinoIcons.music_note_list, library.stats.songCount, YYColors.accentPrimary,
                        () => context.push('/library?tab=songs')),
                    _CategoryChip('艺术家', CupertinoIcons.person_2_fill, library.stats.artistCount, const Color(0xFF9C27B0),
                        () => context.push('/library?tab=artists')),
                    _CategoryChip('专辑', CupertinoIcons.square_stack_3d_up_fill, library.stats.albumCount, const Color(0xFFFF9800),
                        () => context.push('/library?tab=albums')),
                    _CategoryChip('流派', CupertinoIcons.music_mic, library.genres.length, const Color(0xFFE91E63),
                        () => context.push('/library?tab=genres')),
                    _CategoryChip('均衡器', CupertinoIcons.slider_horizontal_3, null, const Color(0xFF00BCD4),
                        () => context.push('/equalizer')),
                  ],
                ),
              )),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 6) return '夜深了 🌙';
    if (h < 12) return '早上好 ☀️';
    if (h < 14) return '中午好 🌤';
    if (h < 18) return '下午好 ☕';
    return '晚上好 🌙';
  }
}

// ═══════════════════════════════════════════════════════════
//  色条分区标题 + 查看全部（参照 my-nas RecentTracksSection._buildHeader）
// ═══════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String text;
  final Color? color;
  final VoidCallback? onMore;
  const _SectionHeader(this.text, {this.color, this.onMore});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(children: [
        Container(width: 4, height: 20,
          decoration: BoxDecoration(color: color ?? YYColors.accentPrimary, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(
          color: context.yyTextPrimary, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3))),
        if (onMore != null) GestureDetector(
          onTap: onMore,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: context.isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('查看全部', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: YYColors.accentPrimary)),
              const SizedBox(width: 4),
              Icon(CupertinoIcons.chevron_right, size: 12, color: YYColors.accentPrimary),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  音乐库统计条（参照 my-nas MusicStatsCard）
// ═══════════════════════════════════════════════════════════

class _StatsBar extends StatelessWidget {
  final LibraryStats stats;
  const _StatsBar({required this.stats});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _StatItem(CupertinoIcons.music_note, stats.songCount, '歌曲', YYColors.accentPrimary),
        Container(width: 1, height: 50, color: context.isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08)),
        _StatItem(CupertinoIcons.person_2_fill, stats.artistCount, '艺术家', const Color(0xFF9C27B0)),
        Container(width: 1, height: 50, color: context.isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08)),
        _StatItem(CupertinoIcons.square_stack_3d_up_fill, stats.albumCount, '专辑', const Color(0xFFFF9800)),
      ]),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;
  final Color color;
  const _StatItem(this.icon, this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(width: 44, height: 44,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 22)),
      const SizedBox(height: 8),
      Text(_fmt(value), style: TextStyle(
        fontSize: 20, fontWeight: FontWeight.w800, color: context.yyTextPrimary)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 12, color: context.yyTextTertiary)),
    ]);
  }
  String _fmt(int n) {
    if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}万';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

// ═══════════════════════════════════════════════════════════
//  Hero 播放卡片
// ═══════════════════════════════════════════════════════════

class _HeroCard extends ConsumerWidget {
  final PlayerState player;
  const _HeroCard({required this.player});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (player.currentSong == null) return _welcome(context, ref);
    return _playing(context, ref);
  }

  Widget _welcome(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        final library = ref.read(libraryProvider);
        if (library.allSongs.isNotEmpty) {
          final songs = List<MusicItem>.from(library.allSongs)..shuffle();
          ref.read(playerProvider.notifier).playSong(songs.first, queue: songs);
        }
      },
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [YYColors.accentPrimary, YYColors.accentPrimary.withValues(alpha: 0.8), YYColors.accentSecondary]),
          boxShadow: [BoxShadow(color: YYColors.accentPrimary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))]),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(fit: StackFit.expand, children: [
            Positioned(right: -30, bottom: -30, child: Opacity(opacity: 0.12,
              child: Icon(CupertinoIcons.music_note_2, size: 140, color: Colors.white))),
            Positioned(left: -20, top: -20, child: Opacity(opacity: 0.08,
              child: Icon(CupertinoIcons.recordingtape, size: 100, color: Colors.white))),
            Padding(padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(CupertinoIcons.play_circle_fill, color: Colors.white, size: 36),
                const SizedBox(height: 12),
                const Text('开始探索你的音乐', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                const SizedBox(height: 4),
                Text('选择一首歌曲开始播放', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(CupertinoIcons.shuffle, color: YYColors.accentPrimary, size: 16),
                    const SizedBox(width: 6),
                    Text('随机播放', style: TextStyle(color: YYColors.accentPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                  ])),
              ])),
          ]),
        ),
      ),
    );
  }

  Widget _playing(BuildContext context, WidgetRef ref) {
    final song = player.currentSong!;
    final accent = YYSeedPalette.primary(song.title);

    return GestureDetector(
      onTap: () => context.push('/player'),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: accent.withValues(alpha: context.isDark ? 0.3 : 0.2), blurRadius: 20, offset: const Offset(0, 8))]),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(fit: StackFit.expand, children: [
            // 模糊背景
            if (song.coverUrl != null && song.coverUrl!.isNotEmpty)
              ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Transform.scale(scale: 1.3,
                  child: GradientCover(seed: '${song.title}_${song.artist}', coverUrl: song.coverUrl, size: 200, borderRadius: 0)))
            else
              Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [accent, accent.withValues(alpha: 0.7), YYColors.accentSecondary]))),
            // 暗层
            Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.black.withValues(alpha: 0.25), Colors.black.withValues(alpha: 0.55)]))),
            // 内容
            Padding(padding: const EdgeInsets.all(20), child: Column(children: [
              Expanded(child: Row(children: [
                // 封面
                Container(width: 90, height: 90,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6))]),
                  child: ClipRRect(borderRadius: BorderRadius.circular(14),
                    child: GradientCover(seed: '${song.title}_${song.artist}', coverUrl: song.coverUrl, size: 90, borderRadius: 14))),
                const SizedBox(width: 16),
                // 信息
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(10)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(
                        color: player.isPlaying ? const Color(0xFF4CAF50) : Colors.white60, shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      Text(player.isPlaying ? '正在播放' : '已暂停', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500)),
                    ])),
                  const SizedBox(height: 10),
                  Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                  const SizedBox(height: 2),
                  Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                ])),
              ])),
              const SizedBox(height: 12),
              // 进度条
              _ProgressBar(player: player),
              const SizedBox(height: 10),
              // 控制
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _CtrlBtn(CupertinoIcons.backward_fill, () => ref.read(playerProvider.notifier).previous()),
                const SizedBox(width: 12),
                _PlayPauseBtn(isPlaying: player.isPlaying, onTap: () => ref.read(playerProvider.notifier).togglePlay()),
                const SizedBox(width: 12),
                _CtrlBtn(CupertinoIcons.forward_fill, () => ref.read(playerProvider.notifier).next()),
              ]),
            ])),
          ]),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final PlayerState player;
  const _ProgressBar({required this.player});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SizedBox(height: 3, child: Stack(children: [
        Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: Colors.white.withValues(alpha: 0.2))),
        FractionallySizedBox(widthFactor: player.progress,
          child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(2),
            gradient: LinearGradient(colors: [Colors.white, Colors.white.withValues(alpha: 0.8)])))),
      ])),
      const SizedBox(height: 4),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(_fmt(player.position), style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10)),
        Text(_fmt(player.duration), style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10)),
      ]),
    ]);
  }
  String _fmt(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CtrlBtn(this.icon, this.onTap);
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, child: Container(width: 36, height: 36, alignment: Alignment.center,
      child: Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 22)));
  }
}

class _PlayPauseBtn extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onTap;
  const _PlayPauseBtn({required this.isPlaying, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, child: Container(width: 48, height: 48,
      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Icon(isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill, color: YYColors.accentPrimary, size: 24)));
  }
}

// ═══════════════════════════════════════════════════════════
//  快捷访问 2x2 毛玻璃卡片（参照 my-nas QuickAccessGrid）
// ═══════════════════════════════════════════════════════════

class _QuickAccessGrid extends StatelessWidget {
  final LibraryStats stats;
  final int recentCount;
  final bool hasSongs;
  final VoidCallback onShuffle;
  const _QuickAccessGrid({required this.stats, required this.recentCount, required this.hasSongs, required this.onShuffle});

  @override
  Widget build(BuildContext context) {
    final w = (MediaQuery.of(context).size.width - 40 - 12) / 2;
    return Wrap(spacing: 12, runSpacing: 12, children: [
      _GlassCard(icon: CupertinoIcons.heart_fill, label: '我喜欢', count: null,
        color: const Color(0xFFE91E63), width: w, onTap: () => context.push('/favorites')),
      _GlassCard(icon: CupertinoIcons.music_note_list, label: '全部歌曲', count: stats.songCount,
        color: YYColors.accentPrimary, width: w, onTap: () => context.push('/library?tab=songs')),
      _GlassCard(icon: CupertinoIcons.time, label: '最近播放', count: recentCount,
        color: const Color(0xFF2196F3), width: w, onTap: () => context.push('/library?tab=recent')),
      _GlassCard(icon: CupertinoIcons.shuffle, label: '随机播放', count: null,
        color: YYColors.accentSecondary, width: w, onTap: hasSongs ? onShuffle : null),
    ]);
  }
}

class _GlassCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? count;
  final Color color;
  final double width;
  final VoidCallback? onTap;
  const _GlassCard({required this.icon, required this.label, this.count, required this.color, required this.width, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: width, height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: context.isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.85),
              border: Border.all(color: context.isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.9), width: 0.5),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.06), blurRadius: 16, offset: const Offset(0, 4))]),
            child: Stack(children: [
              // 装饰图标
              Positioned(right: -10, bottom: -10, child: Icon(icon, size: 60, color: color.withValues(alpha: 0.1))),
              Padding(padding: const EdgeInsets.all(14), child: Row(children: [
                // 渐变图标
                Container(width: 44, height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [color, color.withValues(alpha: 0.8)]),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]),
                  child: Icon(icon, color: Colors.white, size: 22)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.yyTextPrimary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(count != null ? _fmt(count!) : '', style: TextStyle(fontSize: 12, color: context.yyTextTertiary)),
                ])),
                Icon(CupertinoIcons.chevron_right, color: context.yyTextTertiary.withValues(alpha: 0.5), size: 16),
              ])),
            ]),
          ),
        ),
      ),
    );
  }
  String _fmt(int n) => n >= 10000 ? '${(n / 10000).toStringAsFixed(1)}万首' : n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k首' : '$n首';
}

// ═══════════════════════════════════════════════════════════
//  推荐列表（参照 my-nas PopularTracksSection）
// ═══════════════════════════════════════════════════════════

class _PopularList extends StatelessWidget {
  final List<MusicItem> songs;
  const _PopularList({required this.songs});

  @override
  Widget build(BuildContext context) {
    // 每次 build 取 seed 固定的随机 5 首（按 title hash 取）
    final sorted = List<MusicItem>.from(songs)..sort((a, b) => a.title.hashCode.compareTo(b.title.hashCode));
    final picks = sorted.take(5).toList();

    return Container(
      decoration: BoxDecoration(
        color: context.isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: context.isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 4))]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(children: List.generate(picks.length, (i) => _RankItem(song: picks[i], rank: i + 1, isLast: i == picks.length - 1))),
      ),
    );
  }
}

class _RankItem extends ConsumerWidget {
  final MusicItem song;
  final int rank;
  final bool isLast;
  const _RankItem({required this.song, required this.rank, required this.isLast});

  Color get _rankColor => switch (rank) {
    1 => const Color(0xFFFFD700),
    2 => const Color(0xFFC0C0C0),
    3 => const Color(0xFFCD7F32),
    _ => Colors.grey,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => ref.read(playerProvider.notifier).playSong(song, queue: [song]),
      onLongPress: () => showSongActions(context, ref, song),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(border: isLast ? null : Border(
          bottom: BorderSide(color: context.isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)))),
        child: Row(children: [
          // 排名
          SizedBox(width: 28, child: rank <= 3
            ? Container(width: 24, height: 24,
                decoration: BoxDecoration(color: _rankColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                child: Center(child: Text('$rank', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _rankColor))))
            : Text('$rank', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.yyTextTertiary))),
          const SizedBox(width: 14),
          // 封面
          ClipRRect(borderRadius: BorderRadius.circular(10),
            child: SizedBox(width: 48, height: 48,
              child: GradientCover(seed: '${song.title}_${song.artist}', coverUrl: song.coverUrl, size: 48, borderRadius: 10))),
          const SizedBox(width: 14),
          // 信息
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.yyTextPrimary)),
            const SizedBox(height: 3),
            Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: context.yyTextTertiary)),
          ])),
          // 播放按钮
          Container(width: 32, height: 32,
            decoration: BoxDecoration(color: YYColors.accentPrimary.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(CupertinoIcons.play_fill, color: YYColors.accentPrimary, size: 16)),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  横向胶囊分类按钮（参照 my-nas BrowseCategoryGrid）
// ═══════════════════════════════════════════════════════════

class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final int? count;
  final Color color;
  final VoidCallback onTap;
  const _CategoryChip(this.label, this.icon, this.count, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))]),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(10)),
                child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600))),
            ],
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  最近播放卡片（参照 my-nas _ModernTrackCard）
// ═══════════════════════════════════════════════════════════

class _RecentCard extends ConsumerWidget {
  final MusicItem song;
  final List<MusicItem> queue;
  const _RecentCard({required this.song, required this.queue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => ref.read(playerProvider.notifier).playSong(song, queue: queue),
      onLongPress: () => showSongActions(context, ref, song),
      child: Container(
        width: 140, margin: const EdgeInsets.only(right: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // 封面 + 播放按钮
          Container(
            width: 140, height: 140,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: context.isDark ? 0.35 : 0.15), blurRadius: 16, offset: const Offset(0, 6))]),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(fit: StackFit.expand, children: [
                GradientCover(seed: '${song.title}_${song.artist}', coverUrl: song.coverUrl, size: 140, borderRadius: 14),
                // 常驻播放按钮
                Positioned(right: 10, bottom: 10, child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: YYColors.accentPrimary,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: YYColors.accentPrimary.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 2))]),
                  child: const Icon(CupertinoIcons.play_fill, color: Colors.white, size: 18))),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.yyTextPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.yyTextTertiary, fontSize: 11)),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  空状态
// ═══════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final VoidCallback onAddSource;
  const _EmptyState({required this.onAddSource});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Icon(CupertinoIcons.music_note_2, size: 48, color: context.yyTextTertiary.withValues(alpha: 0.4)),
      const SizedBox(height: 16),
      Text('还没有音乐', style: TextStyle(color: context.yyTextPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text('连接数据源开始播放', style: TextStyle(color: context.yyTextTertiary, fontSize: 14)),
      const SizedBox(height: 20),
      GestureDetector(
        onTap: onAddSource,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(color: YYColors.accentPrimary, borderRadius: BorderRadius.circular(12)),
          child: const Text('添加数据源', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)))),
    ]);
  }
}
