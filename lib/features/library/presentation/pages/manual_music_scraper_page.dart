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
import '../../../../shared/widgets/modern_music_ui.dart';
import '../../../player/domain/entities/music_item.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../data/services/music_database_service.dart';
import '../../domain/entities/music_scraper_result.dart';
import '../../domain/entities/scraper_source_entity.dart';
import '../../presentation/providers/music_scraper_provider.dart';

/// Manual music scraper page -- iOS native style
class ManualMusicScraperPage extends ConsumerStatefulWidget {
  const ManualMusicScraperPage({super.key, required this.music});

  final MusicItem music;

  @override
  ConsumerState<ManualMusicScraperPage> createState() =>
      _ManualMusicScraperPageState();
}

class _ManualMusicScraperPageState
    extends ConsumerState<ManualMusicScraperPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _artistController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isSearching = false;
  bool _isLoadingDetail = false;
  bool _isScraping = false;
  String? _errorMessage;

  List<MusicScraperItem> _searchResults = [];
  int _totalResultCount = 0;

  MusicScraperItem? _selectedItem;
  MusicScraperDetail? _selectedDetail;
  LyricScraperResult? _selectedLyrics;
  CoverScraperResult? _selectedCover;

  bool _downloadCover = true;
  bool _downloadLyrics = true;

  int get _musicDurationMs => widget.music.duration?.inMilliseconds ?? 0;
  bool get _hasCover => widget.music.coverUrl != null;
  bool get _hasLyrics =>
      widget.music.lyrics != null && widget.music.lyrics!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_hasCover) _downloadCover = false;
    if (_hasLyrics) _downloadLyrics = false;
    _titleController.text = widget.music.title;
    _artistController.text = widget.music.artist;
    WidgetsBinding.instance.addPostFrameCallback((_) => _search());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ====== Business Logic (preserved) ======

  Future<void> _search() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _searchResults.clear();
      _totalResultCount = 0;
      _clearSelection();
    });

    try {
      final manager = ref.read(musicScraperManagerProvider);
      await manager.init();
      final results = await manager.search(
        title,
        artist: _artistController.text.trim().isNotEmpty
            ? _artistController.text.trim()
            : null,
        limit: 30,
      );

      final allItems = <MusicScraperItem>[];
      for (final result in results) {
        allItems.addAll(result.items);
      }

      final sources = await manager.getSources();
      final sourcePriorities = <ScraperType, int>{};
      for (final source in sources) {
        sourcePriorities[source.type] = source.priority;
      }

      _sortByDurationMatch(allItems, sourcePriorities);

      setState(() {
        _searchResults = allItems;
        _totalResultCount = allItems.length;
        _isSearching = false;
      });
    } on Exception catch (e) {
      setState(() {
        _errorMessage = '搜索失败: $e';
        _isSearching = false;
      });
    }
  }

  void _sortByDurationMatch(
    List<MusicScraperItem> items,
    Map<ScraperType, int> sourcePriorities,
  ) {
    final hasMusicDuration = _musicDurationMs > 0;
    items.sort((a, b) {
      if (hasMusicDuration) {
        final diffA = _getDurationDiff(a);
        final diffB = _getDurationDiff(b);
        if (diffA != diffB) return diffA.compareTo(diffB);
      } else {
        final hasA = a.durationMs != null && a.durationMs! > 0;
        final hasB = b.durationMs != null && b.durationMs! > 0;
        if (hasA != hasB) return hasA ? -1 : 1;
      }
      final priorityA = sourcePriorities[a.source] ?? 999;
      final priorityB = sourcePriorities[b.source] ?? 999;
      if (priorityA != priorityB) return priorityA.compareTo(priorityB);
      return a.title.compareTo(b.title);
    });
  }

  int _getDurationDiff(MusicScraperItem item) {
    if (item.durationMs == null || item.durationMs == 0) return 999999999;
    return (item.durationMs! - _musicDurationMs).abs();
  }

  double _getMatchPercent(MusicScraperItem item) {
    if (_musicDurationMs <= 0 ||
        item.durationMs == null ||
        item.durationMs == 0) {
      return 0;
    }
    final diff = _getDurationDiff(item);
    if (diff <= 5000) return 100;
    if (diff >= 60000) return 0;
    return ((60000 - diff) / 550).clamp(0, 100);
  }

  String _formatDurationDiff(MusicScraperItem item) {
    if (_musicDurationMs <= 0 ||
        item.durationMs == null ||
        item.durationMs == 0) {
      return '';
    }
    final diffSec = (item.durationMs! - _musicDurationMs) ~/ 1000;
    if (diffSec.abs() < 1) return '\u00b10s';
    return diffSec > 0 ? '+${diffSec}s' : '${diffSec}s';
  }

  void _clearSelection() {
    _selectedItem = null;
    _selectedDetail = null;
    _selectedLyrics = null;
    _selectedCover = null;
  }

  Future<void> _selectItem(MusicScraperItem item) async {
    if (_selectedItem?.externalId == item.externalId) {
      setState(_clearSelection);
      return;
    }

    setState(() {
      _selectedItem = item;
      _isLoadingDetail = true;
      _errorMessage = null;
    });

    try {
      final manager = ref.read(musicScraperManagerProvider);
      final detail = await manager.getDetail(item.externalId, item.source);

      LyricScraperResult? lyrics;
      if (item.source.supportsLyrics) {
        final sources = await manager.getSources();
        final source = sources.where((s) => s.type == item.source).firstOrNull;
        if (source != null) {
          final scraper = await manager.getScraper(source.id);
          if (scraper != null) {
            lyrics = await scraper.getLyrics(item.externalId);
          }
        }
      }

      CoverScraperResult? cover;
      if (item.coverUrl != null) {
        cover = CoverScraperResult(
          source: item.source,
          coverUrl: item.coverUrl!,
        );
      }

      setState(() {
        _selectedDetail = detail;
        _selectedLyrics = lyrics;
        _selectedCover = cover;
        _isLoadingDetail = false;
      });
    } on Exception catch (e) {
      setState(() {
        _errorMessage = '获取详情失败: $e';
        _isLoadingDetail = false;
      });
    }
  }

  Future<void> _confirmAndScrape() async {
    if (_selectedDetail == null &&
        _selectedCover == null &&
        _selectedLyrics == null) {
      return;
    }

    final filePath = widget.music.filePath;
    if (filePath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('无法获取文件路径'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isScraping = true);

    try {
      final musicDir = p.dirname(filePath);
      final baseName = p.basenameWithoutExtension(filePath);
      Uint8List? coverData;
      String? savedCoverPath;
      String? savedLyrics;

      if (_downloadCover && _selectedCover != null) {
        coverData = await _downloadCoverData();
        if (coverData != null) {
          savedCoverPath = await _saveCoverFile(musicDir, baseName, coverData);
        }
      }

      if (_downloadLyrics && (_selectedLyrics?.hasLyrics ?? false)) {
        savedLyrics = await _saveLyricsFile(musicDir, baseName);
      }

      if (_selectedDetail != null) {
        await _syncMetadataToDatabase(savedCoverPath, savedLyrics);
      } else if (savedCoverPath != null || savedLyrics != null) {
        await _syncMetadataToDatabase(savedCoverPath, savedLyrics);
      }

      await ref.read(playerProvider.notifier).refreshCurrentSong();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('刮削完成'),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      Navigator.pop(context, true);
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('刮削失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isScraping = false);
    }
  }

  Future<Uint8List?> _downloadCoverData() async {
    if (_selectedCover == null) return null;
    try {
      final dio = Dio();
      final response = await dio.get<List<int>>(
        _selectedCover!.coverUrl,
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
      final ext = _selectedCover!.coverUrl.contains('.png') ? 'png' : 'jpg';
      final coverPath = p.join(musicDir, '$baseName.$ext');
      await File(coverPath).writeAsBytes(coverData);
      return coverPath;
    } on Exception catch (_) {
      return null;
    }
  }

  Future<String?> _saveLyricsFile(String musicDir, String baseName) async {
    if (_selectedLyrics == null || !_selectedLyrics!.hasLyrics) {
      return null;
    }
    try {
      final lrcContent =
          _selectedLyrics!.lrcContent ?? _selectedLyrics!.plainText ?? '';
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
        title: widget.music.title.isEmpty
            ? _selectedDetail?.title
            : widget.music.title,
        artist: widget.music.artist.isEmpty
            ? _selectedDetail?.artist
            : widget.music.artist,
        album: widget.music.album.isEmpty
            ? _selectedDetail?.album
            : widget.music.album,
        year: widget.music.year ?? _selectedDetail?.year,
        trackNumber: widget.music.trackNumber ?? _selectedDetail?.trackNumber,
        genre: (widget.music.genre == null || widget.music.genre!.isEmpty)
            ? _selectedDetail?.genres?.join(', ')
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

  // ====== UI ======

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: context.yyBgBase,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: context.yyBgBase.withValues(alpha: 0.9),
        border: Border(
          bottom: BorderSide(color: context.yySeparator, width: 0.5),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          child: Icon(
            CupertinoIcons.chevron_back,
            color: YYColors.accentPrimary,
            size: 22,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        middle: Text(
          '手动搜索',
          style: TextStyle(
            color: context.yyTextPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: _totalResultCount > 0
            ? Text(
                '$_totalResultCount 个结果',
                style: TextStyle(color: context.yyTextTertiary, fontSize: 13),
              )
            : null,
      ),
      child: SafeArea(
        bottom: false,
        child: YYScenicBackground(
          child: Column(
            children: [
              _buildCompactFileInfo(context),
              _buildSearchBar(context),
              Expanded(child: _buildSearchResults(context)),
              if (_selectedItem != null) _buildSelectionPanel(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactFileInfo(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: YYLiquidGlass(
        thin: true,
        radius: 22,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        color: context.yyBgElevated.withValues(alpha: 0.72),
        child: Row(
          children: [
            SizedBox(
              width: 42,
              height: 42,
              child: GradientCover(
                seed: '${widget.music.title}_${widget.music.artist}',
                coverUrl: widget.music.coverUrl,
                filePath: widget.music.filePath,
                size: 42,
                borderRadius: 12,
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
                      color: context.yyTextPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (widget.music.artist.isNotEmpty)
                        Text(
                          widget.music.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.yyTextTertiary,
                            fontSize: 12,
                          ),
                        ),
                      if (_musicDurationMs > 0)
                        YYTag(
                          text: _formatDuration(_musicDurationMs),
                          color: YYColors.accentPrimary,
                          icon: CupertinoIcons.time,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: YYLiquidGlass(
        thin: true,
        radius: 24,
        padding: const EdgeInsets.all(10),
        color: context.yyBgElevated.withValues(alpha: 0.70),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: CupertinoTextField(
                controller: _titleController,
                placeholder: '歌曲名称',
                prefix: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Icon(
                    CupertinoIcons.music_note,
                    size: 16,
                    color: context.yyTextTertiary,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: context.isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(10),
                ),
                style: TextStyle(color: context.yyTextPrimary, fontSize: 14),
                placeholderStyle: TextStyle(
                  color: context.yyTextTertiary,
                  fontSize: 14,
                ),
                onSubmitted: (_) => _search(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: CupertinoTextField(
                controller: _artistController,
                placeholder: '艺术家',
                prefix: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Icon(
                    CupertinoIcons.person,
                    size: 16,
                    color: context.yyTextTertiary,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: context.isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(10),
                ),
                style: TextStyle(color: context.yyTextPrimary, fontSize: 14),
                placeholderStyle: TextStyle(
                  color: context.yyTextTertiary,
                  fontSize: 14,
                ),
                onSubmitted: (_) => _search(),
              ),
            ),
            const SizedBox(width: 8),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(42, 42),
              color: YYColors.accentPrimary,
              borderRadius: BorderRadius.circular(14),
              onPressed: _isSearching ? null : _search,
              child: _isSearching
                  ? const CupertinoActivityIndicator(
                      color: Colors.white,
                      radius: 10,
                    )
                  : const Icon(
                      CupertinoIcons.search,
                      size: 18,
                      color: Colors.white,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context) {
    if (_isSearching) {
      return Center(
        child: CupertinoActivityIndicator(
          radius: 14,
          color: context.yyTextSecondary,
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.exclamationmark_triangle,
              size: 48,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.yyTextSecondary),
            ),
            const SizedBox(height: 16),
            CupertinoButton(
              color: YYColors.accentPrimary,
              onPressed: _search,
              child: const Text('重试', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.search,
              size: 48,
              color: context.yyTextTertiary,
            ),
            const SizedBox(height: 12),
            Text(
              '未找到结果',
              style: TextStyle(
                color: context.yyTextSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '尝试调整搜索关键词',
              style: TextStyle(color: context.yyTextTertiary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final item = _searchResults[index];
        final isSelected = _selectedItem?.externalId == item.externalId;
        return _buildResultCard(item, isSelected);
      },
    );
  }

  Widget _buildResultCard(MusicScraperItem item, bool isSelected) {
    final matchPercent = _getMatchPercent(item);
    final durationDiff = _formatDurationDiff(item);
    final hasHighMatch = matchPercent >= 90;

    return GestureDetector(
      onTap: () => _selectItem(item),
      child: YYLiquidGlass(
        thin: true,
        margin: const EdgeInsets.only(bottom: 8),
        radius: 20,
        color: isSelected
            ? YYColors.accentPrimary.withValues(
                alpha: context.isDark ? 0.16 : 0.10,
              )
            : context.yyBgElevated.withValues(alpha: 0.68),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Cover + source badge
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: item.source.themeColor.withValues(alpha: 0.1),
              ),
              child: Stack(
                children: [
                  if (item.coverUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        item.coverUrl!,
                        fit: BoxFit.cover,
                        width: 48,
                        height: 48,
                        errorBuilder: (context, error, stackTrace) => Center(
                          child: Icon(
                            CupertinoIcons.music_note,
                            color: item.source.themeColor,
                            size: 20,
                          ),
                        ),
                      ),
                    )
                  else
                    Center(
                      child: Icon(
                        CupertinoIcons.music_note,
                        color: item.source.themeColor,
                        size: 20,
                      ),
                    ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: item.source.themeColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(6),
                          bottomRight: Radius.circular(8),
                        ),
                      ),
                      child: Icon(
                        item.source.icon,
                        size: 9,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.yyTextPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (item.artist != null) item.artist!,
                      if (item.album != null) item.album!,
                    ].join(' \u00b7 '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.yyTextTertiary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: item.source.themeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          item.source.displayName,
                          style: TextStyle(
                            fontSize: 9,
                            color: item.source.themeColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (item.durationText.isNotEmpty)
                        Text(
                          item.durationText,
                          style: TextStyle(
                            fontSize: 10,
                            color: context.yyTextTertiary,
                          ),
                        ),
                      if (item.source.supportsLyrics) ...[
                        const SizedBox(width: 6),
                        Icon(
                          CupertinoIcons.text_quote,
                          size: 11,
                          color: Colors.cyan[context.isDark ? 300 : 700],
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Match indicator
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (matchPercent > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: hasHighMatch
                          ? Colors.green.withValues(alpha: 0.15)
                          : (matchPercent >= 50
                                ? Colors.orange.withValues(alpha: 0.15)
                                : Colors.grey.withValues(alpha: 0.15)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${matchPercent.toInt()}%',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: hasHighMatch
                                ? Colors.green
                                : (matchPercent >= 50
                                      ? Colors.orange
                                      : Colors.grey),
                          ),
                        ),
                        if (durationDiff.isNotEmpty)
                          Text(
                            durationDiff,
                            style: TextStyle(
                              fontSize: 9,
                              color: hasHighMatch
                                  ? Colors.green
                                  : (matchPercent >= 50
                                        ? Colors.orange
                                        : Colors.grey),
                            ),
                          ),
                      ],
                    ),
                  )
                else
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 16,
                    color: context.yyTextTertiary,
                  ),
                if (isSelected)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Icon(
                      CupertinoIcons.checkmark_circle_fill,
                      color: YYColors.accentPrimary,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionPanel(BuildContext context) {
    final hasContent =
        _selectedDetail != null ||
        _selectedCover != null ||
        _selectedLyrics != null;

    return YYLiquidGlass(
      thin: true,
      radius: 30,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.zero,
      color: context.yyBgElevated.withValues(alpha: 0.80),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isLoadingDetail)
              LinearProgressIndicator(
                color: YYColors.accentPrimary,
                minHeight: 2,
              )
            else if (hasContent)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  children: [
                    // Selected item info
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: _selectedItem?.source.themeColor.withValues(
                              alpha: 0.1,
                            ),
                          ),
                          child: _selectedCover?.coverUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    _selectedCover!.coverUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) => Icon(
                                          CupertinoIcons.music_note,
                                          color:
                                              _selectedItem?.source.themeColor,
                                        ),
                                  ),
                                )
                              : Icon(
                                  CupertinoIcons.music_note,
                                  color: _selectedItem?.source.themeColor,
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedDetail?.title ??
                                    _selectedItem?.title ??
                                    '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: context.yyTextPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _selectedItem?.source.themeColor
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Text(
                                      _selectedItem?.source.displayName ?? '',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: _selectedItem?.source.themeColor,
                                      ),
                                    ),
                                  ),
                                  if (_selectedCover != null) ...[
                                    const SizedBox(width: 4),
                                    _buildFeatureChip(
                                      CupertinoIcons.photo,
                                      '封面',
                                    ),
                                  ],
                                  if (_selectedLyrics?.hasLyrics ?? false) ...[
                                    const SizedBox(width: 4),
                                    _buildFeatureChip(
                                      CupertinoIcons.text_quote,
                                      '歌词',
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Options
                    Row(
                      children: [
                        Expanded(
                          child: _buildCompactOption(
                            '封面${_hasCover ? "(覆盖)" : ""}',
                            _downloadCover && _selectedCover != null,
                            _selectedCover != null
                                ? (v) => setState(() => _downloadCover = v)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildCompactOption(
                            '歌词${_hasLyrics ? "(覆盖)" : ""}',
                            _downloadLyrics &&
                                (_selectedLyrics?.hasLyrics ?? false),
                            (_selectedLyrics?.hasLyrics ?? false)
                                ? (v) => setState(() => _downloadLyrics = v)
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: CupertinoButton(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            color: context.isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : CupertinoColors.systemGrey6,
                            borderRadius: BorderRadius.circular(10),
                            onPressed: _isScraping
                                ? null
                                : () => setState(_clearSelection),
                            child: Text(
                              '取消',
                              style: TextStyle(
                                color: context.yyTextSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: CupertinoButton(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            color: YYColors.accentPrimary,
                            borderRadius: BorderRadius.circular(10),
                            onPressed: _isScraping ? null : _confirmAndScrape,
                            child: _isScraping
                                ? const CupertinoActivityIndicator(
                                    color: Colors.white,
                                    radius: 10,
                                  )
                                : const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        CupertinoIcons.checkmark,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        '确认刮削',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CupertinoActivityIndicator(
                      radius: 8,
                      color: context.yyTextTertiary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '正在获取详情...',
                      style: TextStyle(
                        color: context.yyTextSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: (context.isDark ? Colors.green[700] : Colors.green[100])!
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 10,
            color: context.isDark ? Colors.green[300] : Colors.green[700],
          ),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: context.isDark ? Colors.green[300] : Colors.green[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactOption(
    String label,
    bool value,
    void Function(bool)? onChanged,
  ) {
    final isEnabled = onChanged != null;
    return GestureDetector(
      onTap: isEnabled ? () => onChanged(!value) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: value
              ? YYColors.accentPrimary.withValues(alpha: 0.1)
              : (context.isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : CupertinoColors.systemGrey6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: value ? YYColors.accentPrimary : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              value
                  ? CupertinoIcons.checkmark_square_fill
                  : CupertinoIcons.square,
              size: 16,
              color: isEnabled
                  ? (value ? YYColors.accentPrimary : context.yyTextTertiary)
                  : Colors.grey[400],
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: isEnabled ? context.yyTextPrimary : Colors.grey[400],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int ms) {
    final seconds = ms ~/ 1000;
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
