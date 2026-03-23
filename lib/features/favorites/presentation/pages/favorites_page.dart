import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../app/theme/theme.dart';
import '../../../../shared/widgets/gradient_cover.dart';
import '../../../../shared/widgets/modern_music_ui.dart';
import '../../../player/domain/entities/music_item.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../data/services/favorites_service.dart';
import '../../../library/presentation/providers/library_provider.dart';

/// 收藏页面 — 自适应亮暗主题
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
    final songs = favIds.where((id) => songMap.containsKey(id)).map((id) => songMap[id]!).toList();
    if (mounted) setState(() { _songs = songs; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: YYScenicBackground(
        accent: YYColors.heartRed,
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              // 顶部标题区域
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Icon(CupertinoIcons.back, color: context.yyTextPrimary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: YYPageHeader(
                          eyebrow: '我的音乐',
                          title: '收藏',
                          subtitle: '${_songs.length} 首收藏歌曲',
                        ),
                      ),
                      if (_songs.isNotEmpty)
                        YYHeaderActionButton(
                          icon: CupertinoIcons.play_fill,
                          onTap: () => ref.read(playerProvider.notifier).playSong(_songs.first, queue: _songs),
                        ),
                    ],
                  ),
                ),
              ),
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: YYColors.accentPrimary)),
                ),
              if (!_isLoading && _songs.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.heart, size: 48, color: context.yyTextTertiary),
                        const SizedBox(height: 12),
                        Text('还没有收藏', style: TextStyle(color: context.yyTextSecondary, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text('播放歌曲时点击 ❤️ 来收藏', style: TextStyle(color: context.yyTextTertiary, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              if (!_isLoading && _songs.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 28),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final song = _songs[index];
                        final isPlaying = playerState.currentSong?.id == song.id;
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => ref.read(playerProvider.notifier).playSong(song, queue: _songs),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 28,
                                  child: isPlaying
                                      ? const Icon(CupertinoIcons.waveform, color: YYColors.accentPrimary, size: 18)
                                      : Text('${index + 1}', style: TextStyle(color: context.yyTextTertiary, fontSize: 14),
                                          textAlign: TextAlign.center),
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
                                          color: isPlaying ? YYColors.accentPrimary : context.yyTextPrimary,
                                          fontWeight: FontWeight.w500, fontSize: 15),
                                          maxLines: 1, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 2),
                                      Text(song.artist, style: TextStyle(color: context.yyTextSecondary, fontSize: 12),
                                          maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () async {
                                    await ref.read(favoritesServiceProvider).toggleFavorite(song.id);
                                    _load();
                                  },
                                  child: const Icon(CupertinoIcons.heart_fill, color: YYColors.heartRed, size: 20),
                                ),
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
        ),
      ),
    );
  }
}
