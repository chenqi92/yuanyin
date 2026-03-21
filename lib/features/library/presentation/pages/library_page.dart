import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/theme.dart';
import '../providers/library_provider.dart';
import '../../data/services/music_database_service.dart';
import '../../../playlist/data/services/playlist_service.dart';
import '../../../playlist/presentation/pages/playlist_detail_page.dart';
import '../../../player/domain/entities/music_item.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../../shared/widgets/gradient_cover.dart';
import 'song_list_page.dart';

/// 音乐库页 — v3 自适应亮暗主题
class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    final playlistsState = ref.watch(playlistsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? YYColors.bgBase : YYLightColors.bgBase;
    final card = isDark ? YYColors.bgElevated : YYLightColors.bgElevated;
    final pri = isDark ? YYColors.textPrimary : YYLightColors.textPrimary;
    final sub = isDark ? YYColors.textSecondary : YYLightColors.textSecondary;
    final tri = isDark ? YYColors.textTertiary : YYLightColors.textTertiary;
    final sep = isDark ? YYColors.separator : YYLightColors.separator;

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(YYSpacing.screenH, 12, YYSpacing.screenH, 0),
                child: Text('我的音乐', style: TextStyle(
                    color: pri, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 160),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 20),
                // 分类网格
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: YYSpacing.screenH),
                  child: Column(
                    children: [
                      Row(children: [
                        Expanded(child: _CategoryCard(
                          icon: CupertinoIcons.music_mic, title: '艺术家',
                          count: library.artists.length, gradientIndex: 0,
                          onTap: () => _showArtistList(context, ref, card, pri, tri, sep),
                        ).animate().fadeIn(delay: 80.ms)),
                        const SizedBox(width: 12),
                        Expanded(child: _CategoryCard(
                          icon: CupertinoIcons.square_stack, title: '专辑',
                          count: library.albums.length, gradientIndex: 1,
                          onTap: () => _showAlbumList(context, ref, card, pri, tri, sep),
                        ).animate().fadeIn(delay: 120.ms)),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: _CategoryCard(
                          icon: CupertinoIcons.guitars, title: '流派',
                          count: library.genres.length, gradientIndex: 2,
                          onTap: () => _showGenreList(context, ref, card, pri, tri, sep),
                        ).animate().fadeIn(delay: 160.ms)),
                        const SizedBox(width: 12),
                        Expanded(child: _CategoryCard(
                          icon: CupertinoIcons.music_note_list, title: '全部歌曲',
                          count: library.stats.songCount, gradientIndex: 3,
                          onTap: () => _showAllSongs(context, ref),
                        ).animate().fadeIn(delay: 200.ms)),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: _CategoryCard(
                          icon: CupertinoIcons.heart_fill, title: '收藏',
                          count: 0, gradientIndex: 4,
                          onTap: () => context.push('/favorites'),
                        ).animate().fadeIn(delay: 240.ms)),
                        const SizedBox(width: 12),
                        const Expanded(child: SizedBox()),
                      ]),
                    ],
                  ),
                ),

                // 歌单
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: YYSpacing.screenH),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('歌单', style: TextStyle(
                          color: pri, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.3)),
                      GestureDetector(
                        onTap: () => _showCreatePlaylist(context, ref, card, pri, tri,
                            isDark ? YYColors.bgSurface : YYLightColors.bgSurface),
                        child: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(8)),
                          child: const Icon(CupertinoIcons.plus, color: YYColors.accentPrimary, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (playlistsState.playlists.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: YYSpacing.screenH, vertical: 12),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(YYRadius.md),
                        border: Border.all(color: sep),
                      ),
                      child: Center(child: Text('还没有歌单，点击 + 创建', style: TextStyle(color: tri, fontSize: 13))),
                    ),
                  ),
                ...playlistsState.playlists.map((pl) => _PlaylistTile(
                  playlist: pl,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => PlaylistDetailPage(playlistId: pl.id),
                  )),
                )),

                // 最近播放
                if (library.recentPlays.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: YYSpacing.screenH),
                    child: Text('最近播放', style: TextStyle(
                        color: pri, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.3)),
                  ),
                  const SizedBox(height: 8),
                  ...library.recentPlays.take(5).map((song) => _RecentPlayTile(song: song)),
                ],

                // 空状态
                if (library.stats.songCount == 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Column(
                        children: [
                          Container(
                            width: 56, height: 56,
                            decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16)),
                            child: Icon(CupertinoIcons.music_note_2, size: 28, color: tri),
                          ),
                          const SizedBox(height: 16),
                          Text('音乐库为空', style: TextStyle(color: sub, fontSize: 15)),
                          const SizedBox(height: 4),
                          Text('添加数据源并扫描后这里会显示你的音乐',
                              style: TextStyle(color: tri, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showAllSongs(BuildContext context, WidgetRef ref) {
    final db = ref.read(musicDatabaseProvider);
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => SongListPage(
        type: SongListType.all, title: '全部歌曲',
        loadSongs: () => db.getAllSongs(),
      ),
    ));
  }

  void _showArtistList(BuildContext context, WidgetRef ref, Color card, Color pri, Color tri, Color sep) {
    final artists = ref.read(libraryProvider).artists;
    _showPickerSheet(context, '选择艺术家', artists.map((a) => a.name).toList(), card, pri, tri, sep, (name) {
      final db = ref.read(musicDatabaseProvider);
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => SongListPage(
          type: SongListType.artist, title: name, subtitle: '艺术家',
          loadSongs: () => db.getSongsByArtist(name),
        ),
      ));
    });
  }

  void _showAlbumList(BuildContext context, WidgetRef ref, Color card, Color pri, Color tri, Color sep) {
    final albums = ref.read(libraryProvider).albums;
    showModalBottomSheet(
      context: context,
      backgroundColor: card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(YYRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('选择专辑', style: TextStyle(color: pri, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Divider(height: 1, color: sep),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: albums.length,
                itemBuilder: (_, i) => ListTile(
                  title: Text(albums[i].name, style: TextStyle(color: pri)),
                  subtitle: Text(albums[i].artist, style: TextStyle(color: tri, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    final db = ref.read(musicDatabaseProvider);
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => SongListPage(
                        type: SongListType.album, title: albums[i].name, subtitle: albums[i].artist,
                        loadSongs: () => db.getSongsByAlbum(albums[i].name, albums[i].artist),
                      ),
                    ));
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGenreList(BuildContext context, WidgetRef ref, Color card, Color pri, Color tri, Color sep) {
    final genres = ref.read(libraryProvider).genres;
    _showPickerSheet(context, '选择流派', genres.map((g) => g.name).toList(), card, pri, tri, sep, (name) {
      final db = ref.read(musicDatabaseProvider);
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => SongListPage(
          type: SongListType.genre, title: name, subtitle: '流派',
          loadSongs: () => db.getSongsByGenre(name),
        ),
      ));
    });
  }

  void _showPickerSheet(BuildContext context, String title, List<String> items,
      Color card, Color pri, Color tri, Color sep, Function(String) onPick) {
    showModalBottomSheet(
      context: context,
      backgroundColor: card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(YYRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(title, style: TextStyle(color: pri, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Divider(height: 1, color: sep),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (_, i) => ListTile(
                  title: Text(items[i], style: TextStyle(color: pri)),
                  onTap: () { Navigator.pop(ctx); onPick(items[i]); },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreatePlaylist(BuildContext context, WidgetRef ref, Color card, Color pri, Color tri, Color surface) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: card,
        title: Text('新建歌单', style: TextStyle(color: pri)),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          style: TextStyle(color: pri),
          decoration: InputDecoration(
            hintText: '歌单名称',
            hintStyle: TextStyle(color: tri),
            filled: true,
            fillColor: surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: tri)),
          ),
          TextButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isNotEmpty) {
                ref.read(playlistsProvider.notifier).createPlaylist(name);
                Navigator.pop(ctx);
              }
            },
            child: const Text('创建', style: TextStyle(color: YYColors.accentPrimary)),
          ),
        ],
      ),
    );
  }
}

