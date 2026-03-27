import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/theme.dart';
import '../../../../shared/widgets/gradient_cover.dart';
import '../../../player/domain/entities/music_item.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../data/services/favorites_service.dart';
import '../../../library/presentation/providers/library_provider.dart';

/// Favorites page -- iOS native style
class FavoritesPage extends ConsumerStatefulWidget {
  const FavoritesPage({super.key});

  @override
  ConsumerState<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends ConsumerState<FavoritesPage> {
  List<MusicItem> _songs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final favService = ref.read(favoritesServiceProvider);
    final db = ref.read(musicDatabaseProvider);
    final favIds = await favService.getAllFavoriteIds();
    final allSongs = await db.getAllSongs();
    final songMap = {for (final s in allSongs) s.id: s};
    final songs = favIds
        .where((id) => songMap.containsKey(id))
        .map((id) => songMap[id]!)
        .toList();
    if (mounted) {
      setState(() {
        _songs = songs;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
          '收藏',
          style: TextStyle(
            color: context.yyTextPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator(radius: 14))
            : _songs.isEmpty
            ? _buildEmpty(context)
            : _buildList(context, playerState),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.heart,
            size: 48,
            color: context.yyTextTertiary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            '还没有收藏歌曲',
            style: TextStyle(
              color: context.yyTextSecondary,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '播放歌曲时点击心形按钮来收藏',
            style: TextStyle(color: context.yyTextTertiary, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, PlayerState playerState) {
    return CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.heart_fill,
                  color: YYColors.heartRed,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '${_songs.length} 首歌曲',
                  style: TextStyle(
                    color: context.yyTextSecondary,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
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
                        '播放全部',
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

        // Song list
        SliverPadding(
          padding: EdgeInsets.only(
            bottom: YYSizes.bottomInset(context, hasMiniPlayer: false),
          ),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final song = _songs[index];
              final isPlaying = playerState.currentSong?.id == song.id;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => ref
                    .read(playerProvider.notifier)
                    .playSong(song, queue: _songs),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      // Cover
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
                      // Title / Artist
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
                      // Unfavorite
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        onPressed: () async {
                          await ref
                              .read(favoritesServiceProvider)
                              .toggleFavorite(song.id);
                          _load();
                        },
                        child: const Icon(
                          CupertinoIcons.heart_fill,
                          color: YYColors.heartRed,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }, childCount: _songs.length),
          ),
        ),
      ],
    );
  }
}
