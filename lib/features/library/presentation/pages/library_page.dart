import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/theme.dart';
import '../../../../shared/widgets/gradient_cover.dart';
import '../../../../shared/widgets/modern_music_ui.dart';
import '../../data/services/music_database_service.dart';
import '../../../player/domain/entities/music_item.dart';
import '../../../playlist/data/services/playlist_service.dart';
import '../../../playlist/presentation/pages/playlist_detail_page.dart';
import '../providers/library_provider.dart';
import 'library_collection_page.dart';
import 'song_list_page.dart';

class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    final playlists = ref.watch(playlistsProvider);
    final albumCoverMap = _albumSongMap(library.allSongs);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: YYPageHeader(
                eyebrow: '我的音乐',
                title: '音乐库',
                subtitle: library.stats.songCount > 0
                    ? '${library.stats.songCount} 首 · ${library.stats.artistCount} 位艺术家 · ${library.stats.albumCount} 张专辑'
                    : '还没有音乐',
                trailing: YYHeaderActionButton(
                  icon: CupertinoIcons.add,
                  onTap: () => _showCreatePlaylist(context, ref),
                ),
              ),
            ),
            if (playlists.playlists.isNotEmpty) ...[
              const SliverToBoxAdapter(child: _ShelfHeader(title: '歌单')),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 252,
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
            if (library.albums.isNotEmpty) ...[
              const SliverToBoxAdapter(child: _ShelfHeader(title: '专辑')),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 274,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: library.albums.take(12).length,
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
            const SliverToBoxAdapter(child: _ShelfHeader(title: '资料库')),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: YYPanel(
                  radius: 30,
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _LibraryRow(
                        icon: CupertinoIcons.music_note_list,
                        color: YYColors.accentPrimary,
                        title: '歌单',
                        detail: '${playlists.playlists.length}',
                        onTap: () => _showPlaylists(context, ref),
                      ),
                      _separator(context),
                      _LibraryRow(
                        icon: CupertinoIcons.music_note,
                        color: YYColors.accentTertiary,
                        title: '歌曲',
                        detail: '${library.stats.songCount}',
                        onTap: () => _showAllSongs(context, ref),
                      ),
                      _separator(context),
                      _LibraryRow(
                        icon: CupertinoIcons.music_mic,
                        color: YYColors.heartRed,
                        title: '艺术家',
                        detail: '${library.artists.length}',
                        onTap: () => _showArtistList(context, ref),
                      ),
                      _separator(context),
                      _LibraryRow(
                        icon: CupertinoIcons.square_stack_3d_up_fill,
                        color: YYColors.accentSecondary,
                        title: '专辑',
                        detail: '${library.albums.length}',
                        onTap: () => _showAlbumList(context, ref),
                      ),
                      _separator(context),
                      _LibraryRow(
                        icon: CupertinoIcons.guitars,
                        color: const Color(0xFF34D399),
                        title: '流派',
                        detail: '${library.genres.length}',
                        onTap: () => _showGenreList(context, ref),
                      ),
                      _separator(context),
                      _LibraryRow(
                        icon: CupertinoIcons.heart_fill,
                        color: YYColors.heartRed,
                        title: '收藏',
                        onTap: () => context.push('/favorites'),
                        isLast: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: YYSizes.bottomInset(context)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _separator(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 68),
      child: Container(height: 0.5, color: context.yySeparator),
    );
  }

  void _showPlaylists(BuildContext context, WidgetRef ref) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) =>
            const LibraryCollectionPage(kind: LibraryCollectionKind.playlists),
      ),
    );
  }

  void _showAllSongs(BuildContext context, WidgetRef ref) {
    final db = ref.read(musicDatabaseProvider);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SongListPage(
          type: SongListType.all,
          title: '全部歌曲',
          loadSongs: () => db.getAllSongs(),
        ),
      ),
    );
  }

  void _showArtistList(BuildContext context, WidgetRef ref) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) =>
            const LibraryCollectionPage(kind: LibraryCollectionKind.artists),
      ),
    );
  }

  void _showAlbumList(BuildContext context, WidgetRef ref) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) =>
            const LibraryCollectionPage(kind: LibraryCollectionKind.albums),
      ),
    );
  }

  void _showGenreList(BuildContext context, WidgetRef ref) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) =>
            const LibraryCollectionPage(kind: LibraryCollectionKind.genres),
      ),
    );
  }

  void _showCreatePlaylist(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.yyBgElevated,
        title: Text('新建歌单', style: TextStyle(color: context.yyTextPrimary)),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          style: TextStyle(color: context.yyTextPrimary),
          decoration: InputDecoration(
            hintText: '歌单名称',
            hintStyle: TextStyle(color: context.yyTextTertiary),
            filled: true,
            fillColor: context.yyBgSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: context.yyTextTertiary)),
          ),
          TextButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isNotEmpty) {
                ref.read(playlistsProvider.notifier).createPlaylist(name);
              }
              Navigator.pop(ctx);
            },
            child: const Text(
              '创建',
              style: TextStyle(color: YYColors.accentPrimary),
            ),
          ),
        ],
      ),
    );
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
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
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

class _LibraryRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? detail;
  final VoidCallback onTap;
  final bool isLast;

  const _LibraryRow({
    required this.icon,
    required this.color,
    required this.title,
    this.detail,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(30))
            : BorderRadius.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              YYIconBadge(icon: icon, color: color, size: 42),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: context.yyTextPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (detail != null) ...[
                Text(
                  detail!,
                  style: TextStyle(
                    color: context.yyTextTertiary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Icon(
                CupertinoIcons.chevron_right,
                color: context.yyTextTertiary,
                size: 15,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
