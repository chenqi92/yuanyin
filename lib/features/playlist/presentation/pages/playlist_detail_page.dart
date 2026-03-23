import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../app/theme/theme.dart';
import '../../../../shared/services/shell_navigation_visibility.dart';
import '../../../../shared/widgets/gradient_cover.dart';
import '../../../../shared/widgets/song_actions_sheet.dart';
import '../../../player/domain/entities/music_item.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../library/presentation/providers/library_provider.dart';
import '../../data/services/playlist_service.dart';
import '../../data/services/playlist_io_service.dart';

const _playlistGradients = [
  [Color(0xFF667EEA), Color(0xFF764BA2)],
  [Color(0xFFF093FB), Color(0xFFF5576C)],
  [Color(0xFF4FACFE), Color(0xFF00F2FE)],
  [Color(0xFF43E97B), Color(0xFF38F9D7)],
  [Color(0xFFFA709A), Color(0xFFFEE140)],
  [Color(0xFFA18CD1), Color(0xFFFBC2EB)],
  [Color(0xFFFCB69F), Color(0xFFFFCDA5)],
  [Color(0xFF89F7FE), Color(0xFF66A6FF)],
];

/// 歌单详情页 — 自适应亮暗主题 + 拖拽排序
class PlaylistDetailPage extends ConsumerStatefulWidget {
  final String playlistId;
  const PlaylistDetailPage({super.key, required this.playlistId});

