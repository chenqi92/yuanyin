import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/theme.dart';
import '../../../../shared/services/shell_navigation_visibility.dart';
import '../../../../shared/widgets/gradient_cover.dart';
import '../../../../shared/widgets/native_overlay_sheet.dart';
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

/// Playlist detail page -- iOS native style with reorder
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
    if (playlist == null) {
      if (!mounted) return;
      Navigator.pop(context);
      return;
    }
    final allSongs = await db.getAllSongs();
    final songMap = {for (final s in allSongs) s.id: s};
    final songs = playlist.songIds
        .where((id) => songMap.containsKey(id))
        .map((id) => songMap[id]!)
        .toList();
    if (mounted) {
      setState(() {
        _playlist = playlist;
        _songs = songs;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _playlist == null) {
      return CupertinoPageScaffold(
        backgroundColor: context.yyBgBase,
        child: const Center(child: CupertinoActivityIndicator(radius: 14)),
      );
    }

    final playlist = _playlist!;
    final colors =
        _playlistGradients[playlist.colorIndex % _playlistGradients.length];
    final playerState = ref.watch(playerProvider);

    return CupertinoPageScaffold(
      backgroundColor: context.yyBgBase,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: context.yyBgBase.withValues(alpha: 0.9),
        border: Border(
          bottom: BorderSide(color: context.yySeparator, width: 0.5),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          child: Icon(
            CupertinoIcons.chevron_back,
            color: YYColors.accentPrimary,
            size: 22,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        middle: Text(
          playlist.name,
          style: TextStyle(
            color: context.yyTextPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: () => setState(() => _isReordering = !_isReordering),
              child: Icon(
                _isReordering
                    ? CupertinoIcons.checkmark
                    : CupertinoIcons.arrow_up_arrow_down,
                color: _isReordering
                    ? YYColors.accentPrimary
                    : context.yyTextSecondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: () => _showOptions(context),
              child: Icon(
                CupertinoIcons.ellipsis,
                color: context.yyTextSecondary,
                size: 22,
              ),
            ),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            // Header with gradient
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors
                        .map((c) => c.withValues(alpha: 0.25))
                        .toList(),
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.music_note_list,
                      size: 40,
                      color: colors[0].withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_songs.length} 首歌曲',
                            style: TextStyle(
                              color: context.yyTextSecondary,
                              fontSize: 14,
                            ),
                          ),
                          if (_isReordering)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '拖拽排序中',
                                style: TextStyle(
                                  color: YYColors.accentPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_songs.isNotEmpty && !_isReordering)
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        color: YYColors.accentPrimary,
                        borderRadius: BorderRadius.circular(18),
                        onPressed: () => ref
                            .read(playerProvider.notifier)
                            .playSong(_songs.first, queue: _songs),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.play_fill,
                              size: 14,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '播放',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Empty state
            if (_songs.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    '歌单是空的\n从歌曲列表添加歌曲到这里',
                    style: TextStyle(
                      color: context.yyTextTertiary,
                      fontSize: 15,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

            // Reorder mode
            if (_isReordering && _songs.isNotEmpty)
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
                      onTap: () => ref
                          .read(playerProvider.notifier)
                          .playSong(song, queue: _songs),
                      onLongPress: () => showSongActions(
                        context,
                        ref,
                        song,
                        playlistId: widget.playlistId,
                      ),
                    ),
                  );
                },
              ),

            // Normal list
            if (!_isReordering && _songs.isNotEmpty)
              SliverPadding(
                padding: EdgeInsets.only(
                  bottom: YYSizes.bottomInset(context, hasMiniPlayer: false),
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final song = _songs[index];
                    final isPlaying = playerState.currentSong?.id == song.id;
                    return _SongTile(
                      key: ValueKey(song.id),
                      song: song,
                      index: index,
                      isPlaying: isPlaying,
                      showDragHandle: false,
                      onTap: () => ref
                          .read(playerProvider.notifier)
                          .playSong(song, queue: _songs),
                      onLongPress: () => showSongActions(
                        context,
                        ref,
                        song,
                        playlistId: widget.playlistId,
                      ),
                    );
                  }, childCount: _songs.length),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _songs.removeAt(oldIndex);
      _songs.insert(newIndex, item);
    });
    ref
        .read(playlistsProvider.notifier)
        .reorderSongs(
          widget.playlistId,
          oldIndex,
          oldIndex < newIndex ? newIndex + 1 : newIndex,
        );
  }

  void _showOptions(BuildContext context) {
    showYYNativeCupertinoPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _renamePlaylist();
            },
            child: const Text('重命名'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _exportPlaylist();
            },
            child: const Text('导出为 M3U'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(playlistsProvider.notifier)
                  .deletePlaylist(widget.playlistId);
              Navigator.pop(context);
            },
            child: const Text('删除歌单'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
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
          SnackBar(
            content: Text('导出失败: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _renamePlaylist() {
    final controller = TextEditingController(text: _playlist?.name ?? '');
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('重命名歌单'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            placeholder: '歌单名称',
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: false,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref
                    .read(playlistsProvider.notifier)
                    .renamePlaylist(widget.playlistId, name);
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

/// Song tile
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        color: context.yyBgBase, // Required for reorderable background
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Row(
          children: [
            if (showDragHandle)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(
                  CupertinoIcons.line_horizontal_3,
                  size: 18,
                  color: context.yyTextTertiary,
                ),
              )
            else
              SizedBox(
                width: 24,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: isPlaying
                        ? YYColors.accentPrimary
                        : context.yyTextTertiary,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 44,
                height: 44,
                child: GradientCover(
                  seed: song.title,
                  coverUrl: song.coverUrl,
                  filePath: song.filePath,
                  size: 44,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    style: TextStyle(
                      color: isPlaying
                          ? YYColors.accentPrimary
                          : context.yyTextPrimary,
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.artist,
                    style: TextStyle(
                      color: context.yyTextSecondary,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text(
              song.durationText,
              style: TextStyle(color: context.yyTextTertiary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
