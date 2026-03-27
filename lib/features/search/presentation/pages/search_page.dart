import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/theme.dart';
import '../../../../shared/services/native_tab_bar_service.dart';
import '../../../../shared/widgets/gradient_cover.dart';
import '../../../../shared/widgets/song_actions_sheet.dart';
import '../../../library/presentation/providers/library_provider.dart';
import '../../../player/domain/entities/music_item.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../data/services/search_history_service.dart';

/// iOS native-style search page
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  String _query = '';
  bool _searching = false;
  List<MusicItem> _results = [];
  List<String> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
    NativeTabBarService.instance.setTabBarVisible(false);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    NativeTabBarService.instance.setTabBarVisible(true);
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final history = await ref.read(searchHistoryProvider).getHistory();
    if (mounted) setState(() => _history = history);
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
    _debounce = Timer(
      const Duration(milliseconds: 220),
      () => _doSearch(value),
    );
  }

  void _applyQuery(String value) {
    _controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _doSearch(value);
  }

  Future<void> _clearHistory() async {
    await ref.read(searchHistoryProvider).clearAll();
    if (mounted) setState(() => _history = []);
  }

  Future<void> _removeHistoryItem(String item) async {
    await ref.read(searchHistoryProvider).removeSearch(item);
    if (mounted) _loadHistory();
  }

  void _dismiss() {
    _focusNode.unfocus();
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);

    return CupertinoPageScaffold(
      backgroundColor: context.yyBgBase,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoSearchTextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      placeholder: '搜索歌曲、艺术家、专辑',
                      onChanged: _scheduleSearch,
                      onSuffixTap: () {
                        _controller.clear();
                        _doSearch('');
                      },
                      style: TextStyle(
                        color: context.yyTextPrimary,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: _dismiss,
                    child: Text(
                      '取消',
                      style: TextStyle(
                        color: YYColors.accentPrimary,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Content
            Expanded(
              child: _query.isEmpty
                  ? _buildIdleState(context)
                  : _buildResults(context, player),
            ),
          ],
        ),
      ),
    );
  }

  /// Empty state: search history or prompt
  Widget _buildIdleState(BuildContext context) {
    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.search,
              size: 48,
              color: context.yyTextTertiary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              '搜索音乐',
              style: TextStyle(
                color: context.yyTextSecondary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '输入歌曲名、艺术家或专辑',
              style: TextStyle(color: context.yyTextTertiary, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '最近搜索',
                  style: TextStyle(
                    color: context.yyTextPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: _clearHistory,
                child: Text(
                  '清除',
                  style: TextStyle(color: YYColors.accentPrimary, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _history.map((item) {
            return GestureDetector(
              onTap: () => _applyQuery(item),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: context.isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item,
                      style: TextStyle(
                        color: context.yyTextPrimary,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _removeHistoryItem(item),
                      child: Icon(
                        CupertinoIcons.xmark,
                        size: 12,
                        color: context.yyTextTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Search results
  Widget _buildResults(BuildContext context, PlayerState player) {
    if (_searching) {
      return const Center(child: CupertinoActivityIndicator(radius: 14));
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.search,
              size: 40,
              color: context.yyTextTertiary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              '没有找到 "$_query"',
              style: TextStyle(
                color: context.yyTextSecondary,
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '试试其他关键词',
              style: TextStyle(color: context.yyTextTertiary, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final song = _results[index];
        final isActive = player.currentSong?.id == song.id;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () =>
              ref.read(playerProvider.notifier).playSong(song, queue: _results),
          onLongPress: () => showSongActions(context, ref, song),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isActive
                              ? YYColors.accentPrimary
                              : context.yyTextPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.yyTextSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                // Duration
                Text(
                  song.durationText,
                  style: TextStyle(color: context.yyTextTertiary, fontSize: 13),
                ),
                const SizedBox(width: 8),
                // More button
                GestureDetector(
                  onTap: () => showSongActions(context, ref, song),
                  child: Icon(
                    CupertinoIcons.ellipsis,
                    size: 18,
                    color: context.yyTextTertiary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
