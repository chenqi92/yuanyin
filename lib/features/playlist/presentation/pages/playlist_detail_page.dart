import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../app/theme/theme.dart';
import '../../../../shared/widgets/gradient_cover.dart';
import '../../../../shared/widgets/song_actions_sheet.dart';
import '../../../player/domain/entities/music_item.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../library/data/services/music_database_service.dart';
import '../../../library/presentation/providers/library_provider.dart';
import '../../data/services/playlist_service.dart';

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

/// 歌单详情页 — 自适应亮暗主题
class PlaylistDetailPage extends ConsumerStatefulWidget {
  final String playlistId;
  const PlaylistDetailPage({super.key, required this.playlistId});

  @override
  ConsumerState<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends ConsumerState<PlaylistDetailPage> {
  PlaylistEntity? _playlist;
  List<MusicItem> _songs = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _load(); }

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? YYColors.bgBase : YYLightColors.bgBase;
    final card = isDark ? YYColors.bgElevated : YYLightColors.bgElevated;
    final pri = isDark ? YYColors.textPrimary : YYLightColors.textPrimary;
    final sub = isDark ? YYColors.textSecondary : YYLightColors.textSecondary;
    final tri = isDark ? YYColors.textTertiary : YYLightColors.textTertiary;

    if (_isLoading || _playlist == null) {
      return Scaffold(
        backgroundColor: bg,
        body: const Center(child: CircularProgressIndicator(color: YYColors.accentPrimary)),
      );
    }

    final playlist = _playlist!;
    final colors = _playlistGradients[playlist.colorIndex % _playlistGradients.length];
    final playerState = ref.watch(playerProvider);

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: pri,
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(playlist.name, style: TextStyle(color: pri, fontWeight: FontWeight.bold, fontSize: 18)),
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
              IconButton(
                icon: const Icon(CupertinoIcons.ellipsis, size: 22),
                onPressed: () => _showOptions(context, card, pri),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text('${_songs.length} 首歌曲', style: TextStyle(color: tri, fontSize: 13)),
            ),
          ),
          if (_songs.isEmpty)
            SliverFillRemaining(
              child: Center(child: Text('歌单是空的\n从歌曲列表添加歌曲到这里',
                  style: TextStyle(color: tri, fontSize: 14), textAlign: TextAlign.center)),
            ),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final song = _songs[index];
                  final isPlaying = playerState.currentSong?.id == song.id;
                  return GestureDetector(
                    onTap: () => ref.read(playerProvider.notifier).playSong(song, queue: _songs),
                    onLongPress: () => showSongActions(context, ref, song, playlistId: widget.playlistId),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Row(
                        children: [
                          Text('${index + 1}', style: TextStyle(
                              color: isPlaying ? YYColors.accentPrimary : tri, fontSize: 14),
                              textAlign: TextAlign.center),
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
                                    color: isPlaying ? YYColors.accentPrimary : pri,
                                    fontWeight: FontWeight.w500, fontSize: 15),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text(song.artist, style: TextStyle(color: sub, fontSize: 12)),
                              ],
                            ),
                          ),
                          Text(song.durationText, style: TextStyle(color: tri, fontSize: 12)),
                        ],
                      ),
                    ),
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

  void _showOptions(BuildContext context, Color card, Color pri) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tri = isDark ? YYColors.textTertiary : YYLightColors.textTertiary;
    showModalBottomSheet(
      context: context,
      backgroundColor: card,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(CupertinoIcons.pencil, color: pri),
              title: Text('重命名', style: TextStyle(color: pri)),
              onTap: () { Navigator.pop(context); _renamePlaylist(card, pri, tri); },
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

  void _renamePlaylist(Color card, Color pri, Color tri) {
    final controller = TextEditingController(text: _playlist?.name ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: card,
        title: Text('重命名歌单', style: TextStyle(color: pri)),
        content: TextField(
          controller: controller,
          style: TextStyle(color: pri),
          autofocus: true,
          decoration: InputDecoration(hintText: '歌单名称', hintStyle: TextStyle(color: tri)),
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
