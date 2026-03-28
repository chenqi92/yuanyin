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

/// Category type
enum SongListType { artist, album, genre, all }

/// Sort mode
enum _SortMode { original, title, artist, duration }

/// Song list page -- iOS native style
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

class _SongListPageState extends ConsumerState<SongListPage>
    with ConsumerShellNavigationVisibilityMixin {
  List<MusicItem> _songs = [];
  bool _isLoading = true;
  _SortMode _sortMode = _SortMode.original;

  @override
  void initState() {
    super.initState();
    hideShellNavigation();
    _load();
  }

  Future<void> _load() async {
    final songs = await widget.loadSongs();
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
      child: CustomScrollView(
        slivers: [
          // Large title navigation bar
          CupertinoSliverNavigationBar(
            backgroundColor: context.yyBgBase.withValues(alpha: 0.9),
            border: Border(
              bottom: BorderSide(color: context.yySeparator, width: 0.5),
            ),
            largeTitle: Text(
              widget.title,
              style: TextStyle(color: context.yyTextPrimary),
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
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_songs.isNotEmpty)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: _showSortMenu,
                    child: Icon(
                      CupertinoIcons.sort_down,
                      color: YYColors.accentPrimary,
                      size: 22,
                    ),
                  ),
              ],
            ),
          ),

          // Header: song count + play all / shuffle
          if (!_isLoading && _songs.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Text(
                      '${_songs.length} 首歌曲',
                      style: TextStyle(
                        color: context.yyTextTertiary,
                        fontSize: 13,
                      ),
                    ),
                    if (widget.subtitle != null) ...[
                      Text(
                        ' · ${widget.subtitle}',
                        style: TextStyle(
                          color: context.yyTextTertiary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const Spacer(),
                    // Play all
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
                    const SizedBox(width: 8),
                    // Shuffle
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      color: context.isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(18),
                      onPressed: () {
                        final shuffled = List<MusicItem>.from(_songs)
                          ..shuffle();
                        ref
                            .read(playerProvider.notifier)
                            .playSong(shuffled.first, queue: shuffled);
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.shuffle,
                            size: 14,
                            color: context.yyTextPrimary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '随机',
                            style: TextStyle(
                              color: context.yyTextPrimary,
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

          // Loading
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CupertinoActivityIndicator(radius: 14)),
            ),

          // Song list
          if (!_isLoading)
            SliverPadding(
              padding: EdgeInsets.only(
                bottom: YYSizes.bottomInset(context, hasMiniPlayer: false),
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final song = _songs[index];
                  final isPlaying = playerState.currentSong?.id == song.id;
                  return _SongRow(
                    song: song,
                    isPlaying: isPlaying,
                    onTap: () => ref
                        .read(playerProvider.notifier)
                        .playSong(song, queue: _songs),
                    onLongPress: () => showSongActions(context, ref, song),
                  );
                }, childCount: _songs.length),
              ),
            ),
        ],
      ),
    );
  }

  void _showSortMenu() {
    showYYNativeCupertinoPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('排序方式'),
        actions: [
          _sortAction(ctx, _SortMode.original, '默认顺序'),
          _sortAction(ctx, _SortMode.title, '按标题'),
          _sortAction(ctx, _SortMode.artist, '按艺术家'),
          _sortAction(ctx, _SortMode.duration, '按时长'),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
    );
  }

  CupertinoActionSheetAction _sortAction(
    BuildContext ctx,
    _SortMode mode,
    String label,
  ) {
    final isActive = _sortMode == mode;
    return CupertinoActionSheetAction(
      onPressed: () {
        Navigator.pop(ctx);
        setState(() {
          _sortMode = mode;
          _applySorting();
        });
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isActive) ...[
            const Icon(
              CupertinoIcons.checkmark,
              color: YYColors.accentPrimary,
              size: 16,
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: isActive ? YYColors.accentPrimary : null,
              fontWeight: isActive ? FontWeight.w600 : null,
            ),
          ),
        ],
      ),
    );
  }

  List<MusicItem>? _originalOrder;

  void _applySorting() {
    _originalOrder ??= List.from(_songs);
    switch (_sortMode) {
      case _SortMode.original:
        _songs = List.from(_originalOrder!);
        break;
      case _SortMode.title:
        _songs.sort((a, b) => a.title.compareTo(b.title));
        break;
      case _SortMode.artist:
        _songs.sort((a, b) => a.artist.compareTo(b.artist));
        break;
      case _SortMode.duration:
        _songs.sort(
          (a, b) => (a.duration?.inMilliseconds ?? 0).compareTo(
            b.duration?.inMilliseconds ?? 0,
          ),
        );
        break;
    }
  }
}

class _SongRow extends ConsumerWidget {
  final MusicItem song;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _SongRow({
    required this.song,
    required this.isPlaying,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Row(
          children: [
            // Cover 44x44 rounded 6
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
            // Duration
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
