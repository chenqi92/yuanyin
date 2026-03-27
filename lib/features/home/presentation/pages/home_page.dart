import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/l10n/strings.dart';
import '../../../../app/theme/theme.dart';
import '../../../../shared/widgets/gradient_cover.dart';
import '../../../../shared/widgets/modern_music_ui.dart';
import '../../../../shared/widgets/song_actions_sheet.dart';
import '../../../library/data/services/music_database_service.dart';
import '../../../library/presentation/pages/song_list_page.dart';
import '../../../library/presentation/providers/library_provider.dart';
import '../../../player/domain/entities/music_item.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../playlist/data/services/playlist_service.dart';
import '../../../playlist/presentation/pages/playlist_detail_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    final player = ref.watch(playerProvider);
    final playlists = ref.watch(playlistsProvider);
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final featuredSong =
        player.currentSong ??
        (library.recentPlays.isNotEmpty
            ? library.recentPlays.first
            : library.allSongs.isNotEmpty
            ? library.allSongs.first
            : null);
    final albumCoverMap = _albumSongMap(library.allSongs);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: YYPageHeader(
                eyebrow: _greeting(),
                title: S.of(context).appName,
                trailing: isIOS
                    ? null
                    : YYHeaderActionButton(
                        icon: CupertinoIcons.search,
                        onTap: () => context.push('/search'),
                      ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: featuredSong != null
                    ? _FeaturedListenCard(
                        song: featuredSong,
                        isCurrentSong:
                            player.currentSong?.id == featuredSong.id,
                        isPlaying:
                            player.currentSong?.id == featuredSong.id &&
                            player.isPlaying,
                      )
                    : const _EmptyHeroCard(),
              ),
            ),
            if (library.recentPlays.isNotEmpty) ...[
              const SliverToBoxAdapter(child: _ShelfHeader(title: '最近播放')),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 246,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: library.recentPlays.take(10).length,
                    itemBuilder: (_, index) {
                      final song = library.recentPlays[index];
                      return _RecentPosterCard(
                        song: song,
                        queue: library.recentPlays,
                      );
                    },
                  ),
                ),
              ),
            ],
            if (library.albums.isNotEmpty) ...[
              const SliverToBoxAdapter(child: _ShelfHeader(title: '专辑')),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 274,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: library.albums.take(10).length,
                    itemBuilder: (_, index) {
                      final album = library.albums[index];
                      final coverSong =
                          albumCoverMap['${album.name}__${album.artist}'];
                      return _AlbumPosterCard(
                        album: album,
                        coverSong: coverSong,
                      );
                    },
                  ),
                ),
              ),
            ],
            if (playlists.playlists.isNotEmpty) ...[
              const SliverToBoxAdapter(child: _ShelfHeader(title: '歌单')),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 250,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: playlists.playlists.length,
                    itemBuilder: (_, index) {
                      return _PlaylistPosterCard(
                        playlist: playlists.playlists[index],
                      );
                    },
                  ),
                ),
              ),
            ],
            SliverToBoxAdapter(
              child: SizedBox(height: YYSizes.bottomInset(context)),
            ),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return '夜深了';
    if (hour < 12) return '早上好';
    if (hour < 14) return '中午好';
    if (hour < 18) return '下午好';
    return '晚上好';
  }
}

Map<String, MusicItem> _albumSongMap(List<MusicItem> songs) {
  final map = <String, MusicItem>{};
  for (final song in songs) {
    final key = '${song.album}__${song.artist}';
    map.putIfAbsent(key, () => song);
  }
  return map;
}

class _ShelfHeader extends StatelessWidget {
  final String title;

  const _ShelfHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
      child: Text(
        title,
        style: TextStyle(
          color: context.yyTextPrimary,
          fontSize: 30,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.9,
          height: 1.0,
        ),
      ),
    );
  }
}

class _FeaturedListenCard extends ConsumerWidget {
  final MusicItem song;
  final bool isCurrentSong;
  final bool isPlaying;

