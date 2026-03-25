import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/theme.dart';
import '../../../../shared/services/native_tab_bar_service.dart';
import '../../../../shared/widgets/song_actions_sheet.dart';
import '../../../library/presentation/providers/library_provider.dart';
import '../../../player/domain/entities/music_item.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../data/services/search_history_service.dart';

/// iOS 原生风格搜索页 —— 参考 Apple Music
/// 顶部 CupertinoSearchTextField + 取消按钮
/// 底部由 native tab bar 提供返回主界面入口
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
    // 自动聚焦搜索框
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
    // 隐藏 native tab bar（搜索页全屏）
    NativeTabBarService.instance.setTabBarVisible(false);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    // 恢复 native tab bar
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
    _debounce =
        Timer(const Duration(milliseconds: 220), () => _doSearch(value));
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

  void _dismiss() {
    _focusNode.unfocus();
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0A) : CupertinoColors.systemGroupedBackground.resolveFrom(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // — 搜索栏（iOS 原生风格）
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
                    minSize: 0,
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

            // — 内容区
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

  /// 空状态：搜索历史
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
              '搜索你的曲库',
              style: TextStyle(
                color: context.yyTextSecondary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '输入歌曲名、艺术家或专辑',
              style: TextStyle(
                color: context.yyTextTertiary,
                fontSize: 15,
              ),
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
                minSize: 0,
                onPressed: _clearHistory,
                child: Text(
                  '清除',
                  style: TextStyle(
                    color: YYColors.accentPrimary,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
        ..._history.map(
          (item) => CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 0,
            onPressed: () => _applyQuery(item),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom:
                      BorderSide(color: context.yySeparator, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(CupertinoIcons.clock,
                      size: 18, color: context.yyTextTertiary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        color: context.yyTextPrimary,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  Icon(CupertinoIcons.arrow_up_left,
                      size: 14, color: context.yyTextTertiary),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 搜索结果
  Widget _buildResults(BuildContext context, PlayerState player) {
    if (_searching) {
      return const Center(
        child: CupertinoActivityIndicator(radius: 14),
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
              style: TextStyle(
                color: context.yyTextSecondary,
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '试试其他关键词',
              style: TextStyle(
                color: context.yyTextTertiary,
                fontSize: 15,
              ),
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
        return CupertinoListTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                HSLColor.fromAHSL(
                        1.0,
                        (song.title.hashCode % 360).toDouble(),
                        0.5,
                        0.4)
                    .toColor(),
                HSLColor.fromAHSL(
                        1.0,
                        ((song.title.hashCode + 40) % 360).toDouble(),
                        0.4,
                        0.3)
                    .toColor(),
              ]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: isActive
                ? const Icon(CupertinoIcons.waveform,
                    color: Colors.white, size: 18)
                : const Icon(CupertinoIcons.music_note,
                    color: Colors.white, size: 18),
          ),
          title: Text(
            song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isActive
                  ? YYColors.accentPrimary
                  : context.yyTextPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            '${song.artist} · ${song.album}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.yyTextTertiary,
              fontSize: 15,
            ),
          ),
          onTap: () =>
              ref.read(playerProvider.notifier).playSong(song, queue: _results),
          additionalInfo: GestureDetector(
            onTap: () => showSongActions(context, ref, song),
            child: Icon(
              CupertinoIcons.ellipsis,
              size: 20,
              color: context.yyTextTertiary,
            ),
          ),
        );
      },
    );
  }
}
