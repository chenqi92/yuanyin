import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/theme.dart';
import '../../../../shared/utils/cover_art_resolver.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../data/services/lyric_parser.dart';
import '../../data/services/lyric_service.dart';
import '../../../library/presentation/providers/library_provider.dart';

/// Apple Music style full-screen lyrics page
class LyricsPage extends ConsumerStatefulWidget {
  const LyricsPage({super.key});

  @override
  ConsumerState<LyricsPage> createState() => _LyricsPageState();
}

class _LyricsPageState extends ConsumerState<LyricsPage> {
  bool _isFetching = false;
  String? _fetchedLyrics;
  bool _fetchAttempted = false;
  final ScrollController _scrollController = ScrollController();
  int _currentIndex = -1;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final song = playerState.currentSong;

    if (song == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            '暂无播放',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          ),
        ),
      );
    }

    final accent = YYSeedPalette.primary(song.title);

    // Parse lyrics
    final lrcText = _fetchedLyrics ?? song.lyrics;
    final lyrics = (lrcText != null && lrcText.isNotEmpty)
        ? LrcParser.parse(lrcText)
        : <LyricLine>[];

    // Auto-fetch lyrics
    if (lyrics.isEmpty && !_fetchAttempted && !_isFetching) {
      _autoFetchLyrics(
        song.title,
        song.artist,
        song.album,
        song.duration,
        song.id,
      );
    }

    // Track current lyric line
    final position = playerState.position;
    final newIndex = lyrics.isNotEmpty
        ? LrcParser.findCurrentIndex(lyrics, position)
        : -1;
    if (newIndex != _currentIndex && newIndex >= 0) {
      _currentIndex = newIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          final targetOffset = (newIndex * 56.0) - 160.0;
          _scrollController.animateTo(
            targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Blurred cover background
          if (yyBuildCoverImageProvider(song.coverUrl, filePath: song.filePath)
              case final provider?)
            Positioned.fill(
              child: Image(
                image: provider,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [accent.withValues(alpha: 0.6), Colors.black],
                    ),
                  ),
                ),
              ),
            )
          else
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [accent.withValues(alpha: 0.6), Colors.black],
                  ),
                ),
              ),
            ),
          // Blur + dark overlay
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: Container(color: Colors.black.withValues(alpha: 0.4)),
            ),
          ),
          // Main content
          SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          CupertinoIcons.chevron_down,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              song.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              song.artist,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Refresh button
                      IconButton(
                        onPressed: _isFetching
                            ? null
                            : () {
                                _autoFetchLyrics(
                                  song.title,
                                  song.artist,
                                  song.album,
                                  song.duration,
                                  song.id,
                                  force: true,
                                );
                              },
                        icon: _isFetching
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                CupertinoIcons.search,
                                color: Colors.white.withValues(alpha: 0.6),
                                size: 20,
                              ),
                      ),
                    ],
                  ),
                ),
                // Lyrics area
                Expanded(
                  child: _isFetching
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(
                                color: Colors.white,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '正在搜索歌词...',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : lyrics.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.quote_bubble,
                                size: 48,
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '暂无歌词',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 120),
                          itemCount: lyrics.length,
                          itemBuilder: (context, index) {
                            final line = lyrics[index];
                            final isCurrent = index == _currentIndex;

                            return GestureDetector(
                              onTap: () {
                                ref
                                    .read(playerProvider.notifier)
                                    .seek(line.time);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                child: Text(
                                  line.text,
                                  style: TextStyle(
                                    fontSize: isCurrent ? 24 : 18,
                                    fontWeight: isCurrent
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isCurrent
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.4),
                                    height: 1.4,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Auto-fetch lyrics
  Future<void> _autoFetchLyrics(
    String title,
    String artist,
    String album,
    Duration? duration,
    String songId, {
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
        // Persist to database
        try {
          final db = ref.read(musicDatabaseProvider);
          await db.updateSongLyrics(songId, lrc);
        } catch (_) {
          // Non-fatal
        }
      }
    } catch (_) {
      // Silent failure
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }
}
