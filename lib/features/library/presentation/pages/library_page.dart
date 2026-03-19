import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../app/theme/theme.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../providers/library_provider.dart';
import '../../../playlist/data/services/playlist_service.dart';
import '../../../playlist/presentation/pages/playlist_detail_page.dart';
import 'song_list_page.dart';

/// 音乐库页面 — 分类浏览
class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    final playlistsState = ref.watch(playlistsProvider);

    return Scaffold(
      backgroundColor: YYColors.bgBase,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            floating: true,
            title: const Text('音乐库',
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

                // 统计信息
                if (library.stats.songCount > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text(
                      '${library.stats.songCount} 首歌曲 · ${library.stats.artistCount} 位艺术家 · ${library.stats.albumCount} 张专辑',
                      style: const TextStyle(color: YYColors.textTertiary, fontSize: 13),
                    ),
                  ),

                // 分类网格
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.8,
                    children: [
                      _CategoryCard(
                        icon: CupertinoIcons.music_mic,
                        title: '艺术家',
                        count: library.artists.length,
                        gradient: const [Color(0xFF667EEA), Color(0xFF764BA2)],
                        onTap: () => _showArtistList(context, ref),
                      ).animate().fadeIn(delay: 100.ms),
                      _CategoryCard(
                        icon: CupertinoIcons.square_stack,
                        title: '专辑',
                        count: library.albums.length,
                        gradient: const [Color(0xFFF093FB), Color(0xFFF5576C)],
                        onTap: () => _showAlbumList(context, ref),
                      ).animate().fadeIn(delay: 150.ms),
                      _CategoryCard(
                        icon: CupertinoIcons.guitars,
                        title: '流派',
                        count: library.genres.length,
                        gradient: const [Color(0xFF4FACFE), Color(0xFF00F2FE)],
                        onTap: () => _showGenreList(context, ref),
                      ).animate().fadeIn(delay: 200.ms),
                      _CategoryCard(
                        icon: CupertinoIcons.music_note_list,
                        title: '全部歌曲',
                        count: library.stats.songCount,
                        gradient: const [Color(0xFF43E97B), Color(0xFF38F9D7)],
                        onTap: () => _showAllSongs(context, ref),
                      ).animate().fadeIn(delay: 250.ms),
                    ],
                  ),
                ),

                // 歌单
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('歌单', style: TextStyle(
                          color: YYColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                      GestureDetector(
                        onTap: () => _showCreatePlaylist(context, ref),
                        child: const Icon(CupertinoIcons.plus, color: YYColors.accentPrimary, size: 22),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (playlistsState.playlists.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Text('还没有歌单，点击 + 创建', style: TextStyle(color: YYColors.textTertiary, fontSize: 13)),
                  ),
                ...playlistsState.playlists.map((pl) => _PlaylistTile(
                  playlist: pl,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => PlaylistDetailPage(playlistId: pl.id),
                  )),
                )),

                // 最近播放
                if (library.recentPlays.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text('最近播放', style: TextStyle(
                        color: YYColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),
                  ...library.recentPlays.take(5).map((song) => _RecentPlayTile(song: song)),
                ],

                // 空状态
                if (library.stats.songCount == 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(CupertinoIcons.music_note_2, size: 48, color: YYColors.textTertiary),
                          SizedBox(height: 12),
                          Text('音乐库为空', style: TextStyle(color: YYColors.textSecondary, fontSize: 15)),
                          SizedBox(height: 4),
                          Text('添加数据源并扫描后这里会显示你的音乐',
                              style: TextStyle(color: YYColors.textTertiary, fontSize: 13)),
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
        type: SongListType.all,
        title: '全部歌曲',
        loadSongs: () => db.getAllSongs(),
      ),
    ));
  }

  void _showArtistList(BuildContext context, WidgetRef ref) {
    final library = ref.read(libraryProvider);
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _CategoryListPage(
        title: '艺术家',
        items: library.artists.map((a) => _CategoryListItem(
          title: a.name,
          subtitle: '${a.songCount} 首歌曲',
          onTap: () {
            final db = ref.read(musicDatabaseProvider);
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => SongListPage(
                type: SongListType.artist,
                title: a.name,
                subtitle: '${a.songCount} 首歌曲',
                loadSongs: () => db.getSongsByArtist(a.name),
              ),
            ));
          },
        )).toList(),
      ),
    ));
  }

  void _showAlbumList(BuildContext context, WidgetRef ref) {
    final library = ref.read(libraryProvider);
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _CategoryListPage(
        title: '专辑',
        items: library.albums.map((a) => _CategoryListItem(
          title: a.name,
          subtitle: '${a.artist} · ${a.songCount} 首',
          onTap: () {
            final db = ref.read(musicDatabaseProvider);
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => SongListPage(
                type: SongListType.album,
                title: a.name,
                subtitle: a.artist,
                loadSongs: () => db.getSongsByAlbum(a.name, a.artist),
              ),
            ));
          },
        )).toList(),
      ),
    ));
  }

  void _showGenreList(BuildContext context, WidgetRef ref) {
    final library = ref.read(libraryProvider);
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _CategoryListPage(
        title: '流派',
        items: library.genres.map((g) => _CategoryListItem(
          title: g.name,
          subtitle: '${g.songCount} 首歌曲',
          onTap: () {
            final db = ref.read(musicDatabaseProvider);
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => SongListPage(
                type: SongListType.genre,
                title: g.name,
                subtitle: '${g.songCount} 首歌曲',
                loadSongs: () => db.getSongsByGenre(g.name),
              ),
            ));
          },
        )).toList(),
      ),
    ));
  }

  void _showCreatePlaylist(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: YYColors.bgGlassThick,
        title: const Text('新建歌单', style: TextStyle(color: YYColors.textPrimary)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: YYColors.textPrimary),
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '歌单名称',
            hintStyle: TextStyle(color: YYColors.textTertiary),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref.read(playlistsProvider.notifier).createPlaylist(name);
                Navigator.pop(ctx);
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }
}

