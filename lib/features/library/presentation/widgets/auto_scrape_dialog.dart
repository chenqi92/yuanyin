import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../app/theme/theme.dart';
import '../../../../shared/widgets/gradient_cover.dart';
import '../../../../shared/widgets/native_overlay_sheet.dart';
import '../../../player/domain/entities/music_item.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../data/services/music_database_service.dart';
import '../../domain/entities/music_scraper_result.dart';
import '../../domain/entities/scraper_source_entity.dart';
import '../../presentation/providers/music_scraper_provider.dart';
import '../pages/manual_music_scraper_page.dart';

/// 自动刮削对话框
///
/// 显示刮削进度和结果，允许用户选择下载封面和歌词
class AutoScrapeDialog extends ConsumerStatefulWidget {
  const AutoScrapeDialog({super.key, required this.music});

  final MusicItem music;

  /// 显示自动刮削对话框
  static Future<bool?> show(BuildContext context, MusicItem music) =>
      showYYCupertinoPopup<bool>(
        context: context,
        builder: (context) => SizedBox(
          width: double.infinity,
          child: AutoScrapeDialog(music: music),
        ),
      );

  @override
  ConsumerState<AutoScrapeDialog> createState() => _AutoScrapeDialogState();
}

class _AutoScrapeDialogState extends ConsumerState<AutoScrapeDialog> {
  _ScrapeStatus _status = _ScrapeStatus.searching;
  String _statusMessage = '正在搜索...';
  double? _progress;

  MusicScraperDetail? _detail;
  CoverScraperResult? _cover;
  LyricScraperResult? _lyrics;

  bool _downloadCover = true;
  bool _downloadLyrics = true;
  String? _errorMessage;

