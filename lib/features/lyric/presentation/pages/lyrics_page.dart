import 'dart:math';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/theme.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../data/services/lyric_parser.dart';
import '../../data/services/lyric_service.dart';
import '../../../library/presentation/providers/library_provider.dart';
import '../widgets/lyric_view.dart';

/// 全屏歌词页 — 沉浸式背景 + 实时滚动歌词 + 自动在线获取
class LyricsPage extends ConsumerStatefulWidget {
  const LyricsPage({super.key});

  @override
  ConsumerState<LyricsPage> createState() => _LyricsPageState();
}

class _LyricsPageState extends ConsumerState<LyricsPage> {
  bool _isFetching = false;
  String? _fetchedLyrics;
  bool _fetchAttempted = false;

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final song = playerState.currentSong;

    if (song == null) {
      return Scaffold(
        backgroundColor: context.yyBgBase,
        body: Center(
          child: Text('暂无播放', style: TextStyle(color: context.yyTextSecondary)),
        ),
      );
    }

    // 基于歌曲名生成背景主色
    final hash = '${song.title}_${song.artist}'.hashCode;
    final random = Random(hash);
    final hue = random.nextDouble() * 360;
    final isDark = context.isDark;
    final bgColor = HSLColor.fromAHSL(1.0, hue, 0.5, isDark ? 0.2 : 0.75).toColor();

    // 解析歌词 — 优先 fetched，其次 song.lyrics
    final lrcText = _fetchedLyrics ?? song.lyrics;
    final lyrics = (lrcText != null && lrcText.isNotEmpty)
        ? LrcParser.parse(lrcText)
        : <LyricLine>[];

    // 自动获取歌词（仅在无歌词且未尝试过时）
    if (lyrics.isEmpty && !_fetchAttempted && !_isFetching) {
      _autoFetchLyrics(song.title, song.artist, song.album, song.duration, song.id);
    }

    return Scaffold(
      backgroundColor: context.yyBgBase,
      body: Stack(
        children: [
          // 背景
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.5,
                  colors: [bgColor, context.yyBgBase],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: Container(color: (isDark ? Colors.black : Colors.white).withValues(alpha: isDark ? 0.4 : 0.5)),
            ),
          ),
          // 主内容
          SafeArea(
            child: Column(
              children: [
                // 顶部栏
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(CupertinoIcons.chevron_down,
                            color: context.yyTextPrimary, size: 22),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              song.title,
                              style: TextStyle(
                                color: context.yyTextPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              song.artist,
                              style: TextStyle(
                                color: context.yyTextSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 手动搜索按钮
                      IconButton(
                        onPressed: _isFetching ? null : () {
                          _autoFetchLyrics(
                            song.title, song.artist, song.album, song.duration, song.id,
                            force: true,
                          );
                        },
                        icon: _isFetching
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2, color: YYColors.accentPrimary),
                              )
                            : Icon(CupertinoIcons.search,
                                color: context.yyTextSecondary, size: 20),
                      ),
                    ],
                  ),
                ),
                // 歌词区域
                Expanded(
                  child: _isFetching
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(color: YYColors.accentPrimary),
                              const SizedBox(height: 16),
                              Text('正在搜索歌词…',
                                  style: TextStyle(color: context.yyTextSecondary, fontSize: 14)),
                            ],
                          ),
                        )
                      : lyrics.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(CupertinoIcons.quote_bubble,
                                      size: 48, color: context.yyTextTertiary),
                                  const SizedBox(height: 16),
                                  Text('暂无歌词',
                                      style: TextStyle(color: context.yyTextTertiary, fontSize: 16)),
                                ],
                              ),
                            )
                          : LyricView(lyrics: lyrics),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 自动获取歌词
  Future<void> _autoFetchLyrics(
    String title, String artist, String album, Duration? duration, String songId, {
    bool force = false,
  }) async {
    if (_isFetching) return;
    if (!force) _fetchAttempted = true;

    setState(() => _isFetching = true);

    try {
      final lyricService = ref.read(lyricServiceProvider);
      final lrc = await lyricService.fetchLyrics(
        title: title,
        artist: artist,
        album: album,
        duration: duration,
      );

      if (lrc != null && lrc.isNotEmpty && mounted) {
        setState(() => _fetchedLyrics = lrc);
        // 持久化到数据库
        try {
          final db = ref.read(musicDatabaseProvider);
          await db.updateSongLyrics(songId, lrc);
        } catch (_) {
          // 非致命错误
        }
      }
    } catch (_) {
      // 静默失败
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }
}
