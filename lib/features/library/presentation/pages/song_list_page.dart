import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../app/theme/theme.dart';
import '../../../../shared/widgets/gradient_cover.dart';
import '../../../../shared/widgets/song_actions_sheet.dart';
import '../../../player/domain/entities/music_item.dart';
import '../../../player/presentation/providers/player_provider.dart';

/// 分类类型
enum SongListType { artist, album, genre, all }

/// 排序模式
enum _SortMode { original, title, artist, duration }

/// 歌曲列表页 — 自适应亮暗主题
class SongListPage extends ConsumerStatefulWidget {
  final SongListType type;
  final String title;
  final String? subtitle;
  final Future<List<MusicItem>> Function() loadSongs;

  const SongListPage({
    super.key,
    required this.type,
    required this.title,
    this.subtitle,
    required this.loadSongs,
  });

  @override
  ConsumerState<SongListPage> createState() => _SongListPageState();
}

class _SongListPageState extends ConsumerState<SongListPage> {
  List<MusicItem> _songs = [];
  bool _isLoading = true;
  _SortMode _sortMode = _SortMode.original;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final songs = await widget.loadSongs();
    if (mounted) setState(() { _songs = songs; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? YYColors.bgBase : YYLightColors.bgBase;
    final pri = isDark ? YYColors.textPrimary : YYLightColors.textPrimary;
    final sub = isDark ? YYColors.textSecondary : YYLightColors.textSecondary;
    final tri = isDark ? YYColors.textTertiary : YYLightColors.textTertiary;
    final card = isDark ? YYColors.bgElevated : YYLightColors.bgElevated;

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: pri,
            expandedHeight: 140,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(widget.title, style: TextStyle(
                  color: pri, fontWeight: FontWeight.bold, fontSize: 18)),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [YYColors.accentPrimary.withValues(alpha: 0.15), bg],
                  ),
                ),
              ),
            ),
            actions: [
              if (_songs.isNotEmpty)
                PopupMenuButton<_SortMode>(
                  icon: const Icon(CupertinoIcons.sort_down, size: 22),
                  color: card,
                  onSelected: (mode) {
                    setState(() { _sortMode = mode; _applySorting(); });
                  },
                  itemBuilder: (_) => [
                    _sortMenuItem(_SortMode.original, '默认顺序', pri),
                    _sortMenuItem(_SortMode.title, '按标题', pri),
                    _sortMenuItem(_SortMode.artist, '按艺术家', pri),
                    _sortMenuItem(_SortMode.duration, '按时长', pri),
                  ],
                ),
              if (_songs.isNotEmpty)
                IconButton(
                  icon: const Icon(CupertinoIcons.play_circle, size: 28),
                  onPressed: () => ref.read(playerProvider.notifier).playSong(_songs.first, queue: _songs),
                ),
            ],
          ),
          if (widget.subtitle != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text('${_songs.length} 首歌曲 · ${widget.subtitle}',
                    style: TextStyle(color: tri, fontSize: 13)),
              ),
            ),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: YYColors.accentPrimary)),
            ),
          if (!_isLoading)
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 160),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final song = _songs[index];
                    final isPlaying = playerState.currentSong?.id == song.id;
                    return _SongRow(song: song, index: index + 1, isPlaying: isPlaying,
                      onTap: () => ref.read(playerProvider.notifier).playSong(song, queue: _songs),
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

  PopupMenuItem<_SortMode> _sortMenuItem(_SortMode mode, String label, Color textColor) {
    return PopupMenuItem(
      value: mode,
      child: Row(
        children: [
          if (_sortMode == mode)
            const Icon(CupertinoIcons.checkmark, color: YYColors.accentPrimary, size: 16)
          else
            const SizedBox(width: 16),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: textColor)),
        ],
      ),
    );
  }

  List<MusicItem>? _originalOrder;

  void _applySorting() {
    _originalOrder ??= List.from(_songs);
    switch (_sortMode) {
      case _SortMode.original: _songs = List.from(_originalOrder!);
      case _SortMode.title: _songs.sort((a, b) => a.title.compareTo(b.title));
      case _SortMode.artist: _songs.sort((a, b) => a.artist.compareTo(b.artist));
      case _SortMode.duration: _songs.sort((a, b) => (a.duration?.inMilliseconds ?? 0).compareTo(b.duration?.inMilliseconds ?? 0));
    }
  }
}

class _SongRow extends ConsumerWidget {
  final MusicItem song;
  final int index;
  final bool isPlaying;
  final VoidCallback onTap;

  const _SongRow({required this.song, required this.index, required this.isPlaying, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pri = isDark ? YYColors.textPrimary : YYLightColors.textPrimary;
    final sub = isDark ? YYColors.textSecondary : YYLightColors.textSecondary;
    final tri = isDark ? YYColors.textTertiary : YYLightColors.textTertiary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: () => showSongActions(context, ref, song),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: isPlaying
                  ? const Icon(CupertinoIcons.waveform, color: YYColors.accentPrimary, size: 18)
                  : Text('$index', style: TextStyle(color: tri, fontSize: 14), textAlign: TextAlign.center),
            ),
            const SizedBox(width: 12),
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
                  const SizedBox(height: 2),
                  Text(song.artist, style: TextStyle(color: sub, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(song.durationText, style: TextStyle(color: tri, fontSize: 12)),
                if (song.format != null)
                  Text(song.format!, style: TextStyle(
                      color: YYColors.accentPrimary.withValues(alpha: 0.6),
                      fontSize: 10, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
