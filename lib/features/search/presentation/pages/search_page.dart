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
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
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
    setState(() { _query = value; _searching = true; });
    if (value.trim().isEmpty) {
      setState(() { _results = []; _searching = false; });
      return;
    }
    ref.read(searchHistoryProvider).addSearch(value);
    _loadHistory();
    final db = ref.read(musicDatabaseProvider);
    final results = await db.search(value);
    if (mounted) setState(() { _results = results; _searching = false; });
  }

  void _scheduleSearch(String value) => _doSearch(value);

  void _applyQuery(String value) {
    _controller.text = value;
    _doSearch(value);
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);

    return YYScenicBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: YYPanel(
                        padding: EdgeInsets.zero,
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          onChanged: _scheduleSearch,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                          decoration: InputDecoration(
                            hintText: '搜索歌曲、艺人、专辑',
                            hintStyle: const TextStyle(color: Colors.white24),
                            prefixIcon: const Icon(CupertinoIcons.search, color: Colors.white38, size: 20),
                            suffixIcon: _query.isNotEmpty ? IconButton(icon: const Icon(CupertinoIcons.clear_circled_solid, size: 18, color: Colors.white24), onPressed: () { _controller.clear(); _doSearch(''); }) : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => context.pop(),
                      child: const Text('取消', style: TextStyle(color: YYColors.accentPrimary, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: _query.isEmpty 
                  ? _buildIdleState(context) 
                  : _buildResults(context, player),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIdleState(BuildContext context) {
    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const YYIconBadge(icon: CupertinoIcons.search, color: Colors.white10, size: 64),
            const SizedBox(height: 24),
            Text('开始探索', style: context.yyTextTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('输入你想听的内容', style: TextStyle(color: context.yyTextSecondary)),
          ],
        ),
      ).animate().fadeIn();
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        YYSectionTitle(
          title: '最近搜索',
          trailing: IconButton(icon: const Icon(CupertinoIcons.trash, size: 18, color: Colors.white24), onPressed: () => ref.read(searchHistoryProvider).clearAll().then((_) => _loadHistory())),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _history.map((h) => YYPillButton(label: h, onTap: () => _applyQuery(h), compact: true)).toList(),
        ),
      ],
    );
  }

  Widget _buildResults(BuildContext context, PlayerState player) {
    if (_searching) return const Center(child: CupertinoActivityIndicator(color: YYColors.accentPrimary));
    
    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.nosign, color: Colors.white12, size: 48),
            const SizedBox(height: 16),
            Text('未找到相关结果', style: TextStyle(color: context.yyTextSecondary)),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final song = _results[index];
        return YYTrackRow(
          song: song,
          active: player.currentSong?.id == song.id,
          onTap: () {
            HapticFeedback.lightImpact();
            ref.read(playerProvider.notifier).playSong(song, queue: _results);
          },
          onLongPress: () => showSongActions(context, ref, song),
        ).animate().fadeIn(delay: (20 * index).ms).slideX(begin: 0.05);
      },
    );
  }
}

