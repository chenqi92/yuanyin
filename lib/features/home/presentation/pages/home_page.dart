import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/l10n/strings.dart';
import '../../../../app/theme/theme.dart';
import '../../../../shared/widgets/gradient_cover.dart';
import '../../../../shared/widgets/modern_music_ui.dart';
import '../../../../shared/widgets/song_actions_sheet.dart';
import '../../../library/presentation/providers/library_provider.dart';
import '../../../player/domain/entities/music_item.dart';
import '../../../player/presentation/providers/player_provider.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return '深夜声场';
    if (hour < 12) return '早安精选';
    if (hour < 18) return '午后律动';
    return '夜色听感';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    final player = ref.watch(playerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: YYScenicBackground(
        accent: player.currentSong != null
            ? YYSeedPalette.primary(player.currentSong!.title)
            : YYColors.accentPrimary,
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 28),
            children: [
              YYPageHeader(
                eyebrow: _greeting(),
                title: S.of(context).appName,
                subtitle: library.allSongs.isEmpty
                    ? null
                    : '音乐库 ${library.stats.songCount} 首',
                trailing: YYHeaderActionButton(
                  icon: CupertinoIcons.waveform_path_badge_plus,
                  onTap: () => context.push('/sources'),
                ),
              ),
              _HeroDeck(
                player: player,
                library: library,
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.04),
              if (library.allSongs.isNotEmpty) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: YYMetricBand(
                    items: [
                      YYMetricBandItem(
                        label: '歌曲',
                        value: '${library.stats.songCount}',
                        tint: YYColors.accentPrimary,
                      ),
                      YYMetricBandItem(
                        label: '艺术家',
                        value: '${library.stats.artistCount}',
                        tint: YYColors.accentSecondary,
                      ),
                      YYMetricBandItem(
                        label: '专辑',
                        value: '${library.stats.albumCount}',
                        tint: YYColors.accentTertiary,
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 60.ms),
                const YYSectionTitle(title: '快速操作'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _QuickActionDeck(
                    onShuffle: () {
                      final songs = List<MusicItem>.from(library.allSongs)
                        ..shuffle();
                      if (songs.isNotEmpty) {
                        ref
                            .read(playerProvider.notifier)
                            .playSong(songs.first, queue: songs);
                      }
                    },
                    onFavorites: () => context.push('/favorites'),
                    onStats: () => context.push('/stats'),
                    onEqualizer: () => context.push('/equalizer'),
                  ),
                ).animate().fadeIn(delay: 100.ms),
              ],
              if (library.recentPlays.isNotEmpty) ...[
                const YYSectionTitle(title: '最近在听'),
                SizedBox(
                  height: 194,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: library.recentPlays.take(10).length,
                    itemBuilder: (context, index) {
                      final song = library.recentPlays[index];
                      return _RecentCard(
                        song: song,
                        queue: library.recentPlays,
                      ).animate().fadeIn(delay: (80 * index).ms);
                    },
                  ),
                ),
              ],
              if (library.allSongs.isNotEmpty) ...[
                const YYSectionTitle(title: '马上开播'),
                ...library.allSongs.take(8).map((song) {
                  final active = player.currentSong?.id == song.id;
                  return YYTrackRow(
                    song: song,
                    active: active,
                    onTap: () => ref
                        .read(playerProvider.notifier)
                        .playSong(song, queue: library.allSongs),
                    onLongPress: () => showSongActions(context, ref, song),
                    leading: SizedBox(
                      width: 24,
                      child: active
                          ? const Icon(
                              CupertinoIcons.waveform,
                              color: YYColors.accentPrimary,
                              size: 18,
                            )
                          : Text(
                              '${library.allSongs.indexOf(song) + 1}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: context.yyTextTertiary,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroDeck extends ConsumerWidget {
  final PlayerState player;
  final LibraryState library;

  const _HeroDeck({required this.player, required this.library});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (player.currentSong == null) {
      return YYPanel(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const YYIconBadge(
                  icon: CupertinoIcons.music_note_2,
                  color: YYColors.accentPrimary,
                  size: 52,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '把音乐库点亮',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '连接音乐源后即可开始播放',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                YYPillButton(
                  label: '添加数据源',
                  icon: CupertinoIcons.plus,
                  primary: true,
                  onTap: () => context.push('/sources'),
                ),
                YYPillButton(
                  label: '浏览设置',
                  icon: CupertinoIcons.slider_horizontal_3,
                  onTap: () => context.go('/settings'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final song = player.currentSong!;

    return YYPanel(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      onTap: () => context.push('/player'),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 98,
                height: 98,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  gradient: YYSeedPalette.gradient(song.title),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: YYShadows.coverFloat,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(23),
                  child: GradientCover(
                    seed: '${song.title}_${song.artist}',
                    coverUrl: song.coverUrl,
                    size: 98,
                    borderRadius: 23,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '继续播放',
                      style: TextStyle(
                        color: YYSeedPalette.primary(song.title),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      song.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      song.artist,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        YYTag(
                          text: song.album,
                          color: YYSeedPalette.secondary(song.title),
                        ),
                        YYTag(
                          text: player.isPlaying ? '正在播放' : '已暂停',
                          color: player.isPlaying
                              ? YYColors.statusSuccess
                              : context.yyBgSurface,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (library.stats.songCount > 0) ...[
            const SizedBox(height: 14),
            YYMetricBand(
              items: [
                YYMetricBandItem(
                  label: '队列',
                  value: '${player.queue.length}',
                  tint: YYSeedPalette.primary(song.title),
                ),
                YYMetricBandItem(
                  label: '曲库',
                  value: '${library.stats.songCount}',
                  tint: YYColors.accentSecondary,
                ),
                YYMetricBandItem(
                  label: '状态',
                  value: player.isPlaying ? '播放中' : '暂停',
                  tint: player.isPlaying
                      ? YYColors.statusSuccess
                      : context.yyTextSecondary,
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(YYRadius.full),
            child: LinearProgressIndicator(
              value: player.progress,
              minHeight: 5,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(
                YYSeedPalette.primary(song.title),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: YYPillButton(
                  label: player.isPlaying ? '暂停' : '播放',
                  icon: player.isPlaying
                      ? CupertinoIcons.pause_fill
                      : CupertinoIcons.play_fill,
                  primary: true,
                  onTap: () => ref.read(playerProvider.notifier).togglePlay(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: YYPillButton(
                  label: '下一首',
                  icon: CupertinoIcons.forward_fill,
                  onTap: () => ref.read(playerProvider.notifier).next(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionDeck extends StatelessWidget {
  final VoidCallback onShuffle;
  final VoidCallback onFavorites;
  final VoidCallback onStats;
  final VoidCallback onEqualizer;

  const _QuickActionDeck({
    required this.onShuffle,
    required this.onFavorites,
    required this.onStats,
    required this.onEqualizer,
  });

  @override
  Widget build(BuildContext context) {
    return YYPanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          YYActionRow(
            icon: CupertinoIcons.shuffle,
            color: YYColors.accentPrimary,
            title: '随机播放',
            subtitle: '立刻打开一条新的听歌路径',
            onTap: onShuffle,
          ),
          Divider(
            height: 1,
            color: context.yySeparator,
            indent: 64,
            endIndent: 16,
          ),
          YYActionRow(
            icon: CupertinoIcons.heart_fill,
            color: YYColors.heartRed,
            title: '我的收藏',
            subtitle: '把偏爱集中在一个干净的列表里',
            onTap: onFavorites,
          ),
          Divider(
            height: 1,
            color: context.yySeparator,
            indent: 64,
            endIndent: 16,
          ),
          YYActionRow(
            icon: CupertinoIcons.chart_bar_alt_fill,
            color: YYColors.accentSecondary,
            title: '听歌统计',
            subtitle: '看看你最近真正在重复什么',
            onTap: onStats,
          ),
          Divider(
            height: 1,
            color: context.yySeparator,
            indent: 64,
            endIndent: 16,
          ),
          YYActionRow(
            icon: CupertinoIcons.slider_horizontal_3,
            color: YYColors.accentTertiary,
            title: '均衡器',
            subtitle: '让当前的声音更贴近你的口味',
            onTap: onEqualizer,
          ),
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
      onTap: () =>
          ref.read(playerProvider.notifier).playSong(song, queue: queue),
      onLongPress: () => showSongActions(context, ref, song),
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            YYPanel(
              padding: const EdgeInsets.all(10),
              color: YYSeedPalette.primary(
                song.title,
              ).withValues(alpha: context.isDark ? 0.08 : 0.05),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  width: 130,
                  height: 130,
                  child: GradientCover(
                    seed: '${song.title}_${song.artist}',
                    coverUrl: song.coverUrl,
                    size: 130,
                    borderRadius: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.yyTextPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.yyTextSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
