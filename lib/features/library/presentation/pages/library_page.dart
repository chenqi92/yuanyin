import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/theme.dart';
import '../providers/library_provider.dart';
import '../../../playlist/data/services/playlist_service.dart';
import '../../../playlist/presentation/pages/playlist_detail_page.dart';
import 'song_list_page.dart';

class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    final playlists = ref.watch(playlistsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            // 页头
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '音乐库',
                      style: TextStyle(
                        color: context.yyTextPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  if (library.stats.songCount > 0)
                    Text(
                      '${library.stats.songCount} 首',
                      style: TextStyle(
                        color: context.yyTextTertiary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 分类浏览 — 2x2 网格
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _CategoryCard(
                          title: '艺术家',
                          count: library.artists.length,
                          icon: CupertinoIcons.music_mic,
                          color: const Color(0xFFF59E0B),
                          onTap: () => _showArtistList(context, ref),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _CategoryCard(
                          title: '专辑',
                          count: library.albums.length,
                          icon: CupertinoIcons.square_stack_3d_up_fill,
                          color: const Color(0xFF0EA5E9),
                          onTap: () => _showAlbumList(context, ref),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _CategoryCard(
                          title: '流派',
                          count: library.genres.length,
                          icon: CupertinoIcons.guitars,
                          color: const Color(0xFF8B5CF6),
                          onTap: () => _showGenreList(context, ref),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _CategoryCard(
                          title: '全部歌曲',
                          count: library.stats.songCount,
                          icon: CupertinoIcons.music_note_list,
                          color: const Color(0xFF34D399),
                          onTap: () => _showAllSongs(context, ref),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 歌单
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '歌单',
                      style: TextStyle(
                        color: context.yyTextPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showCreatePlaylist(context, ref),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: context.yyBgSurface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.plus, size: 14, color: context.yyTextSecondary),
                          const SizedBox(width: 4),
                          Text(
                            '新建',
                            style: TextStyle(
                              color: context.yyTextSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            if (playlists.playlists.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: context.yyBgSurface.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        CupertinoIcons.music_note_list,
                        size: 32,
                        color: context.yyTextTertiary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '还没有歌单',
                        style: TextStyle(
                          color: context.yyTextSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            ...playlists.playlists.map((playlist) {
              final palette = YYColors
                  .categoryGradients[playlist.colorIndex % YYColors.categoryGradients.length];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlaylistDetailPage(playlistId: playlist.id),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: palette.first.withValues(alpha: context.isDark ? 0.08 : 0.05),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: palette.first.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(CupertinoIcons.music_note_list, color: palette.first, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                playlist.name,
                                style: TextStyle(
                                  color: context.yyTextPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${playlist.songIds.length} 首',
                                style: TextStyle(
                                  color: context.yyTextTertiary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(CupertinoIcons.chevron_right, size: 14, color: context.yyTextTertiary),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
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
    final artists = ref.read(libraryProvider).artists;
    _showPickerSheet(
      context,
      '艺术家',
      artists.map((item) => item.name).toList(),
      (name) {
        final db = ref.read(musicDatabaseProvider);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SongListPage(
              type: SongListType.artist,
              title: name,
              loadSongs: () => db.getSongsByArtist(name),
            ),
          ),
        );
      },
    );
  }

  void _showAlbumList(BuildContext context, WidgetRef ref) {
    final albums = ref.read(libraryProvider).albums;
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: context.yyBgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('专辑', style: TextStyle(
                  color: ctx.yyTextPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Divider(height: 1, color: ctx.yySeparator),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: albums.length,
                itemBuilder: (_, index) {
                  final album = albums[index];
                  return ListTile(
                    title: Text(album.name, style: TextStyle(
                        color: ctx.yyTextPrimary, fontWeight: FontWeight.w600)),
                    subtitle: Text(album.artist, style: TextStyle(color: ctx.yyTextTertiary)),
                    onTap: () {
                      Navigator.pop(ctx);
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
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGenreList(BuildContext context, WidgetRef ref) {
    final genres = ref.read(libraryProvider).genres;
    _showPickerSheet(
      context,
      '流派',
      genres.map((item) => item.name).toList(),
      (name) {
        final db = ref.read(musicDatabaseProvider);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SongListPage(
              type: SongListType.genre,
              title: name,
              loadSongs: () => db.getSongsByGenre(name),
            ),
          ),
        );
      },
    );
  }

  void _showPickerSheet(
    BuildContext context,
    String title,
    List<String> items,
    void Function(String) onPick,
  ) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: context.yyBgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(title, style: TextStyle(
                  color: ctx.yyTextPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Divider(height: 1, color: ctx.yySeparator),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (_, index) {
                  return ListTile(
                    title: Text(items[index], style: TextStyle(
                        color: ctx.yyTextPrimary, fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(ctx);
                      onPick(items[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
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
            child: const Text('创建', style: TextStyle(color: YYColors.accentPrimary)),
          ),
        ],
      ),
    );
  }
}

/// 分类卡片 — 精简版
class _CategoryCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: context.isDark ? 0.08 : 0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const Spacer(),
                Icon(CupertinoIcons.chevron_right, size: 14, color: context.yyTextTertiary),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                color: context.yyTextPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: TextStyle(
                color: context.yyTextSecondary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
