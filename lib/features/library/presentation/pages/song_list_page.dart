import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../app/theme/theme.dart';
import '../../../../shared/widgets/gradient_cover.dart';
import '../../../player/domain/entities/music_item.dart';
import '../../../player/presentation/providers/player_provider.dart';

/// 分类类型
enum SongListType { artist, album, genre, all }

/// 歌曲列表页 — 通用分类歌曲列表
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

    return Scaffold(
      backgroundColor: YYColors.bgBase,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: YYColors.textPrimary,
            expandedHeight: 140,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(widget.title, style: const TextStyle(
                  color: YYColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      YYColors.accentPrimary.withValues(alpha: 0.15),
                      YYColors.bgBase,
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              // 全部播放
              if (_songs.isNotEmpty)
                IconButton(
                  icon: const Icon(CupertinoIcons.play_circle, size: 28),
                  onPressed: () {
                    ref.read(playerProvider.notifier).playSong(_songs.first, queue: _songs);
                  },
                ),
            ],
          ),

          // Subtitle
          if (widget.subtitle != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text('${_songs.length} 首歌曲 · ${widget.subtitle}',
                    style: const TextStyle(color: YYColors.textTertiary, fontSize: 13)),
              ),
            ),

          // 加载
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: YYColors.accentPrimary)),
            ),

          // 歌曲列表
          if (!_isLoading)
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 160),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final song = _songs[index];
                    final isPlaying = playerState.currentSong?.id == song.id;

                    return _SongRow(
                      song: song,
                      index: index + 1,
                      isPlaying: isPlaying,
                      onTap: () {
                        ref.read(playerProvider.notifier).playSong(song, queue: _songs);
                      },
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
}

class _SongRow extends StatelessWidget {
  final MusicItem song;
  final int index;
  final bool isPlaying;
  final VoidCallback onTap;

  const _SongRow({
    required this.song,
    required this.index,
    required this.isPlaying,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            // 序号或播放动画
            SizedBox(
              width: 28,
              child: isPlaying
                  ? const Icon(CupertinoIcons.waveform, color: YYColors.accentPrimary, size: 18)
                  : Text('$index', style: const TextStyle(
                      color: YYColors.textTertiary, fontSize: 14),
                      textAlign: TextAlign.center),
            ),
            const SizedBox(width: 12),
            // 封面
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 44, height: 44,
                child: GradientCover(seed: song.title, size: 44),
              ),
            ),
            const SizedBox(width: 12),
            // 标题和艺术家
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(song.title,
                      style: TextStyle(
                        color: isPlaying ? YYColors.accentPrimary : YYColors.textPrimary,
                        fontWeight: FontWeight.w500, fontSize: 15),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(song.artist,
                      style: const TextStyle(color: YYColors.textSecondary, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            // 时长 + 格式
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(song.durationText,
                    style: const TextStyle(color: YYColors.textTertiary, fontSize: 12)),
                if (song.format != null)
                  Text(song.format!,
                      style: TextStyle(
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
