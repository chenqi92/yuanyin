import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/l10n/strings.dart';
import '../../../../app/theme/theme.dart';
import '../../../../shared/widgets/gradient_cover.dart';
import '../../../../shared/widgets/modern_music_ui.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../../../shared/widgets/song_actions_sheet.dart';
import '../../../favorites/data/services/favorites_service.dart';
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
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── 页头 ──
            SliverToBoxAdapter(
              child: YYPageHeader(
                eyebrow: _greeting(),
                title: S.of(context).appName,
                trailing: YYHeaderActionButton(
                  icon: CupertinoIcons.search,
                  onTap: () => context.push('/search'),
                  primary: false,
                ),
              ),
            ),

            // ── Hero 播放卡片 ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: _HeroCard(player: player),
              ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.98, 0.98)),
            ),

            // ── 音乐库统计 ──
            if (library.allSongs.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                  child: _StatsPanel(stats: library.stats),
                ),
              ),

            // ── 快捷访问 ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: _QuickAccessGrid(
                  stats: library.stats,
                  recentCount: library.recentPlays.length,
                  hasSongs: library.allSongs.isNotEmpty,
                  onShuffle: () {
                    HapticFeedback.mediumImpact();
                    final songs = List<MusicItem>.from(library.allSongs)..shuffle();
                    if (songs.isNotEmpty) {
                      ref.read(playerProvider.notifier).playSong(songs.first, queue: songs);
                    }
                  },
                ),
              ),
            ),

            // ── 最近播放 ──
            if (library.recentPlays.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: YYSectionTitle(
                  title: '最近播放',
                  trailing: TextButton(
                    onPressed: () => context.push('/library?tab=recent'),
                    child: const Text('全部'),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 190,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: library.recentPlays.take(10).length,
                    itemBuilder: (_, i) {
                      final song = library.recentPlays[i];
                      return _RecentCard(song: song, queue: library.recentPlays)
                          .animate().fadeIn(delay: (40 * i).ms).slideX(begin: 0.1);
                    },
                  ),
                ),
              ),
            ],

            // ── 收藏歌曲 ──
            SliverToBoxAdapter(child: _FavoritesSection()),

            // ── 为你推荐 ──
            if (library.allSongs.length >= 5) ...[
              SliverToBoxAdapter(
                child: YYSectionTitle(
                  title: '为你推荐',
                  subtitle: '随机发现音乐库中的宝藏',
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      // 这里简单模拟随机取样逻辑
                      final song = library.allSongs[(index * 7) % library.allSongs.length];
                      return YYTrackRow(
                        song: song,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          ref.read(playerProvider.notifier).playSong(song, queue: [song]);
                        },
                      );
                    },
                    childCount: 5,
                  ),
                ),
              ),
            ],

            // ── 专辑精选 ──
            if (library.albums.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: YYSectionTitle(
                  title: '专辑精选',
                  trailing: TextButton(
                    onPressed: () => context.push('/library?tab=albums'),
                    child: const Text('浏览'),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 160,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: library.albums.take(8).length,
                    itemBuilder: (_, i) {
                      final album = library.albums[i];
                      return _AlbumCard(album: album)
                          .animate().fadeIn(delay: (40 * i).ms);
                    },
                  ),
                ),
              ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 5) return '深夜潜听';
    if (h < 12) return '清晨乐章';
    if (h < 14) return '午后时光';
    if (h < 19) return '傍晚旋律';
    return '月下弦音';
  }
}

class _StatsPanel extends StatelessWidget {
  final LibraryStats stats;
  const _StatsPanel({required this.stats});

