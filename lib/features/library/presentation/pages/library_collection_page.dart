import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/theme.dart';
import '../../../../shared/widgets/gradient_cover.dart';
import '../../../../shared/widgets/modern_music_ui.dart';
import '../../../player/domain/entities/music_item.dart';
import '../../../playlist/data/services/playlist_service.dart';
import '../../../playlist/presentation/pages/playlist_detail_page.dart';
import '../../data/services/music_database_service.dart';
import '../providers/library_provider.dart';
import 'song_list_page.dart';

enum LibraryCollectionKind { playlists, artists, albums, genres }

class LibraryCollectionPage extends ConsumerWidget {
  final LibraryCollectionKind kind;

  const LibraryCollectionPage({super.key, required this.kind});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    final playlists = ref.watch(playlistsProvider).playlists;
    final albumCoverMap = _albumSongMap(library.allSongs);

    return CupertinoPageScaffold(
      backgroundColor: context.yyBgBase,
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(_title),
            previousPageTitle: '音乐库',
            backgroundColor: context.yyBgBase.withValues(alpha: 0.92),
            border: Border(
              bottom: BorderSide(color: context.yySeparator, width: 0.5),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(
                _summary(playlists.length, library),
                style: TextStyle(
                  color: context.yyTextSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverToBoxAdapter(
              child: YYPanel(
                radius: 28,
                padding: EdgeInsets.zero,
                child: _buildList(
                  context,
                  ref,
                  playlists,
                  library,
                  albumCoverMap,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: YYSizes.bottomInset(context)),
          ),
        ],
      ),
    );
  }

  String get _title {
    return switch (kind) {
      LibraryCollectionKind.playlists => '歌单',
      LibraryCollectionKind.artists => '艺术家',
      LibraryCollectionKind.albums => '专辑',
      LibraryCollectionKind.genres => '流派',
    };
  }

  String _summary(int playlistCount, LibraryState library) {
    return switch (kind) {
      LibraryCollectionKind.playlists => '$playlistCount 个歌单',
      LibraryCollectionKind.artists => '${library.artists.length} 位艺术家',
      LibraryCollectionKind.albums => '${library.albums.length} 张专辑',
      LibraryCollectionKind.genres => '${library.genres.length} 个流派',
    };
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<PlaylistEntity> playlists,
    LibraryState library,
    Map<String, MusicItem> albumCoverMap,
  ) {
    final itemCount = switch (kind) {
      LibraryCollectionKind.playlists => playlists.length,
      LibraryCollectionKind.artists => library.artists.length,
      LibraryCollectionKind.albums => library.albums.length,
      LibraryCollectionKind.genres => library.genres.length,
    };

    if (itemCount == 0) {
      return Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          '这里还没有内容',
          style: TextStyle(
            color: context.yyTextTertiary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Column(
      children: List.generate(itemCount, (index) {
        final isLast = index == itemCount - 1;
        final row = switch (kind) {
          LibraryCollectionKind.playlists => _PlaylistCollectionRow(
            playlist: playlists[index],
            onTap: () => Navigator.of(context).push(
              CupertinoPageRoute<void>(
                builder: (_) =>
                    PlaylistDetailPage(playlistId: playlists[index].id),
              ),
            ),
          ),
          LibraryCollectionKind.artists => _MetaCollectionRow(
            badge: YYIconBadge(
              icon: CupertinoIcons.music_mic,
              color: YYColors.heartRed,
              size: 42,
            ),
            title: library.artists[index].name,
            detail: '${library.artists[index].songCount} 首',
            onTap: () {
              final db = ref.read(musicDatabaseProvider);
              Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => SongListPage(
                    type: SongListType.artist,
                    title: library.artists[index].name,
                    loadSongs: () =>
                        db.getSongsByArtist(library.artists[index].name),
                  ),
                ),
              );
            },
          ),
          LibraryCollectionKind.albums => _AlbumCollectionRow(
            album: library.albums[index],
            coverSong:
                albumCoverMap['${library.albums[index].name}__${library.albums[index].artist}'],
            onTap: () {
              final db = ref.read(musicDatabaseProvider);
              final album = library.albums[index];
              Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => SongListPage(
                    type: SongListType.album,
                    title: album.name,
                    subtitle: album.artist,
                    loadSongs: () =>
                        db.getSongsByAlbum(album.name, album.artist),
                  ),
                ),
              );
            },
          ),
          LibraryCollectionKind.genres => _MetaCollectionRow(
            badge: YYIconBadge(
              icon: CupertinoIcons.guitars,
              color: const Color(0xFF34D399),
              size: 42,
            ),
            title: library.genres[index].name,
            detail: '${library.genres[index].songCount} 首',
            onTap: () {
              final db = ref.read(musicDatabaseProvider);
              Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => SongListPage(
                    type: SongListType.genre,
                    title: library.genres[index].name,
                    loadSongs: () =>
                        db.getSongsByGenre(library.genres[index].name),
                  ),
                ),
              );
            },
          ),
        };

        return Column(
          children: [
            row,
            if (!isLast)
              Padding(
                padding: const EdgeInsets.only(left: 74),
                child: Divider(height: 1, color: context.yySeparator),
              ),
          ],
        );
      }),
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

class _MetaCollectionRow extends StatelessWidget {
  final Widget badge;
  final String title;
  final String detail;
  final VoidCallback onTap;

  const _MetaCollectionRow({
    required this.badge,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(double.infinity, 60),
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            badge,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: context.yyTextPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    style: TextStyle(
                      color: context.yyTextSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              color: context.yyTextTertiary,
              size: 15,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistCollectionRow extends StatelessWidget {
  final PlaylistEntity playlist;
  final VoidCallback onTap;

  const _PlaylistCollectionRow({required this.playlist, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = YYSeedPalette.primary(
      '${playlist.name}_${playlist.colorIndex}',
    );
    return _MetaCollectionRow(
      badge: YYIconBadge(
        icon: CupertinoIcons.music_note_list,
        color: color,
        size: 42,
      ),
      title: playlist.name,
      detail: '${playlist.songIds.length} 首',
      onTap: onTap,
    );
  }
}

class _AlbumCollectionRow extends StatelessWidget {
  final AlbumInfo album;
  final MusicItem? coverSong;
  final VoidCallback onTap;

  const _AlbumCollectionRow({
    required this.album,
    required this.coverSong,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(double.infinity, 60),
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 42,
                height: 42,
                child: GradientCover(
                  seed: '${album.name}_${album.artist}',
                  coverUrl: coverSong?.coverUrl,
                  filePath: coverSong?.filePath,
                  size: 42,
                  borderRadius: 12,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.yyTextPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
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
            Icon(
              CupertinoIcons.chevron_right,
              color: context.yyTextTertiary,
              size: 15,
            ),
          ],
        ),
      ),
    );
  }
}