// ──── Category Card ────
class _CategoryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;
  final int gradientIndex;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.icon, required this.title, required this.count,
    required this.gradientIndex, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pri = isDark ? YYColors.textPrimary : YYLightColors.textPrimary;
    final colors = YYColors.categoryGradients[gradientIndex % YYColors.categoryGradients.length];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 90,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [colors[0].withValues(alpha: 0.2), colors[1].withValues(alpha: 0.08)],
          ),
          borderRadius: BorderRadius.circular(YYRadius.md),
          border: Border.all(color: colors[0].withValues(alpha: 0.15), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: colors[0], size: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: TextStyle(color: pri, fontWeight: FontWeight.w600, fontSize: 15)),
                if (count > 0)
                  Text('$count', style: TextStyle(color: colors[0], fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ──── Playlist Tile ────
class _PlaylistTile extends StatelessWidget {
  final dynamic playlist;
  final VoidCallback onTap;
  const _PlaylistTile({required this.playlist, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? YYColors.bgElevated : YYLightColors.bgElevated;
    final pri = isDark ? YYColors.textPrimary : YYLightColors.textPrimary;
    final tri = isDark ? YYColors.textTertiary : YYLightColors.textTertiary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: YYSpacing.screenH, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(YYRadius.sm)),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(gradient: YYColors.accentGradient, borderRadius: BorderRadius.circular(10)),
              child: const Icon(CupertinoIcons.music_note_list, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(playlist.name, style: TextStyle(color: pri, fontWeight: FontWeight.w500, fontSize: 15)),
                  Text('${playlist.songIds.length} 首歌曲', style: TextStyle(color: tri, fontSize: 12)),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_forward, color: tri, size: 16),
          ],
        ),
      ),
    );
  }
}

// ──── Recent Play Tile ────
class _RecentPlayTile extends ConsumerWidget {
  final MusicItem song;
  const _RecentPlayTile({required this.song});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pri = isDark ? YYColors.textPrimary : YYLightColors.textPrimary;
    final tri = isDark ? YYColors.textTertiary : YYLightColors.textTertiary;

    return GestureDetector(
      onTap: () => ref.read(playerProvider.notifier).playSong(song),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: YYSpacing.screenH, vertical: 6),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(YYRadius.coverSmall),
              child: SizedBox(width: 40, height: 40, child: GradientCover(seed: song.title, coverUrl: song.coverUrl, size: 40)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(song.title, style: TextStyle(color: pri, fontWeight: FontWeight.w500, fontSize: 14),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(song.artist, style: TextStyle(color: tri, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
