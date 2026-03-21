import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/theme.dart';
import '../../../../shared/widgets/modern_music_ui.dart';
import '../../../player/domain/entities/music_item.dart';
import '../../../player/presentation/providers/player_provider.dart';
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
      body: YYScenicBackground(
        accent: YYColors.accentTertiary,
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 28),
            children: [
              YYPageHeader(
                eyebrow: '内容总览',
                title: '音乐库',
                subtitle: library.stats.songCount == 0
                    ? null
                    : '${library.stats.songCount} 首歌曲',
                trailing: YYHeaderActionButton(
                  icon: CupertinoIcons.plus,
                  onTap: () => _showCreatePlaylist(
                    context,
                    ref,
                    context.yyBgElevated,
                    context.yyTextPrimary,
                    context.yyTextTertiary,
                    context.yyBgSurface,
                  ),
                ),
              ),
              _OverviewCard(library: library),
              const YYSectionTitle(title: '分类浏览'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _CategoryCard(
                            title: '艺术家',
                            subtitle: '按创作者进入',
                            count: library.artists.length,
                            icon: CupertinoIcons.music_mic,
                            colors: const [
                              Color(0xFFF59E0B),
                              Color(0xFFF97316),
                            ],
                            onTap: () => _showArtistList(
                              context,
                              ref,
                              context.yyBgElevated,
                              context.yyTextPrimary,
                              context.yyTextTertiary,
                              context.yySeparator,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _CategoryCard(
                            title: '专辑',
                            subtitle: '按发行归档浏览',
                            count: library.albums.length,
                            icon: CupertinoIcons.square_stack_3d_up_fill,
                            colors: const [
                              Color(0xFF22C7B8),
                              Color(0xFF0EA5E9),
                            ],
                            onTap: () => _showAlbumList(
                              context,
                              ref,
                              context.yyBgElevated,
                              context.yyTextPrimary,
                              context.yyTextTertiary,
                              context.yySeparator,
                            ),
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
                            subtitle: '按风格快速过滤',
                            count: library.genres.length,
                            icon: CupertinoIcons.guitars,
                            colors: const [
                              Color(0xFF8B5CF6),
                              Color(0xFFEC4899),
                            ],
                            onTap: () => _showGenreList(
                              context,
                              ref,
                              context.yyBgElevated,
                              context.yyTextPrimary,
                              context.yyTextTertiary,
                              context.yySeparator,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _CategoryCard(
                            title: '全部歌曲',
                            subtitle: '完整曲库列表',
                            count: library.stats.songCount,
                            icon: CupertinoIcons.music_note_list,
                            colors: const [
                              Color(0xFF34D399),
                              Color(0xFF22C7B8),
                            ],
                            onTap: () => _showAllSongs(context, ref),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              YYSectionTitle(
                title: '你的歌单',
                trailing: YYPillButton(
                  label: '新建',
                  compact: true,
                  onTap: () => _showCreatePlaylist(
                    context,
                    ref,
                    context.yyBgElevated,
                    context.yyTextPrimary,
                    context.yyTextTertiary,
                    context.yyBgSurface,
                  ),
                ),
              ),
              if (playlists.playlists.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: YYPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const YYIconBadge(
                              icon: CupertinoIcons.music_note_list,
                              color: YYColors.accentSecondary,
                              size: 48,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '还没有歌单',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '创建歌单来整理你的音乐',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        YYPillButton(
                          label: '创建第一张歌单',
                          icon: CupertinoIcons.plus,
                          primary: true,
                          onTap: () => _showCreatePlaylist(
                            context,
                            ref,
                            context.yyBgElevated,
                            context.yyTextPrimary,
                            context.yyTextTertiary,
                            context.yyBgSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ...playlists.playlists.map((playlist) {
                return _PlaylistCard(
                  title: playlist.name,
                  count: playlist.songIds.length,
                  colorIndex: playlist.colorIndex,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PlaylistDetailPage(playlistId: playlist.id),
                    ),
                  ),
                );
              }),
              if (library.recentPlays.isNotEmpty) ...[
                const YYSectionTitle(title: '最近播放'),
                ...library.recentPlays.take(6).map((song) {
                  return YYTrackRow(
                    song: song,
                    active:
                        ref.watch(playerProvider).currentSong?.id == song.id,
                    onTap: () => ref
                        .read(playerProvider.notifier)
                        .playSong(song, queue: library.recentPlays),
                  );
                }),
              ],
            ],
          ),
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

  void _showArtistList(
    BuildContext context,
    WidgetRef ref,
    Color card,
    Color pri,
    Color tri,
    Color sep,
  ) {
    final artists = ref.read(libraryProvider).artists;
    _showPickerSheet(
      context,
      '选择艺术家',
      artists.map((item) => item.name).toList(),
      card,
      pri,
      tri,
      sep,
      (name) {
        final db = ref.read(musicDatabaseProvider);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SongListPage(
              type: SongListType.artist,
              title: name,
              subtitle: '艺术家',
              loadSongs: () => db.getSongsByArtist(name),
            ),
          ),
        );
      },
    );
  }

  void _showAlbumList(
    BuildContext context,
    WidgetRef ref,
    Color card,
    Color pri,
    Color tri,
    Color sep,
  ) {
    final albums = ref.read(libraryProvider).albums;
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PickerSheet(
        title: '选择专辑',
        card: card,
        pri: pri,
        tri: tri,
        sep: sep,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: albums.length,
          itemBuilder: (_, index) {
            final album = albums[index];
            return ListTile(
              title: Text(
                album.name,
                style: TextStyle(color: pri, fontWeight: FontWeight.w700),
              ),
              subtitle: Text(album.artist, style: TextStyle(color: tri)),
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
                      loadSongs: () =>
                          db.getSongsByAlbum(album.name, album.artist),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showGenreList(
    BuildContext context,
    WidgetRef ref,
    Color card,
    Color pri,
    Color tri,
    Color sep,
  ) {
    final genres = ref.read(libraryProvider).genres;
    _showPickerSheet(
      context,
      '选择流派',
      genres.map((item) => item.name).toList(),
      card,
      pri,
      tri,
      sep,
      (name) {
        final db = ref.read(musicDatabaseProvider);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SongListPage(
              type: SongListType.genre,
              title: name,
              subtitle: '流派',
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
    Color card,
    Color pri,
    Color tri,
    Color sep,
    void Function(String) onPick,
  ) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PickerSheet(
        title: title,
        card: card,
        pri: pri,
        tri: tri,
        sep: sep,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: items.length,
          itemBuilder: (_, index) {
            final item = items[index];
            return ListTile(
              title: Text(
                item,
                style: TextStyle(color: pri, fontWeight: FontWeight.w700),
              ),
              onTap: () {
                Navigator.pop(ctx);
                onPick(item);
              },
            );
          },
        ),
      ),
    );
  }

  void _showCreatePlaylist(
    BuildContext context,
    WidgetRef ref,
    Color card,
    Color pri,
    Color tri,
    Color surface,
  ) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      useRootNavigator: true,
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
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
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

class _OverviewCard extends ConsumerWidget {
  final LibraryState library;

  const _OverviewCard({required this.library});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: YYPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('曲库概览', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            if (library.stats.songCount == 0)
              Text(
                '导入音乐后显示统计信息',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: 16),
            YYMetricBand(
              items: [
                YYMetricBandItem(
                  label: '歌曲',
                  value: '${library.stats.songCount}',
                  tint: YYColors.accentPrimary,
                ),
                YYMetricBandItem(
                  label: '艺术家',
                  value: '${library.artists.length}',
                  tint: YYColors.accentSecondary,
                ),
                YYMetricBandItem(
                  label: '专辑',
                  value: '${library.albums.length}',
                  tint: YYColors.accentTertiary,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: YYPillButton(
                    label: '全部播放',
                    icon: CupertinoIcons.play_fill,
                    primary: true,
                    onTap: () {
                      if (library.allSongs.isNotEmpty) {
                        ref
                            .read(playerProvider.notifier)
                            .playSong(
                              library.allSongs.first,
                              queue: library.allSongs,
                            );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: YYPillButton(
                    label: '随机来一组',
                    icon: CupertinoIcons.shuffle,
                    onTap: () {
                      final queue = List<MusicItem>.from(library.allSongs)
                        ..shuffle();
                      if (queue.isNotEmpty) {
                        ref
                            .read(playerProvider.notifier)
                            .playSong(queue.first, queue: queue);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final int count;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tone = colors.first;
    return YYPanel(
      color: tone.withValues(alpha: context.isDark ? 0.07 : 0.05),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              YYIconBadge(icon: icon, color: colors.first, size: 40),
              const Spacer(),
              Icon(
                Icons.arrow_outward_rounded,
                size: 16,
                color: context.yyTextTertiary,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: TextStyle(
              color: context.yyTextPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  final String title;
  final int count;
  final int colorIndex;
  final VoidCallback onTap;

  const _PlaylistCard({
    required this.title,
    required this.count,
    required this.colorIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = YYColors
        .categoryGradients[colorIndex % YYColors.categoryGradients.length];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: YYPanel(
        color: palette.first.withValues(alpha: context.isDark ? 0.08 : 0.06),
        onTap: onTap,
        child: Row(
          children: [
            YYIconBadge(
              icon: CupertinoIcons.music_note_list,
              color: palette.first,
              size: 42,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    count == 0 ? '空歌单' : '$count 首歌曲',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: context.yyBgSurface.withValues(
                  alpha: context.isDark ? 0.64 : 0.9,
                ),
                borderRadius: BorderRadius.circular(YYRadius.full),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: context.yyTextPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerSheet extends StatelessWidget {
  final String title;
  final Color card;
  final Color pri;
  final Color tri;
  final Color sep;
  final Widget child;

  const _PickerSheet({
    required this.title,
    required this.card,
    required this.pri,
    required this.tri,
    required this.sep,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(YYRadius.bottomSheet),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: tri.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(YYRadius.full),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: TextStyle(
                  color: pri,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: sep),
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
