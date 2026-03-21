import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/theme.dart';
import '../../../../shared/widgets/modern_music_ui.dart';
import '../../../../shared/widgets/song_actions_sheet.dart';
import '../../../library/presentation/providers/library_provider.dart';
import '../../../player/domain/entities/music_item.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../data/services/search_history_service.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  bool _searching = false;
  List<MusicItem> _results = [];
  List<String> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final history = await ref.read(searchHistoryProvider).getHistory();
    if (mounted) {
      setState(() => _history = history);
    }
  }

  Future<void> _doSearch(String value) async {
    _debounce?.cancel();
    setState(() {
      _query = value;
      _searching = true;
    });

    if (value.trim().isEmpty) {
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }

    ref.read(searchHistoryProvider).addSearch(value);
    _loadHistory();

    final db = ref.read(musicDatabaseProvider);
    final results = await db.search(value);

    if (mounted) {
      setState(() {
        _results = results;
        _searching = false;
      });
    }
  }

  void _scheduleSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      _doSearch(value);
    });
  }

  void _applyQuery(String value) {
    _controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _doSearch(value);
  }

  Future<void> _removeHistoryItem(String value) async {
    await ref.read(searchHistoryProvider).removeSearch(value);
    await _loadHistory();
  }

  Future<void> _clearHistory() async {
    await ref.read(searchHistoryProvider).clearAll();
    if (!mounted) return;
    setState(() => _history = []);
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    final player = ref.watch(playerProvider);
    final suggestionTerms = {
      ..._history.take(3),
      ...library.genres.map((genre) => genre.name),
    }.take(8).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: YYScenicBackground(
        accent: _query.isEmpty
            ? YYColors.accentSecondary
            : YYSeedPalette.primary(_query),
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 28),
            children: [
              const YYPageHeader(
                eyebrow: '精准定位',
                title: '搜索',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _SearchFieldCard(
                  controller: _controller,
                  query: _query,
                  resultCount: _results.length,
                  searching: _searching,
                  onChanged: _scheduleSearch,
                  onClear: () {
                    _controller.clear();
                    _doSearch('');
                  },
                ),
              ),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _query.isEmpty
                    ? Column(
                        key: const ValueKey('search-idle'),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: _SearchOverviewCard(
                              songCount: library.allSongs.length,
                              artistCount: library.artists.length,
                              albumCount: library.albums.length,
                              suggestions: suggestionTerms,
                              onSuggestionTap: _applyQuery,
                            ),
                          ),
                          if (_history.isNotEmpty) ...[
                            YYSectionTitle(
                              title: '最近搜索',
                              trailing: YYPillButton(
                                label: '清空',
                                compact: true,
                                onTap: _clearHistory,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _history.map((item) {
                                  return _HistoryChip(
                                    label: item,
                                    onTap: () => _applyQuery(item),
                                    onRemove: () => _removeHistoryItem(item),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                          if (library.recentPlays.isNotEmpty) ...[
                            const YYSectionTitle(
                              title: '最近播放',
                            ),
                            ...library.recentPlays.take(6).map((song) {
                              return YYTrackRow(
                                song: song,
                                active: player.currentSong?.id == song.id,
                                onTap: () => ref
                                    .read(playerProvider.notifier)
                                    .playSong(song, queue: library.recentPlays),
                                onLongPress: () =>
                                    showSongActions(context, ref, song),
                              );
                            }),
                          ],
                        ],
                      )
                    : Column(
                        key: const ValueKey('search-results'),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: _ResultSummaryCard(
                              query: _query,
                              searching: _searching,
                              resultCount: _results.length,
                              libraryCount: library.allSongs.length,
                            ),
                          ),
                          YYSectionTitle(
                            title: _searching ? '正在搜索' : '结果列表',
                          ),
                          if (_searching)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 30),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: YYColors.accentPrimary,
                                ),
                              ),
                            ),
                          if (!_searching && _results.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: YYPanel(
                                child: Column(
                                  children: [
                                    const YYIconBadge(
                                      icon: CupertinoIcons.search_circle,
                                      color: YYColors.accentSecondary,
                                      size: 52,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      '没有找到匹配项',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '换个关键词，或者试试艺术家 / 专辑名。',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (!_searching)
                            ..._results.map((song) {
                              return YYTrackRow(
                                song: song,
                                active: player.currentSong?.id == song.id,
                                subtitle: '${song.artist} · ${song.album}',
                                onTap: () => ref
                                    .read(playerProvider.notifier)
                                    .playSong(song, queue: _results),
                                onLongPress: () =>
                                    showSongActions(context, ref, song),
                              );
                            }),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchFieldCard extends StatelessWidget {
  const _SearchFieldCard({
    required this.controller,
    required this.query,
    required this.resultCount,
    required this.searching,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String query;
  final int resultCount;
  final bool searching;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final badgeLabel = query.isEmpty
        ? '本地曲库'
        : searching
        ? '搜索中'
        : '$resultCount 条';

    return YYPanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(CupertinoIcons.search, color: context.yyTextTertiary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: TextStyle(
                color: context.yyTextPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: '搜索歌曲、艺术家、专辑、流派',
                hintStyle: TextStyle(
                  color: context.yyTextTertiary,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: context.yyBgSurface.withValues(
                alpha: context.isDark ? 0.72 : 0.9,
              ),
              borderRadius: BorderRadius.circular(YYRadius.full),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (searching) ...[
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: YYColors.accentPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  badgeLabel,
                  style: TextStyle(
                    color: context.yyTextSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (query.isNotEmpty) ...[
            const SizedBox(width: 8),
            Material(
              color: Colors.transparent,
              child: Ink(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: context.yyBgSurface.withValues(
                    alpha: context.isDark ? 0.72 : 0.9,
                  ),
                  shape: BoxShape.circle,
                ),
                child: InkWell(
                  onTap: onClear,
                  customBorder: const CircleBorder(),
                  overlayColor: WidgetStatePropertyAll(
                    context.yyTextPrimary.withValues(alpha: 0.05),
                  ),
                  child: Icon(
                    CupertinoIcons.xmark,
                    color: context.yyTextTertiary,
                    size: 14,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SearchOverviewCard extends StatelessWidget {
  const _SearchOverviewCard({
    required this.songCount,
    required this.artistCount,
    required this.albumCount,
    required this.suggestions,
    required this.onSuggestionTap,
  });

  final int songCount;
  final int artistCount;
  final int albumCount;
  final List<String> suggestions;
  final ValueChanged<String> onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    return YYPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('检索范围', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          YYMetricBand(
            items: [
              YYMetricBandItem(
                label: '歌曲',
                value: '$songCount',
                tint: YYColors.accentPrimary,
              ),
              YYMetricBandItem(
                label: '艺术家',
                value: '$artistCount',
                tint: YYColors.accentSecondary,
              ),
              YYMetricBandItem(
                label: '专辑',
                value: '$albumCount',
                tint: YYColors.accentTertiary,
              ),
            ],
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              '推荐关键词',
              style: TextStyle(
                color: context.yyTextSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: suggestions.map((term) {
                return YYTag(
                  text: term,
                  color: YYSeedPalette.primary(term),
                  onTap: () => onSuggestionTap(term),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryChip extends StatelessWidget {
  const _HistoryChip({
    required this.label,
    required this.onTap,
    required this.onRemove,
  });

  final String label;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: context.yyBgElevated.withValues(
            alpha: context.isDark ? 0.88 : 0.97,
          ),
          borderRadius: BorderRadius.circular(YYRadius.full),
          border: Border.all(color: context.yySeparator),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(YYRadius.full),
              overlayColor: WidgetStatePropertyAll(
                context.yyTextPrimary.withValues(alpha: 0.04),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      CupertinoIcons.time,
                      size: 14,
                      color: YYColors.accentPrimary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        color: context.yyTextSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onRemove,
                customBorder: const CircleBorder(),
                overlayColor: WidgetStatePropertyAll(
                  context.yyTextPrimary.withValues(alpha: 0.04),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    CupertinoIcons.xmark,
                    size: 12,
                    color: context.yyTextTertiary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultSummaryCard extends StatelessWidget {
  const _ResultSummaryCard({
    required this.query,
    required this.searching,
    required this.resultCount,
    required this.libraryCount,
  });

  final String query;
  final bool searching;
  final int resultCount;
  final int libraryCount;

  @override
  Widget build(BuildContext context) {
    return YYPanel(
      color: context.yyBlend(YYSeedPalette.primary(query), amount: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            searching ? '正在搜索 “$query”' : '“$query” 的结果',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 14),
          YYMetricBand(
            items: [
              YYMetricBandItem(
                label: '匹配结果',
                value: '$resultCount',
                tint: YYColors.accentPrimary,
              ),
              YYMetricBandItem(
                label: '总曲库',
                value: '$libraryCount',
                tint: YYColors.accentSecondary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
