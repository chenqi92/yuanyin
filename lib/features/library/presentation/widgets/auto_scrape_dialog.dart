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
import '../../../player/domain/entities/music_item.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../data/services/music_database_service.dart';
import '../../domain/entities/music_scraper_result.dart';
import '../../domain/entities/scraper_source_entity.dart';
import '../../presentation/providers/music_scraper_provider.dart';
import 'manual_music_scraper_page.dart';

/// 自动刮削对话框
///
/// 显示刮削进度和结果，允许用户选择下载封面和歌词
class AutoScrapeDialog extends ConsumerStatefulWidget {
  const AutoScrapeDialog({super.key, required this.music});

  final MusicItem music;

  /// 显示自动刮削对话框
  static Future<bool?> show(BuildContext context, MusicItem music) => showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AutoScrapeDialog(music: music),
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
  bool get _hasLyrics => widget.music.lyrics != null && widget.music.lyrics!.isNotEmpty;

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
    if (result.detail == null && result.cover == null && result.lyrics == null) {
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
      var completedSteps = 0;
      final totalSteps = (_downloadCover && _cover != null ? 1 : 0) +
          (_downloadLyrics && _lyrics != null ? 1 : 0);

      // 下载封面
      Uint8List? coverData;
      if (_downloadCover && _cover != null) {
        setState(() => _statusMessage = '下载封面...');
        coverData = await _downloadCoverData();
        if (coverData != null) {
          await _saveCoverFile(musicDir, baseName, coverData);
        }
        completedSteps++;
        if (totalSteps > 0) setState(() => _progress = completedSteps / totalSteps);
      }

      // 下载歌词
      if (_downloadLyrics && _lyrics != null && _lyrics!.hasLyrics) {
        setState(() => _statusMessage = '下载歌词...');
        await _saveLyricsFile(musicDir, baseName);
        completedSteps++;
        if (totalSteps > 0) setState(() => _progress = completedSteps / totalSteps);
      }

      // 更新数据库元数据
      if (_detail != null) {
        await _syncMetadataToDatabase(coverData);
      }

      // 更新当前播放状态
      _updateCurrentMusicIfNeeded(coverData);

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

  Future<void> _saveCoverFile(String musicDir, String baseName, Uint8List coverData) async {
    try {
      final ext = _cover!.coverUrl.contains('.png') ? 'png' : 'jpg';
      final folderCoverPath = p.join(musicDir, 'folder.$ext');
      final coverPath = File(folderCoverPath).existsSync()
          ? p.join(musicDir, '$baseName-cover.$ext')
          : folderCoverPath;
      await File(coverPath).writeAsBytes(coverData);
    } on Exception catch (_) {}
  }

  Future<void> _saveLyricsFile(String musicDir, String baseName) async {
    if (_lyrics == null || !_lyrics!.hasLyrics) return;
    try {
      final lrcContent = _lyrics!.lrcContent ?? _lyrics!.plainText ?? '';
      if (lrcContent.isEmpty) return;
      final lrcPath = p.join(musicDir, '$baseName.lrc');
      await File(lrcPath).writeAsString(lrcContent, encoding: utf8);
    } on Exception catch (_) {}
  }

  Future<void> _syncMetadataToDatabase(Uint8List? coverData) async {
    final sourceId = widget.music.sourceId;
    if (sourceId == null || _detail == null) return;
    try {
      final db = MusicDatabaseService();
      await db.init();
      final existing = await db.get(sourceId, widget.music.filePath ?? '');
      if (existing != null) {
        await db.upsert(existing.copyWith(
          title: (existing.title == null || existing.title!.isEmpty) ? _detail?.title : existing.title,
          artist: (existing.artist == null || existing.artist!.isEmpty) ? _detail?.artist : existing.artist,
          album: (existing.album == null || existing.album!.isEmpty) ? _detail?.album : existing.album,
          year: existing.year ?? _detail?.year,
          trackNumber: existing.trackNumber ?? _detail?.trackNumber,
          genre: (existing.genre == null || existing.genre!.isEmpty)
              ? _detail?.genres?.join(', ')
              : existing.genre,
          lastUpdated: DateTime.now(),
        ));
      }
    } on Exception catch (_) {}
  }

  void _updateCurrentMusicIfNeeded(Uint8List? coverData) {
    final playerState = ref.read(playerProvider);
    if (playerState.currentSong?.id != widget.music.id) return;
    final current = playerState.currentSong!;
    ref.read(playerProvider.notifier);
    // Update via playerProvider is complex — just rely on DB sync for now
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

    return AlertDialog(
      backgroundColor: isDark ? context.yyBgElevated : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        Icon(CupertinoIcons.sparkles, color: YYColors.accentPrimary, size: 22),
        const SizedBox(width: 10),
        const Expanded(child: Text('自动识别', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
        GestureDetector(
          onTap: _openManualScraper,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: YYColors.accentPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('手动', style: TextStyle(color: YYColors.accentPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
      content: SizedBox(
        width: 320,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
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
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_errorMessage!, style: const TextStyle(fontSize: 12, color: Colors.red)),
            ),
          ],
        ]),
      ),
      actionsOverflowButtonSpacing: 8,
      actionsAlignment: MainAxisAlignment.end,
      actions: _buildActions(isDark),
    );
  }

  Widget _buildMusicInfo(bool isDark) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: YYColors.accentPrimary.withValues(alpha: 0.1),
            ),
            clipBehavior: Clip.antiAlias,
            child: widget.music.coverUrl != null
                ? Image.file(File(widget.music.coverUrl!.replaceFirst('file://', '')),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(CupertinoIcons.music_note, color: YYColors.accentPrimary))
                : Icon(CupertinoIcons.music_note, color: YYColors.accentPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.music.title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w600, color: context.yyTextPrimary)),
            const SizedBox(height: 2),
            Text(widget.music.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: context.yyTextSecondary)),
          ])),
        ]),
      );

  Widget _buildStatus(bool isDark) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (_status == _ScrapeStatus.searching || _status == _ScrapeStatus.downloading)
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: YYColors.accentPrimary))
          else if (_status == _ScrapeStatus.found || _status == _ScrapeStatus.completed)
            const Icon(CupertinoIcons.checkmark_circle_fill, size: 16, color: Colors.green)
          else if (_status == _ScrapeStatus.notFound)
            Icon(CupertinoIcons.search, size: 16, color: Colors.orange[700])
          else if (_status == _ScrapeStatus.error)
            const Icon(CupertinoIcons.exclamationmark_circle_fill, size: 16, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(child: Text(_statusMessage, style: TextStyle(fontSize: 13, color: context.yyTextSecondary))),
        ]),
        if (_progress != null && (_status == _ScrapeStatus.searching || _status == _ScrapeStatus.downloading)) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _progress,
              backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey[200],
              color: YYColors.accentPrimary,
              minHeight: 3,
            ),
          ),
        ],
      ]);

  Widget _buildResults(bool isDark) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('找到以下内容:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: context.yyTextSecondary)),
        const SizedBox(height: 8),
        if (_detail != null)
          _buildResultRow(isDark, CupertinoIcons.info, '元数据',
            '${_detail!.title} - ${_detail!.artist ?? "未知"}', source: _detail!.source),
        if (_cover != null)
          _buildResultRow(isDark, CupertinoIcons.photo, '封面${_hasCover ? " (已有)" : ""}',
            '来自 ${_cover!.source.displayName}', source: _cover!.source,
            trailing: CupertinoSwitch(value: _downloadCover, activeTrackColor: YYColors.accentPrimary,
              onChanged: (v) => setState(() => _downloadCover = v))),
        if (_lyrics != null && _lyrics!.hasLyrics)
          _buildResultRow(isDark, CupertinoIcons.text_quote, '歌词${_hasLyrics ? " (已有)" : ""}',
            _lyrics!.isLrc ? 'LRC (时间同步)' : '纯文本', source: _lyrics!.source,
            trailing: CupertinoSwitch(value: _downloadLyrics, activeTrackColor: YYColors.accentPrimary,
              onChanged: (v) => setState(() => _downloadLyrics = v))),
      ]);

  Widget _buildResultRow(bool isDark, IconData icon, String label, String value,
      {ScraperType? source, Widget? trailing}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, size: 18, color: context.yyTextTertiary),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: context.yyTextPrimary)),
            if (source != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(color: source.themeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(3)),
                child: Text(source.displayName, style: TextStyle(fontSize: 9, color: source.themeColor, fontWeight: FontWeight.w500)),
              ),
            ],
          ]),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: context.yyTextTertiary)),
        ])),
        if (trailing != null) trailing,
      ]),
    );

  List<Widget> _buildActions(bool isDark) {
    switch (_status) {
      case _ScrapeStatus.searching:
        return [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('取消')),
        ];
      case _ScrapeStatus.found:
        final hasAction = (_downloadCover && _cover != null) || (_downloadLyrics && _lyrics != null);
        return [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('取消')),
          if (hasAction)
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              color: YYColors.accentPrimary,
              borderRadius: BorderRadius.circular(10),
              onPressed: _applyResults,
              child: const Text('应用', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
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
            child: const Text('完成', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ];
      case _ScrapeStatus.notFound:
      case _ScrapeStatus.error:
        return [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('关闭')),
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
            child: const Text('重试', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ];
    }
  }
}

enum _ScrapeStatus { searching, found, downloading, completed, notFound, error }