  @override
  ConsumerState<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends ConsumerState<PlaylistDetailPage>
    with ConsumerShellNavigationVisibilityMixin {
  PlaylistEntity? _playlist;
  List<MusicItem> _songs = [];
  bool _isLoading = true;
  bool _isReordering = false;

  @override
  void initState() {
    super.initState();
    hideShellNavigation();
    _load();
  }

  Future<void> _load() async {
    final service = ref.read(playlistServiceProvider);
    final db = ref.read(musicDatabaseProvider);
    final playlist = await service.getById(widget.playlistId);
    if (playlist == null) { Navigator.pop(context); return; }
    final allSongs = await db.getAllSongs();
    final songMap = {for (final s in allSongs) s.id: s};
    final songs = playlist.songIds.where((id) => songMap.containsKey(id)).map((id) => songMap[id]!).toList();
    if (mounted) setState(() { _playlist = playlist; _songs = songs; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _playlist == null) {
      return Scaffold(
        backgroundColor: context.yyBgBase,
        body: const Center(child: CircularProgressIndicator(color: YYColors.accentPrimary)),
      );
    }

    final playlist = _playlist!;
    final colors = _playlistGradients[playlist.colorIndex % _playlistGradients.length];
    final playerState = ref.watch(playerProvider);

    return Scaffold(
      backgroundColor: context.yyBgBase,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: context.yyTextPrimary,
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(playlist.name, style: TextStyle(color: context.yyTextPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: colors.map((c) => c.withValues(alpha: 0.3)).toList(),
                  ),
                ),
                child: Center(child: Icon(CupertinoIcons.music_note_list, size: 64, color: colors[0].withValues(alpha: 0.5))),
              ),
            ),
            actions: [
              if (_songs.isNotEmpty)
                IconButton(
                  icon: const Icon(CupertinoIcons.play_circle, size: 28),
                  onPressed: () => ref.read(playerProvider.notifier).playSong(_songs.first, queue: _songs),
                ),
              // 排序切换按钮
              IconButton(
                icon: Icon(
                  _isReordering ? CupertinoIcons.checkmark : CupertinoIcons.arrow_up_arrow_down,
                  size: 20,
                ),
                onPressed: () => setState(() => _isReordering = !_isReordering),
              ),
              IconButton(
                icon: const Icon(CupertinoIcons.ellipsis, size: 22),
                onPressed: () => _showOptions(context),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text('${_songs.length} 首歌曲', style: TextStyle(color: context.yyTextTertiary, fontSize: 13)),
                  if (_isReordering) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: YYColors.accentPrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('拖拽排序中', style: TextStyle(
                        color: YYColors.accentPrimary, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_songs.isEmpty)
            SliverFillRemaining(
              child: Center(child: Text('歌单是空的\n从歌曲列表添加歌曲到这里',
                  style: TextStyle(color: context.yyTextTertiary, fontSize: 14), textAlign: TextAlign.center)),
            ),
          if (_isReordering)
            SliverReorderableList(
              itemCount: _songs.length,
              onReorder: _onReorder,
              itemBuilder: (context, index) {
                final song = _songs[index];
                final isPlaying = playerState.currentSong?.id == song.id;
                return ReorderableDragStartListener(
                  key: ValueKey(song.id),
                  index: index,
                  child: _SongTile(
                    song: song,
                    index: index,
                    isPlaying: isPlaying,
                    showDragHandle: true,
                    onTap: () => ref.read(playerProvider.notifier).playSong(song, queue: _songs),
                    onLongPress: () => showSongActions(context, ref, song, playlistId: widget.playlistId),
                  ),
                );
              },
            )
          else
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 28),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final song = _songs[index];
                    final isPlaying = playerState.currentSong?.id == song.id;
                    return _SongTile(
                      key: ValueKey(song.id),
                      song: song,
                      index: index,
                      isPlaying: isPlaying,
                      showDragHandle: false,
                      onTap: () => ref.read(playerProvider.notifier).playSong(song, queue: _songs),
                      onLongPress: () => showSongActions(context, ref, song, playlistId: widget.playlistId),
                    ).animate().fadeIn(delay: (30 * index).ms, duration: 300.ms);
                  },
                  childCount: _songs.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _songs.removeAt(oldIndex);
      _songs.insert(newIndex, item);
    });
    // 异步持久化（+1 因为 ReorderableListView 的 convention）
    ref.read(playlistsProvider.notifier).reorderSongs(
      widget.playlistId,
      oldIndex,
      oldIndex < newIndex ? newIndex + 1 : newIndex,
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: context.yyBgElevated,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(CupertinoIcons.pencil, color: context.yyTextPrimary),
              title: Text('重命名', style: TextStyle(color: context.yyTextPrimary)),
              onTap: () { Navigator.pop(context); _renamePlaylist(); },
            ),
            ListTile(
              leading: Icon(CupertinoIcons.share, color: context.yyTextPrimary),
              title: Text('导出为 M3U', style: TextStyle(color: context.yyTextPrimary)),
              onTap: () {
                Navigator.pop(context);
                _exportPlaylist();
              },
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.delete, color: Colors.redAccent),
              title: const Text('删除歌单', style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(context);
                ref.read(playlistsProvider.notifier).deletePlaylist(widget.playlistId);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportPlaylist() async {
    if (_playlist == null || _songs.isEmpty) return;
    try {
      final io = PlaylistIOService();
      final filePath = await io.exportToM3U(_playlist!, _songs);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('歌单已导出到: $filePath'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  void _renamePlaylist() {
    final controller = TextEditingController(text: _playlist?.name ?? '');
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.yyBgElevated,
        title: Text('重命名歌单', style: TextStyle(color: context.yyTextPrimary)),
        content: TextField(
          controller: controller,
          style: TextStyle(color: context.yyTextPrimary),
          autofocus: true,
          decoration: InputDecoration(hintText: '歌单名称', hintStyle: TextStyle(color: context.yyTextTertiary)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref.read(playlistsProvider.notifier).renamePlaylist(widget.playlistId, name);
                Navigator.pop(ctx);
                _load();
              }
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }
}

/// 歌曲条目
class _SongTile extends StatelessWidget {
  final MusicItem song;
  final int index;
  final bool isPlaying;
  final bool showDragHandle;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _SongTile({
    super.key,
    required this.song,
    required this.index,
    required this.isPlaying,
    required this.showDragHandle,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              if (showDragHandle)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Icon(CupertinoIcons.line_horizontal_3, size: 18, color: context.yyTextTertiary),
                )
              else
                SizedBox(
                  width: 24,
                  child: Text('${index + 1}', style: TextStyle(
                      color: isPlaying ? YYColors.accentPrimary : context.yyTextTertiary, fontSize: 14),
                      textAlign: TextAlign.center),
                ),
              const SizedBox(width: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(width: 44, height: 44, child: GradientCover(seed: song.title, coverUrl: song.coverUrl, size: 44)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(song.title, style: TextStyle(
                        color: isPlaying ? YYColors.accentPrimary : context.yyTextPrimary,
                        fontWeight: FontWeight.w500, fontSize: 15),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(song.artist, style: TextStyle(color: context.yyTextSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Text(song.durationText, style: TextStyle(color: context.yyTextTertiary, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
