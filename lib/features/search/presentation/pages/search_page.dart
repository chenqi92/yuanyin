import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/theme.dart';
import '../../../../shared/widgets/gradient_cover.dart';
import '../../../../shared/widgets/song_actions_sheet.dart';
import '../../../player/domain/entities/music_item.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../library/presentation/providers/library_provider.dart';
import '../../data/services/search_history_service.dart';

/// 搜索页 — v3 自适应亮暗主题
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _searchController = TextEditingController();
  String _query = '';
  List<MusicItem> _results = [];
  bool _searching = false;
  List<String> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() { _searchController.dispose(); super.dispose(); }

  Future<void> _loadHistory() async {
    final h = await ref.read(searchHistoryProvider).getHistory();
    if (mounted) setState(() => _history = h);
  }

  Future<void> _doSearch(String query) async {
    setState(() { _query = query; _searching = true; });
    if (query.isEmpty) {
      setState(() { _results = []; _searching = false; });
      return;
    }
    // 记录搜索历史
    ref.read(searchHistoryProvider).addSearch(query);
    _loadHistory();
    final db = ref.read(musicDatabaseProvider);
    final results = await db.search(query);
    if (mounted) setState(() { _results = results; _searching = false; });
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? YYColors.bgBase : YYLightColors.bgBase;
    final card = isDark ? YYColors.bgElevated : YYLightColors.bgElevated;
    final pri = isDark ? YYColors.textPrimary : YYLightColors.textPrimary;
    final sub = isDark ? YYColors.textSecondary : YYLightColors.textSecondary;
    final tri = isDark ? YYColors.textTertiary : YYLightColors.textTertiary;
    final sep = isDark ? YYColors.separator : YYLightColors.separator;

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(YYSpacing.screenH, 12, YYSpacing.screenH, 0),
                child: Text('搜索', style: TextStyle(
                    color: pri, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 160),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: YYSpacing.screenH, vertical: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(YYRadius.searchBar),
                      border: Border.all(color: sep, width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.search, color: tri, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: TextStyle(color: pri, fontSize: 16),
                            decoration: InputDecoration(
                              hintText: '搜索歌曲、艺术家、专辑',
                              hintStyle: TextStyle(color: tri),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onChanged: _doSearch,
                          ),
                        ),
                        if (_query.isNotEmpty)
                          GestureDetector(
                            onTap: () { _searchController.clear(); _doSearch(''); },
                            child: Icon(CupertinoIcons.xmark_circle_fill, color: tri, size: 18),
                          ),
                      ],
                    ),
                  ),
                ),

                if (_query.isEmpty && _history.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: YYSpacing.screenH, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('搜索历史', style: TextStyle(color: tri, fontSize: 13, fontWeight: FontWeight.w600)),
                            const Spacer(),
                            GestureDetector(
                              onTap: () async {
                                await ref.read(searchHistoryProvider).clearAll();
                                _loadHistory();
                              },
                              child: Text('清空', style: TextStyle(color: tri, fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: _history.map((q) => GestureDetector(
                            onTap: () { _searchController.text = q; _doSearch(q); },
                            onLongPress: () async {
                              await ref.read(searchHistoryProvider).removeSearch(q);
                              _loadHistory();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: card,
                                borderRadius: BorderRadius.circular(YYRadius.full),
                                border: Border.all(color: sep),
                              ),
                              child: Text(q, style: TextStyle(color: sub, fontSize: 13)),
                            ),
                          )).toList(),
                        ),
                      ],
                    ),
                  ),

                if (_query.isEmpty && library.allSongs.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: YYSpacing.screenH, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('共 ${library.allSongs.length} 首歌曲', style: TextStyle(color: tri, fontSize: 13)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: library.genres.take(6).map((g) => GestureDetector(
                            onTap: () { _searchController.text = g.name; _doSearch(g.name); },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: card,
                                borderRadius: BorderRadius.circular(YYRadius.full),
                                border: Border.all(color: sep),
                              ),
                              child: Text(g.name, style: TextStyle(color: sub, fontSize: 13)),
                            ),
                          )).toList(),
                        ),
                      ],
                    ),
                  ),

                if (_query.isEmpty && library.allSongs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: Column(children: [
                        Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16)),
                          child: Icon(CupertinoIcons.search, size: 28, color: tri),
                        ),
                        const SizedBox(height: 16),
                        Text('还没有歌曲', style: TextStyle(color: sub, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text('先去设置中添加数据源', style: TextStyle(color: tri, fontSize: 13)),
                      ]),
                    ),
                  ),

                if (_query.isNotEmpty && _results.isEmpty && !_searching)
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(child: Text('没有找到结果', style: TextStyle(color: tri, fontSize: 15))),
                  ),

                ..._results.map((song) => _SearchResultTile(song: song, allResults: _results)),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResultTile extends ConsumerWidget {
  final MusicItem song;
  final List<MusicItem> allResults;
  const _SearchResultTile({required this.song, required this.allResults});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pri = isDark ? YYColors.textPrimary : YYLightColors.textPrimary;
    final sub = isDark ? YYColors.textSecondary : YYLightColors.textSecondary;
    final tri = isDark ? YYColors.textTertiary : YYLightColors.textTertiary;
    final isPlaying = ref.watch(playerProvider).currentSong?.id == song.id;

    return GestureDetector(
      onTap: () => ref.read(playerProvider.notifier).playSong(song, queue: allResults),
      onLongPress: () => showSongActions(context, ref, song),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: YYSpacing.screenH, vertical: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(YYRadius.coverSmall),
              child: SizedBox(width: 48, height: 48, child: GradientCover(seed: song.title, coverUrl: song.coverUrl, size: 48)),
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
                  Text('${song.artist} · ${song.album}',
                      style: TextStyle(color: sub, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (isPlaying)
              const Icon(CupertinoIcons.waveform, color: YYColors.accentPrimary, size: 16)
            else
              Text(song.durationText, style: TextStyle(color: tri, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