/// 歌单渐变色列表 (与 playlist_detail_page 共享)
const _plGradients = [
  [Color(0xFF667EEA), Color(0xFF764BA2)],
  [Color(0xFFF093FB), Color(0xFFF5576C)],
  [Color(0xFF4FACFE), Color(0xFF00F2FE)],
  [Color(0xFF43E97B), Color(0xFF38F9D7)],
  [Color(0xFFFA709A), Color(0xFFFEE140)],
  [Color(0xFFA18CD1), Color(0xFFFBC2EB)],
];

class _PlaylistTile extends StatelessWidget {
  final PlaylistEntity playlist;
  final VoidCallback onTap;
  const _PlaylistTile({required this.playlist, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = _plGradients[playlist.colorIndex % _plGradients.length];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors.map((c) => c.withValues(alpha: 0.35)).toList()),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(CupertinoIcons.music_note_list, color: colors[0], size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(playlist.name, style: const TextStyle(
                      color: YYColors.textPrimary, fontWeight: FontWeight.w500, fontSize: 15)),
                  Text('${playlist.songIds.length} 首歌曲', style: const TextStyle(
                      color: YYColors.textTertiary, fontSize: 12)),
                ],
              ),
            ),
            const Icon(CupertinoIcons.chevron_forward, color: YYColors.textTertiary, size: 16),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.icon,
    required this.title,
    required this.count,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient.map((c) => c.withValues(alpha: 0.25)).toList(),
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: gradient[0].withValues(alpha: 0.15), width: 0.5),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: gradient[0], size: 26),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(
                    color: YYColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
                Text('$count', style: TextStyle(
                    color: gradient[0], fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentPlayTile extends StatelessWidget {
  final dynamic song;
  const _RecentPlayTile({required this.song});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          const Icon(CupertinoIcons.time, color: YYColors.textTertiary, size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Text('${song.title} - ${song.artist}',
                style: const TextStyle(color: YYColors.textSecondary, fontSize: 14),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

// ---- 分类列表子页面 ----

class _CategoryListItem {
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _CategoryListItem({required this.title, required this.subtitle, required this.onTap});
}

class _CategoryListPage extends StatelessWidget {
  final String title;
  final List<_CategoryListItem> items;

  const _CategoryListPage({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: YYColors.bgBase,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.transparent,
        foregroundColor: YYColors.textPrimary,
      ),
      body: ListView.builder(
        itemCount: items.length,
        padding: const EdgeInsets.only(bottom: 100),
        itemBuilder: (context, index) {
          final item = items[index];
          return ListTile(
            title: Text(item.title, style: const TextStyle(color: YYColors.textPrimary)),
            subtitle: Text(item.subtitle, style: const TextStyle(color: YYColors.textTertiary, fontSize: 12)),
            trailing: const Icon(CupertinoIcons.chevron_forward, color: YYColors.textTertiary, size: 16),
            onTap: item.onTap,
          );
        },
      ),
    );
  }
}
