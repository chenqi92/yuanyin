import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../app/theme/theme.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../../../shared/widgets/gradient_cover.dart';
import '../../../player/domain/entities/music_item.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../library/data/services/music_database_service.dart';
import '../../../library/presentation/providers/library_provider.dart';
import '../../data/services/playlist_service.dart';

/// 歌单渐变色列表
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

/// 歌单详情页
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
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = ref.read(playlistServiceProvider);
    final db = ref.read(musicDatabaseProvider);
    final playlist = await service.getById(widget.playlistId);
    if (playlist == null) { Navigator.pop(context); return; }

    final allSongs = await db.getAllSongs();
    final songMap = {for (final s in allSongs) s.id: s};
    final songs = playlist.songIds
        .where((id) => songMap.containsKey(id))
        .map((id) => songMap[id]!)
        .toList();

    if (mounted) setState(() { _playlist = playlist; _songs = songs; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _playlist == null) {
      return const Scaffold(
        backgroundColor: YYColors.bgBase,
        body: Center(child: CircularProgressIndicator(color: YYColors.accentPrimary)),
      );
    }

    final playlist = _playlist!;
    final colors = _playlistGradients[playlist.colorIndex % _playlistGradients.length];
    final playerState = ref.watch(playerProvider);

    return Scaffold(
      backgroundColor: YYColors.bgBase,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: YYColors.textPrimary,
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(playlist.name, style: const TextStyle(
                  color: YYColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors.map((c) => c.withValues(alpha: 0.3)).toList(),
                  ),
                ),
                child: Center(
                  child: Icon(CupertinoIcons.music_note_list,
                      size: 64, color: colors[0].withValues(alpha: 0.5)),
                ),
              ),
            ),
            actions: [
              if (_songs.isNotEmpty)
                IconButton(
                  icon: const Icon(CupertinoIcons.play_circle, size: 28),
                  onPressed: () {
                    ref.read(playerProvider.notifier).playSong(_songs.first, queue: _songs);
                  },
                ),
              IconButton(
                icon: const Icon(CupertinoIcons.ellipsis, size: 22),
                onPressed: () => _showOptions(context),
              ),
            ],
          ),

          // 歌曲数
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text('${_songs.length} 首歌曲',
                  style: const TextStyle(color: YYColors.textTertiary, fontSize: 13)),
            ),
          ),

          // 空状态
          if (_songs.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text('歌单是空的\n从歌曲列表添加歌曲到这里',
                    style: TextStyle(color: YYColors.textTertiary, fontSize: 14),
                    textAlign: TextAlign.center),
              ),
            ),

          // 歌曲列表
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final song = _songs[index];
                  final isPlaying = playerState.currentSong?.id == song.id;
                  return GestureDetector(
                    onTap: () => ref.read(playerProvider.notifier).playSong(song, queue: _songs),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Row(
                        children: [
                          Text('${index + 1}', style: TextStyle(
                              color: isPlaying ? YYColors.accentPrimary : YYColors.textTertiary, fontSize: 14),
                              textAlign: TextAlign.center),
                          const SizedBox(width: 14),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox(width: 44, height: 44,
                                child: GradientCover(seed: song.title, size: 44)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(song.title, style: TextStyle(
                                    color: isPlaying ? YYColors.accentPrimary : YYColors.textPrimary,
                                    fontWeight: FontWeight.w500, fontSize: 15),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text(song.artist, style: const TextStyle(
                                    color: YYColors.textSecondary, fontSize: 12)),
                              ],
                            ),
                          ),
                          Text(song.durationText, style: const TextStyle(
                              color: YYColors.textTertiary, fontSize: 12)),
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

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: YYColors.bgGlassThick,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(CupertinoIcons.pencil, color: YYColors.textPrimary),
              title: const Text('重命名', style: TextStyle(color: YYColors.textPrimary)),
              onTap: () { Navigator.pop(context); _renamePlaylist(); },
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

  void _renamePlaylist() {
    final controller = TextEditingController(text: _playlist?.name ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: YYColors.bgGlassThick,
        title: const Text('重命名歌单', style: TextStyle(color: YYColors.textPrimary)),
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
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