  bool get _hasCover => widget.music.coverUrl != null;
  bool get _hasLyrics =>
      widget.music.lyrics != null && widget.music.lyrics!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _startScraping();
  }

  Future<void> _startScraping() async {
    try {
      final manager = ref.read(musicScraperManagerProvider);
      await manager.init();
      await _searchByMetadata();
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _status = _ScrapeStatus.error;
          _statusMessage = '刮削失败';
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _searchByMetadata() async {
    final title = widget.music.title;
    final artist = widget.music.artist;

    setState(() {
      _statusMessage = '搜索 "$title"...';
      _progress = 0.2;
    });

    final manager = ref.read(musicScraperManagerProvider);
    final result = await manager.scrape(
      title: title,
      artist: artist.isNotEmpty ? artist : null,
      album: widget.music.album.isNotEmpty ? widget.music.album : null,
      getCover: true,
      getLyrics: true,
    );

    _handleScrapeResult(result);
  }

  void _handleScrapeResult(MusicScrapeResult result) {
    if (!mounted) return;
    if (result.detail == null &&
        result.cover == null &&
        result.lyrics == null) {
      setState(() {
        _status = _ScrapeStatus.notFound;
        _statusMessage = '未找到匹配结果';
        if (result.errors.isNotEmpty) _errorMessage = result.errors.join('\n');
      });
      return;
    }
    setState(() {
      _status = _ScrapeStatus.found;
      _statusMessage = '找到匹配结果';
      _progress = 1.0;
      _detail = result.detail;
      _cover = result.cover;
      _lyrics = result.lyrics;
      if (_hasCover) _downloadCover = false;
      if (_hasLyrics) _downloadLyrics = false;
    });
  }

  Future<void> _applyResults() async {
    setState(() {
      _status = _ScrapeStatus.downloading;
      _statusMessage = '正在处理...';
      _progress = 0;
    });

    try {
      final filePath = widget.music.filePath;
      if (filePath == null) throw Exception('无法获取文件路径');

      final musicDir = p.dirname(filePath);
      final baseName = p.basenameWithoutExtension(filePath);
      String? savedCoverPath;
      String? savedLyrics;
      var completedSteps = 0;
      final totalSteps =
          (_downloadCover && _cover != null ? 1 : 0) +
          (_downloadLyrics && _lyrics != null ? 1 : 0);

      // 下载封面
      Uint8List? coverData;
      if (_downloadCover && _cover != null) {
        setState(() => _statusMessage = '下载封面...');
        coverData = await _downloadCoverData();
        if (coverData != null) {
          savedCoverPath = await _saveCoverFile(musicDir, baseName, coverData);
        }
        completedSteps++;
        if (totalSteps > 0) {
          setState(() => _progress = completedSteps / totalSteps);
        }
      }

      // 下载歌词
      if (_downloadLyrics && _lyrics != null && _lyrics!.hasLyrics) {
        setState(() => _statusMessage = '下载歌词...');
        savedLyrics = await _saveLyricsFile(musicDir, baseName);
        completedSteps++;
        if (totalSteps > 0) {
          setState(() => _progress = completedSteps / totalSteps);
        }
      }

      // 更新数据库元数据
      if (_detail != null || savedCoverPath != null || savedLyrics != null) {
        await _syncMetadataToDatabase(savedCoverPath, savedLyrics);
      }

      // 更新当前播放状态
      await _updateCurrentMusicIfNeeded();

      setState(() {
        _status = _ScrapeStatus.completed;
        _statusMessage = '处理完成';
        _progress = 1.0;
      });

      await Future<void>.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.of(context).pop(true);
    } on Exception catch (e) {
      setState(() {
        _status = _ScrapeStatus.error;
        _statusMessage = '处理失败';
        _errorMessage = e.toString();
      });
    }
  }

  Future<Uint8List?> _downloadCoverData() async {
    if (_cover == null) return null;
    try {
      final dio = Dio();
      final response = await dio.get<List<int>>(
        _cover!.coverUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      if (response.data == null) return null;
      return Uint8List.fromList(response.data!);
    } on Exception {
      return null;
    }
  }

  Future<String?> _saveCoverFile(
    String musicDir,
    String baseName,
    Uint8List coverData,
  ) async {
    try {
      final ext = _cover!.coverUrl.contains('.png') ? 'png' : 'jpg';
      final coverPath = p.join(musicDir, '$baseName.$ext');
      await File(coverPath).writeAsBytes(coverData);
      return coverPath;
    } on Exception catch (_) {
      return null;
    }
  }

  Future<String?> _saveLyricsFile(String musicDir, String baseName) async {
    if (_lyrics == null || !_lyrics!.hasLyrics) {
      return null;
    }
    try {
      final lrcContent = _lyrics!.lrcContent ?? _lyrics!.plainText ?? '';
      if (lrcContent.isEmpty) {
        return null;
      }
      final lrcPath = p.join(musicDir, '$baseName.lrc');
      await File(lrcPath).writeAsString(lrcContent, encoding: utf8);
      return lrcContent;
    } on Exception catch (_) {
      return null;
    }
  }

  Future<void> _syncMetadataToDatabase(
    String? savedCoverPath,
    String? lyricsText,
  ) async {
    try {
      final db = MusicDatabaseService();
      final updated = widget.music.copyWith(
        title: widget.music.title.isEmpty ? _detail?.title : widget.music.title,
        artist: widget.music.artist.isEmpty
            ? _detail?.artist
            : widget.music.artist,
        album: widget.music.album.isEmpty ? _detail?.album : widget.music.album,
        year: widget.music.year ?? _detail?.year,
        trackNumber: widget.music.trackNumber ?? _detail?.trackNumber,
        genre: (widget.music.genre == null || widget.music.genre!.isEmpty)
            ? _detail?.genres?.join(', ')
            : widget.music.genre,
        coverUrl: savedCoverPath ?? widget.music.coverUrl,
        lyrics: lyricsText ?? widget.music.lyrics,
      );
      await db.updateSong(updated);
      if (lyricsText != null && lyricsText.isNotEmpty) {
        await db.updateSongLyrics(widget.music.id, lyricsText);
      }
    } on Exception catch (_) {}
  }

  Future<void> _updateCurrentMusicIfNeeded() async {
    final playerState = ref.read(playerProvider);
    if (playerState.currentSong?.id != widget.music.id) return;
    await ref.read(playerProvider.notifier).refreshCurrentSong();
  }

  void _openManualScraper() {
    Navigator.of(context).pop(false);
    Navigator.of(context).push(
      CupertinoPageRoute<bool>(
        builder: (context) => ManualMusicScraperPage(music: widget.music),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.sparkles,
                color: YYColors.accentPrimary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                '自动识别',
                style: TextStyle(
                  color: context.yyTextPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                color: YYColors.accentPrimary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(YYRadius.full),
                onPressed: _openManualScraper,
                child: const Text(
                  '手动',
                  style: TextStyle(
                    color: YYColors.accentPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildMusicInfo(isDark),
          const SizedBox(height: 16),
          _buildStatus(isDark),
          if (_status == _ScrapeStatus.found) ...[
            const SizedBox(height: 16),
            _buildResults(isDark),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: _buildActions(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildMusicInfo(bool isDark) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: GradientCover(
            seed: '${widget.music.title}_${widget.music.artist}',
            coverUrl: widget.music.coverUrl,
            filePath: widget.music.filePath,
            size: 48,
            borderRadius: 10,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.music.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: context.yyTextPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.music.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: context.yyTextSecondary),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildStatus(bool isDark) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          if (_status == _ScrapeStatus.searching ||
              _status == _ScrapeStatus.downloading)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: YYColors.accentPrimary,
              ),
            )
          else if (_status == _ScrapeStatus.found ||
              _status == _ScrapeStatus.completed)
            const Icon(
              CupertinoIcons.checkmark_circle_fill,
              size: 16,
              color: Colors.green,
            )
          else if (_status == _ScrapeStatus.notFound)
            Icon(CupertinoIcons.search, size: 16, color: Colors.orange[700])
          else if (_status == _ScrapeStatus.error)
            const Icon(
              CupertinoIcons.exclamationmark_circle_fill,
              size: 16,
              color: Colors.red,
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _statusMessage,
              style: TextStyle(fontSize: 13, color: context.yyTextSecondary),
            ),
          ),
        ],
      ),
      if (_progress != null &&
          (_status == _ScrapeStatus.searching ||
              _status == _ScrapeStatus.downloading)) ...[
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _progress,
            backgroundColor: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.grey[200],
            color: YYColors.accentPrimary,
            minHeight: 3,
          ),
        ),
      ],
    ],
  );

  Widget _buildResults(bool isDark) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '找到以下内容:',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: context.yyTextSecondary,
        ),
      ),
      const SizedBox(height: 8),
      if (_detail != null)
        _buildResultRow(
          isDark,
          CupertinoIcons.info,
          '元数据',
          '${_detail!.title} - ${_detail!.artist ?? "未知"}',
          source: _detail!.source,
        ),
      if (_cover != null)
        _buildResultRow(
          isDark,
          CupertinoIcons.photo,
          '封面${_hasCover ? " (已有)" : ""}',
          '来自 ${_cover!.source.displayName}',
          source: _cover!.source,
          trailing: CupertinoSwitch(
            value: _downloadCover,
            activeTrackColor: YYColors.accentPrimary,
            onChanged: (v) => setState(() => _downloadCover = v),
          ),
        ),
      if (_lyrics != null && _lyrics!.hasLyrics)
        _buildResultRow(
          isDark,
          CupertinoIcons.text_quote,
          '歌词${_hasLyrics ? " (已有)" : ""}',
          _lyrics!.isLrc ? 'LRC (时间同步)' : '纯文本',
          source: _lyrics!.source,
          trailing: CupertinoSwitch(
            value: _downloadLyrics,
            activeTrackColor: YYColors.accentPrimary,
            onChanged: (v) => setState(() => _downloadLyrics = v),
          ),
        ),
    ],
  );

  Widget _buildResultRow(
    bool isDark,
    IconData icon,
    String label,
    String value, {
    ScraperType? source,
    Widget? trailing,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(icon, size: 18, color: context.yyTextTertiary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: context.yyTextPrimary,
                    ),
                  ),
                  if (source != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: source.themeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        source.displayName,
                        style: TextStyle(
                          fontSize: 9,
                          color: source.themeColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: context.yyTextTertiary),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[trailing],
      ],
    ),
  );

  List<Widget> _buildActions(bool isDark) {
    switch (_status) {
      case _ScrapeStatus.searching:
        return [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
        ];
      case _ScrapeStatus.found:
        final hasAction =
            (_downloadCover && _cover != null) ||
            (_downloadLyrics && _lyrics != null);
        return [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          if (hasAction)
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              color: YYColors.accentPrimary,
              borderRadius: BorderRadius.circular(10),
              onPressed: _applyResults,
              child: const Text(
                '应用',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
        ];
      case _ScrapeStatus.downloading:
        return [];
      case _ScrapeStatus.completed:
        return [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            color: YYColors.accentPrimary,
            borderRadius: BorderRadius.circular(10),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              '完成',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ];
      case _ScrapeStatus.notFound:
      case _ScrapeStatus.error:
        return [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('关闭'),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            color: YYColors.accentPrimary,
            borderRadius: BorderRadius.circular(10),
            onPressed: () {
              setState(() {
                _status = _ScrapeStatus.searching;
                _statusMessage = '正在搜索...';
                _progress = null;
                _errorMessage = null;
              });
              _startScraping();
            },
            child: const Text(
              '重试',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ];
    }
  }
}

enum _ScrapeStatus { searching, found, downloading, completed, notFound, error }
