import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/theme.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../../../shared/widgets/gradient_cover.dart';
import '../../../player/domain/entities/music_item.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../library/presentation/providers/library_provider.dart';

/// 搜索页
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _doSearch(String query) async {
    setState(() { _query = query; _searching = true; });
    if (query.isEmpty) {
      setState(() { _results = []; _searching = false; });
      return;
    }
    final db = ref.read(musicDatabaseProvider);
    final results = await db.search(query);
    if (mounted) setState(() { _results = results; _searching = false; });
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);

    return Scaffold(
      backgroundColor: YYColors.bgBase,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            floating: true,
            title: const Text('搜索',
                style: TextStyle(
                    color: YYColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold)),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 160),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 搜索框
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: GlassContainer(
                    borderRadius: BorderRadius.circular(14),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.search, color: YYColors.textTertiary, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(color: YYColors.textPrimary, fontSize: 16),
                            decoration: const InputDecoration(
                              hintText: '搜索歌曲、艺术家、专辑',
                              hintStyle: TextStyle(color: YYColors.textTertiary),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 14),
                            ),
                            onChanged: _doSearch,
                          ),
                        ),
                        if (_query.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              _doSearch('');
                            },
                            child: const Icon(CupertinoIcons.xmark_circle_fill,
                                color: YYColors.textTertiary, size: 18),
                          ),
                      ],
                    ),
                  ),
                ),

                // 搜索结果
                if (_query.isNotEmpty && _results.isEmpty && !_searching)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: Text('没有找到结果',
                        style: TextStyle(color: YYColors.textTertiary, fontSize: 15))),
                  ),

                if (_query.isEmpty && library.allSongs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(CupertinoIcons.search, size: 48, color: YYColors.textTertiary),
                          SizedBox(height: 12),
                          Text('还没有歌曲', style: TextStyle(color: YYColors.textSecondary, fontSize: 15)),
                          SizedBox(height: 4),
                          Text('先去设置中添加数据源', style: TextStyle(color: YYColors.textTertiary, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),

                if (_query.isEmpty && library.allSongs.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('共 ${library.allSongs.length} 首歌曲可搜索',
                        style: const TextStyle(color: YYColors.textTertiary, fontSize: 14)),
                  ),

                // 结果列表
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
    return GestureDetector(
      onTap: () => ref.read(playerProvider.notifier).playSong(song, queue: allResults),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(width: 48, height: 48, child: GradientCover(seed: song.title, size: 48)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(song.title, style: const TextStyle(
                      color: YYColors.textPrimary, fontWeight: FontWeight.w500, fontSize: 15),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('${song.artist} · ${song.album}',
                      style: const TextStyle(color: YYColors.textSecondary, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Text(song.durationText, style: const TextStyle(color: YYColors.textTertiary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