  @override
  Widget build(BuildContext context) {
    return YYPanel(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatCell(label: '曲目', value: stats.songCount, icon: CupertinoIcons.music_note),
          _StatCell(label: '专辑', value: stats.albumCount, icon: CupertinoIcons.square_stack),
          _StatCell(label: '艺人', value: stats.artistCount, icon: CupertinoIcons.person_2),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  const _StatCell({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: YYColors.accentPrimary, size: 20),
        const SizedBox(height: 8),
        Text(
          value.toString(),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        Text(
          label,
          style: TextStyle(color: context.yyTextTertiary, fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _HeroCard extends ConsumerWidget {
  final PlayerState player;
  const _HeroCard({required this.player});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = player.currentSong;
    if (song == null) return _EmptyHero(ref: ref);

    return YYPanel(
      padding: EdgeInsets.zero,
      onTap: () => context.push('/player'),
      child: Stack(
        children: [
          // Background Blur
          Positioned.fill(
            child: Opacity(
              opacity: 0.4,
              child: GradientCover(
                seed: song.title,
                coverUrl: song.coverUrl,
                size: 400,
                borderRadius: 0,
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.6),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(YYRadius.md),
                  child: SizedBox(
                    width: 100,
                    height: 100,
                    child: GradientCover(
                      seed: song.title,
                      coverUrl: song.coverUrl,
                      size: 100,
                      borderRadius: YYRadius.md,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: YYColors.accentPrimary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          player.isPlaying ? '正在播放' : '已暂停',
                          style: const TextStyle(color: YYColors.accentPrimary, fontSize: 10, fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        song.artist,
                        style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ),
                _HeroPlayBtn(isPlaying: player.isPlaying, onTap: () => ref.read(playerProvider.notifier).togglePlay()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHero extends StatelessWidget {
  final WidgetRef ref;
  const _EmptyHero({required this.ref});

  @override
  Widget build(BuildContext context) {
    return YYPanel(
      onTap: () {
        final library = ref.read(libraryProvider);
        if (library.allSongs.isNotEmpty) {
          final songs = List<MusicItem>.from(library.allSongs)..shuffle();
          ref.read(playerProvider.notifier).playSong(songs.first, queue: songs);
        }
      },
      child: Row(
        children: [
          const YYIconBadge(icon: CupertinoIcons.music_note_2, color: YYColors.accentPrimary),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('开始探索你的音乐库', style: context.yyTextTheme.titleMedium),
                const SizedBox(height: 4),
                Text('随机播放一首歌曲开始', style: context.yyTextTheme.labelMedium),
              ],
            ),
          ),
          const Icon(CupertinoIcons.shuffle, color: YYColors.accentPrimary),
        ],
      ),
    );
  }
}

class _HeroPlayBtn extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onTap;
  const _HeroPlayBtn({required this.isPlaying, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        width: 52,
        height: 52,
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: Icon(
          isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
          color: Colors.black,
          size: 26,
        ),
      ),
    );
  }
}

class _QuickAccessGrid extends StatelessWidget {
  final LibraryStats stats;
  final int recentCount;
  final bool hasSongs;
  final VoidCallback onShuffle;
  const _QuickAccessGrid({required this.stats, required this.recentCount, required this.hasSongs, required this.onShuffle});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: [
        _AccessCard(icon: CupertinoIcons.heart_fill, label: '我喜欢', color: YYColors.heartRed, onTap: () => context.push('/favorites')),
        _AccessCard(icon: CupertinoIcons.music_albums, label: '专辑库', color: YYColors.accentTertiary, onTap: () => context.push('/library?tab=albums')),
        _AccessCard(icon: CupertinoIcons.time, label: '最近播放', color: YYColors.accentPrimary, onTap: () => context.push('/library?tab=recent')),
        _AccessCard(icon: CupertinoIcons.shuffle, label: '随机播放', color: YYColors.accentSecondary, onTap: onShuffle),
      ],
    );
  }
}

class _AccessCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _AccessCard({required this.icon, required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return YYPanel(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _RecentCard extends ConsumerWidget {
  final MusicItem song;
  final List<MusicItem> queue;
  const _RecentCard({required this.song, required this.queue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        ref.read(playerProvider.notifier).playSong(song, queue: queue);
      },
      onLongPress: () => showSongActions(context, ref, song),
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(YYRadius.md),
              child: AspectRatio(
                aspectRatio: 1,
                child: GradientCover(seed: song.title, coverUrl: song.coverUrl, size: 130, borderRadius: YYRadius.md),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.yyTextSecondary, fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoritesSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    // 这里简单示意，实际需从 favoritesService 获取
    return const SizedBox.shrink(); 
  }
}

class _AlbumCard extends StatelessWidget {
  final AlbumInfo album;
  const _AlbumCard({required this.album});

  @override
  Widget build(BuildContext context) {
    return YYPanel(
      margin: const EdgeInsets.only(right: 16),
      width: 150,
      padding: const EdgeInsets.all(12),
      onTap: () {},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Row(
              children: [
                const Icon(CupertinoIcons.square_stack_3d_up_fill, color: YYColors.accentTertiary, size: 24),
                const Spacer(),
                Text('${album.songCount}首', style: TextStyle(color: context.yyTextTertiary, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(album.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 2),
          Text(album.artist, maxLines: 1, style: TextStyle(color: context.yyTextSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

extension on BuildContext {
  TextTheme get yyTextTheme => Theme.of(this).textTheme;
}

