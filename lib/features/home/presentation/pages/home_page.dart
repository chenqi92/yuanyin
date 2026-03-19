import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/theme.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../../../shared/widgets/gradient_cover.dart';
import '../../../player/domain/entities/music_item.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../library/presentation/providers/library_provider.dart';

/// 首页
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final library = ref.watch(libraryProvider);

    return Scaffold(
      backgroundColor: YYColors.bgBase,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            floating: true,
            title: const Text('猿音',
                style: TextStyle(
                    color: YYColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold)),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 160),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 8),

                // Hero 当前播放卡片
                if (playerState.hasSong)
                  _HeroPlayingCard(playerState: playerState)
                      .animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0),

                // 空状态引导
                if (library.allSongs.isEmpty && !playerState.hasSong)
                  _EmptyGuide().animate().fadeIn(duration: 500.ms),

                // 最近播放
                if (library.recentPlays.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _SectionTitle(title: '最近播放'),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 160,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: library.recentPlays.length,
                      itemBuilder: (context, index) {
                        final song = library.recentPlays[index];
                        return _RecentCard(song: song, allSongs: library.allSongs);
                      },
                    ),
                  ),
                ],

                // 全部歌曲
                if (library.allSongs.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _SectionTitle(title: '全部歌曲', count: library.allSongs.length),
                  const SizedBox(height: 8),
                  ...library.allSongs.take(30).map((song) =>
                      _SongTile(song: song, allSongs: library.allSongs)),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyGuide extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Icon(CupertinoIcons.music_note_2, size: 48, color: YYColors.textTertiary),
          const SizedBox(height: 16),
          const Text('开始使用猿音', style: TextStyle(
              color: YYColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('添加数据源来扫描你的音乐文件',
              style: TextStyle(color: YYColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => context.push('/sources'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: YYColors.accentPrimary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('添加数据源', style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPlayingCard extends ConsumerWidget {
  final PlayerState playerState;
  const _HeroPlayingCard({required this.playerState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = playerState.currentSong!;

    return GestureDetector(
      onTap: () => context.push('/player'),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        tintColor: YYColors.accentPrimary,
        child: Row(
          children: [
            Hero(
              tag: 'cover',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(width: 64, height: 64, child: GradientCover(seed: song.title, size: 64)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('正在播放', style: TextStyle(
                      color: YYColors.accentPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(song.title, style: const TextStyle(
                      color: YYColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(song.artist, style: const TextStyle(
                      color: YYColors.textSecondary, fontSize: 13),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => ref.read(playerProvider.notifier).togglePlay(),
              child: Icon(
                playerState.isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                color: YYColors.accentPrimary, size: 32,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final int? count;
  const _SectionTitle({required this.title, this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(title, style: const TextStyle(
              color: YYColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
          if (count != null) ...[
            const SizedBox(width: 8),
            Text('$count', style: const TextStyle(color: YYColors.textTertiary, fontSize: 14)),
          ],
        ],
      ),
    );
  }
}

class _RecentCard extends ConsumerWidget {
  final MusicItem song;
  final List<MusicItem> allSongs;
  const _RecentCard({required this.song, required this.allSongs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => ref.read(playerProvider.notifier).playSong(song, queue: allSongs),
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(width: 120, height: 120, child: GradientCover(seed: song.title, size: 120)),
            ),
            const SizedBox(height: 6),
            Text(song.title, style: const TextStyle(
                color: YYColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(song.artist, style: const TextStyle(
                color: YYColors.textTertiary, fontSize: 10),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _SongTile extends ConsumerWidget {
  final MusicItem song;
  final List<MusicItem> allSongs;
  const _SongTile({required this.song, required this.allSongs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying = ref.watch(playerProvider).currentSong?.id == song.id;

    return GestureDetector(
      onTap: () => ref.read(playerProvider.notifier).playSong(song, queue: allSongs),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(width: 48, height: 48, child: GradientCover(seed: song.title, size: 48)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(song.title,
                      style: TextStyle(
                        color: isPlaying ? YYColors.accentPrimary : YYColors.textPrimary,
                        fontWeight: FontWeight.w500, fontSize: 15),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('${song.artist} · ${song.album}',
                      style: const TextStyle(color: YYColors.textSecondary, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Text(song.durationText, style: const TextStyle(color: YYColors.textTertiary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