  const _FeaturedListenCard({
    required this.song,
    required this.isCurrentSong,
    required this.isPlaying,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => context.push('/player'),
      onLongPress: () => showSongActions(context, ref, song),
      child: Container(
        height: 330,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GradientCover(
              seed: '${song.title}_${song.artist}',
              coverUrl: song.coverUrl,
              filePath: song.filePath,
              size: 330,
              borderRadius: 34,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.06),
                    Colors.black.withValues(alpha: 0.18),
                    Colors.black.withValues(alpha: 0.66),
                    Colors.black.withValues(alpha: 0.84),
                  ],
                  stops: const [0, 0.35, 0.74, 1],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  YYTag(
                    text: isPlaying ? '继续播放' : '推荐播放',
                    color: YYColors.accentPrimary,
                    icon: CupertinoIcons.waveform_path_ecg,
                  ),
                  const Spacer(),
                  Text(
                    song.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 33,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.2,
                      height: 0.98,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      _OverlayButton(
                        icon: isPlaying
                            ? CupertinoIcons.pause_fill
                            : CupertinoIcons.play_fill,
                        onTap: () {
                          final notifier = ref.read(playerProvider.notifier);
                          if (isCurrentSong) {
                            notifier.togglePlay();
                          } else {
                            notifier.playSong(song);
                          }
                        },
                        filled: true,
                      ),
                      const SizedBox(width: 10),
                      _OverlayButton(
                        icon: CupertinoIcons.forward_fill,
                        onTap: () => ref.read(playerProvider.notifier).next(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHeroCard extends StatelessWidget {
  const _EmptyHeroCard();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/sources'),
      child: Container(
        height: 280,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.yyBgElevated,
              context.yyBlend(YYColors.accentPrimary, amount: 0.14),
            ],
          ),
          borderRadius: BorderRadius.circular(34),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const YYTag(text: '开始使用', color: YYColors.accentPrimary),
              const Spacer(),
              Text(
                '连接你的音乐来源',
                style: TextStyle(
                  color: context.yyTextPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.9,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '把本地和 NAS 的音乐放进同一个播放器里。',
                style: TextStyle(
                  color: context.yyTextSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverlayButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  const _OverlayButton({
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: filled ? Colors.white : Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(YYRadius.full),
          border: Border.all(
            color: filled
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.16),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(YYRadius.full),
          child: Icon(
            icon,
            color: filled ? Colors.black : Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _RecentPosterCard extends ConsumerWidget {
  final MusicItem song;
  final List<MusicItem> queue;

  const _RecentPosterCard({required this.song, required this.queue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () =>
          ref.read(playerProvider.notifier).playSong(song, queue: queue),
      onLongPress: () => showSongActions(context, ref, song),
      child: Container(
        width: 184,
        margin: const EdgeInsets.only(right: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: SizedBox(
                width: 184,
                height: 184,
                child: GradientCover(
                  seed: '${song.title}_${song.artist}',
                  coverUrl: song.coverUrl,
                  filePath: song.filePath,
                  size: 184,
                  borderRadius: 26,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              song.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.yyTextPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.yyTextSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumPosterCard extends ConsumerWidget {
  final AlbumInfo album;
  final MusicItem? coverSong;

  const _AlbumPosterCard({required this.album, this.coverSong});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        final db = ref.read(musicDatabaseProvider);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SongListPage(
              type: SongListType.album,
              title: album.name,
              subtitle: album.artist,
              loadSongs: () => db.getSongsByAlbum(album.name, album.artist),
            ),
          ),
        );
      },
      child: Container(
        width: 210,
        margin: const EdgeInsets.only(right: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: SizedBox(
                width: 210,
                height: 210,
                child: GradientCover(
                  seed: '${album.name}_${album.artist}',
                  coverUrl: coverSong?.coverUrl,
                  filePath: coverSong?.filePath,
                  size: 210,
                  borderRadius: 28,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              album.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.yyTextPrimary,
                fontSize: 19,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.35,
                height: 1.08,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              album.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.yyTextSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistPosterCard extends StatelessWidget {
  final PlaylistEntity playlist;

  const _PlaylistPosterCard({required this.playlist});

  @override
  Widget build(BuildContext context) {
    final palette =
        YYColors.categoryGradients[playlist.colorIndex %
            YYColors.categoryGradients.length];

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlaylistDetailPage(playlistId: playlist.id),
          ),
        );
      },
      child: Container(
        width: 210,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              yyMix(const Color(0xFF13161C), palette.first, 0.34),
              yyMix(const Color(0xFF0A0B0F), palette.last, 0.26),
            ],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              YYTag(
                text: '播放列表',
                color: palette.first,
                icon: CupertinoIcons.music_note_list,
              ),
              const Spacer(),
              Text(
                playlist.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${playlist.songIds.length} 首歌曲',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.76),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
