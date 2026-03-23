import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/theme.dart';
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
    if (mounted) setState(() => _history = history);
  }

  Future<void> _doSearch(String value) async {
    _debounce?.cancel();
    setState(() {
      _query = value;
      _searching = true;
    });

    if (value.trim().isEmpty) {
      setState(() { _results = []; _searching = false; });
      return;
    }

    ref.read(searchHistoryProvider).addSearch(value);
    _loadHistory();

    final db = ref.read(musicDatabaseProvider);
    final results = await db.search(value);

    if (mounted) {
      setState(() { _results = results; _searching = false; });
    }
  }

  void _scheduleSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () => _doSearch(value));
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

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 搜索框
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: context.yyBgSurface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.search, color: context.yyTextTertiary, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        onChanged: _scheduleSearch,
                        style: TextStyle(
                          color: context.yyTextPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: '搜索歌曲、艺术家、专辑',
                          hintStyle: TextStyle(
                            color: context.yyTextTertiary,
                            fontWeight: FontWeight.w400,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    if (_query.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _controller.clear();
                          _doSearch('');
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: context.yyTextTertiary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(CupertinoIcons.xmark, size: 12, color: context.yyTextTertiary),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 内容区
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

  /// 空状态：仅搜索历史
  Widget _buildIdleState(BuildContext context) {
    if (_history.isEmpty) {
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
              '搜索你的曲库',
              style: TextStyle(color: context.yyTextTertiary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '最近搜索',
                style: TextStyle(
                  color: context.yyTextSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            GestureDetector(
              onTap: _clearHistory,
              child: Text(
                '清空',
                style: TextStyle(
                  color: context.yyTextTertiary,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ..._history.map((item) => GestureDetector(
          onTap: () => _applyQuery(item),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: context.yySeparator, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(CupertinoIcons.time, size: 16, color: context.yyTextTertiary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      color: context.yyTextPrimary,
                      fontSize: 15,
                    ),
                  ),
                ),
                Icon(CupertinoIcons.arrow_up_left, size: 14, color: context.yyTextTertiary),
              ],
            ),
          ),
        )),
      ],
    );
  }

  /// 搜索结果
  Widget _buildResults(BuildContext context, PlayerState player) {
    if (_searching) {
      return const Center(
        child: CircularProgressIndicator(color: YYColors.accentPrimary),
      );
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
              style: TextStyle(color: context.yyTextSecondary, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final song = _results[index];
        final isActive = player.currentSong?.id == song.id;
        return ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                HSLColor.fromAHSL(1.0, (song.title.hashCode % 360).toDouble(), 0.5, 0.4).toColor(),
                HSLColor.fromAHSL(1.0, ((song.title.hashCode + 40) % 360).toDouble(), 0.4, 0.3).toColor(),
              ]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: isActive
                ? const Icon(CupertinoIcons.waveform, color: Colors.white, size: 16)
                : const Icon(CupertinoIcons.music_note, color: Colors.white, size: 16),
          ),
          title: Text(
            song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isActive ? YYColors.accentPrimary : context.yyTextPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            '${song.artist} · ${song.album}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.yyTextTertiary, fontSize: 12),
          ),
          onTap: () => ref.read(playerProvider.notifier).playSong(song, queue: _results),
          onLongPress: () => showSongActions(context, ref, song),
        );
      },
    );
  }
}
