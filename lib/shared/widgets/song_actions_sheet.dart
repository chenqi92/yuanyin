import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme/theme.dart';
import '../../features/player/domain/entities/music_item.dart';
import '../../features/player/presentation/providers/player_provider.dart';
import '../../features/favorites/data/services/favorites_service.dart';
import '../../features/playlist/data/services/playlist_service.dart';
import '../../features/library/data/services/metadata_scraper.dart';
import '../../features/library/data/services/music_database_service.dart';
import '../../features/library/presentation/providers/library_provider.dart';

/// 歌曲操作底部弹窗 — 自适应亮暗主题
void showSongActions(
  BuildContext context,
  WidgetRef ref,
  MusicItem song, {
  String? playlistId,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final sheetBg = isDark ? YYColors.bgElevated : YYLightColors.bgElevated;

  showModalBottomSheet(
    context: context,
    backgroundColor: sheetBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _SongActionsContent(song: song, playlistId: playlistId),
  );
}

class _SongActionsContent extends ConsumerStatefulWidget {
  final MusicItem song;
  final String? playlistId;
  const _SongActionsContent({required this.song, this.playlistId});

  @override
  ConsumerState<_SongActionsContent> createState() => _SongActionsContentState();
}

class _SongActionsContentState extends ConsumerState<_SongActionsContent> {
  bool _isFavorite = false;

  @override
  void initState() { super.initState(); _checkFavorite(); }

  Future<void> _checkFavorite() async {
    final fav = await ref.read(favoritesServiceProvider).isFavorite(widget.song.id);
    if (mounted) setState(() => _isFavorite = fav);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pri = isDark ? YYColors.textPrimary : YYLightColors.textPrimary;
    final sub = isDark ? YYColors.textSecondary : YYLightColors.textSecondary;
    final sep = isDark ? YYColors.separator : YYLightColors.separator;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(colors: [
                      HSLColor.fromAHSL(1.0, (widget.song.title.hashCode % 360).toDouble(), 0.6, 0.4).toColor(),
                      HSLColor.fromAHSL(1.0, ((widget.song.title.hashCode + 40) % 360).toDouble(), 0.5, 0.3).toColor(),
                    ]),
                  ),
                  child: const Icon(CupertinoIcons.music_note, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.song.title, style: TextStyle(
                          color: pri, fontWeight: FontWeight.w600, fontSize: 16),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('${widget.song.artist} · ${widget.song.album}',
                          style: TextStyle(color: sub, fontSize: 13),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: sep),
          _ActionTile(icon: CupertinoIcons.arrow_right_circle, title: '下一首播放', onTap: () {
            ref.read(playerProvider.notifier).addNextInQueue(widget.song);
            Navigator.pop(context);
            _showSnack(context, '已添加到下一首');
          }),
          _ActionTile(
            icon: _isFavorite ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
            title: _isFavorite ? '取消收藏' : '收藏',
            iconColor: _isFavorite ? YYColors.heartRed : null,
            onTap: () async {
              await ref.read(favoritesServiceProvider).toggleFavorite(widget.song.id);
              Navigator.pop(context);
              _showSnack(context, _isFavorite ? '已取消收藏' : '已收藏');
            },
          ),
          _ActionTile(icon: CupertinoIcons.music_note_list, title: '添加到歌单', onTap: () {
            Navigator.pop(context);
            _showPlaylistPicker(context, ref, widget.song);
          }),
          if (widget.playlistId != null)
            _ActionTile(
              icon: CupertinoIcons.minus_circle, title: '从歌单移除',
              iconColor: Colors.redAccent,
              onTap: () {
                ref.read(playlistsProvider.notifier)
                    .removeSongFromPlaylist(widget.playlistId!, widget.song.id);
                Navigator.pop(context);
              },
            ),
          _ActionTile(icon: CupertinoIcons.info_circle, title: '歌曲详情', onTap: () {
            Navigator.pop(context);
            _showSongDetails(context, widget.song);
          }),
          _ActionTile(icon: CupertinoIcons.sparkles, title: '元数据刮削', onTap: () {
            Navigator.pop(context);
            _scrapeMetadata(context, ref, widget.song);
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? iconColor;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.title, this.iconColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pri = isDark ? YYColors.textPrimary : YYLightColors.textPrimary;
    return ListTile(
      leading: Icon(icon, color: iconColor ?? pri, size: 22),
      title: Text(title, style: TextStyle(color: pri, fontSize: 16)),
      onTap: onTap,
    );
  }
}

void _showSnack(BuildContext context, String message) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
    content: Text(message),
    behavior: SnackBarBehavior.floating,
    duration: const Duration(seconds: 2),
    backgroundColor: isDark ? YYColors.bgElevated : YYLightColors.bgElevated,
  ));
}

void _showPlaylistPicker(BuildContext context, WidgetRef ref, MusicItem song) {
  final playlists = ref.read(playlistsProvider).playlists;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final sheetBg = isDark ? YYColors.bgElevated : YYLightColors.bgElevated;
  final pri = isDark ? YYColors.textPrimary : YYLightColors.textPrimary;
  final tri = isDark ? YYColors.textTertiary : YYLightColors.textTertiary;
  final sep = isDark ? YYColors.separator : YYLightColors.separator;

  showModalBottomSheet(
    context: context,
    backgroundColor: sheetBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('添加到歌单', style: TextStyle(
                color: pri, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Divider(height: 1, color: sep),
          if (playlists.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('还没有歌单', style: TextStyle(color: tri, fontSize: 14)),
            ),
          ...playlists.map((pl) => ListTile(
            leading: const Icon(CupertinoIcons.music_note_list, color: YYColors.accentPrimary),
            title: Text(pl.name, style: TextStyle(color: pri)),
            subtitle: Text('${pl.songIds.length} 首歌曲', style: TextStyle(color: tri, fontSize: 12)),
            onTap: () {
              ref.read(playlistsProvider.notifier).addSongToPlaylist(pl.id, song.id);
              Navigator.pop(ctx);
              _showSnack(context, '已添加到「${pl.name}」');
            },
          )),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

void _showSongDetails(BuildContext context, MusicItem song) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final sheetBg = isDark ? YYColors.bgElevated : YYLightColors.bgElevated;
  final pri = isDark ? YYColors.textPrimary : YYLightColors.textPrimary;
  final tri = isDark ? YYColors.textTertiary : YYLightColors.textTertiary;

  showModalBottomSheet(
    context: context,
    backgroundColor: sheetBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(song.title, style: TextStyle(color: pri, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _DetailRow('艺术家', song.artist),
            _DetailRow('专辑', song.album),
            if (song.format != null) _DetailRow('格式', song.format!),
            if (song.bitrateText.isNotEmpty) _DetailRow('比特率', song.bitrateText),
            if (song.sampleRate != null) _DetailRow('采样率', '${song.sampleRate} Hz'),
            if (song.fileSizeText.isNotEmpty) _DetailRow('文件大小', song.fileSizeText),
            _DetailRow('时长', song.durationText),
            if (song.year != null) _DetailRow('年份', '${song.year}'),
            if (song.trackNumber != null) _DetailRow('曲目编号', '${song.trackNumber}'),
            if (song.genre != null) _DetailRow('流派', song.genre!),
            if (song.filePath != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(song.filePath!, style: TextStyle(color: tri, fontSize: 11),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pri = isDark ? YYColors.textPrimary : YYLightColors.textPrimary;
    final tri = isDark ? YYColors.textTertiary : YYLightColors.textTertiary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: TextStyle(color: tri, fontSize: 14))),
          Expanded(child: Text(value, style: TextStyle(color: pri, fontSize: 14))),
        ],
      ),
    );
  }
}

/// 元数据刮削
void _scrapeMetadata(BuildContext context, WidgetRef ref, MusicItem song) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final sheetBg = isDark ? YYColors.bgElevated : YYLightColors.bgElevated;
  final pri = isDark ? YYColors.textPrimary : YYLightColors.textPrimary;
  final sub = isDark ? YYColors.textSecondary : YYLightColors.textSecondary;

  showModalBottomSheet(
    context: context,
    backgroundColor: sheetBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _ScrapeProgress(song: song),
  );
}

class _ScrapeProgress extends ConsumerStatefulWidget {
  final MusicItem song;
  const _ScrapeProgress({required this.song});

  @override
  ConsumerState<_ScrapeProgress> createState() => _ScrapeProgressState();
}

class _ScrapeProgressState extends ConsumerState<_ScrapeProgress> {
  String _status = '正在搜索 MusicBrainz…';
  bool _done = false;
  MusicItem? _result;

  @override
  void initState() {
    super.initState();
    _doScrape();
  }

  Future<void> _doScrape() async {
    try {
      final scraper = ref.read(metadataScraperProvider);
      final enriched = await scraper.scrape(widget.song);
      if (enriched != null && mounted) {
        // 持久化
        await ref.read(musicDatabaseProvider).updateSong(enriched);
        setState(() {
          _status = '刮削成功！已更新元数据';
          _done = true;
          _result = enriched;
        });
      } else if (mounted) {
        setState(() {
          _status = '未找到匹配的元数据';
          _done = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = '刮削失败: $e';
          _done = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pri = isDark ? YYColors.textPrimary : YYLightColors.textPrimary;
    final sub = isDark ? YYColors.textSecondary : YYLightColors.textSecondary;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_done)
              const CircularProgressIndicator(color: YYColors.accentPrimary)
            else
              Icon(
                _result != null ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.xmark_circle,
                size: 48,
                color: _result != null ? YYColors.accentPrimary : YYColors.textTertiary,
              ),
            const SizedBox(height: 16),
            Text(_status, style: TextStyle(color: pri, fontSize: 16)),
            if (_result != null) ...[
              const SizedBox(height: 12),
              if (_result!.year != null)
                Text('年份: ${_result!.year}', style: TextStyle(color: sub, fontSize: 14)),
              if (_result!.genre != null)
                Text('流派: ${_result!.genre}', style: TextStyle(color: sub, fontSize: 14)),
              if (_result!.album != widget.song.album)
                Text('专辑: ${_result!.album}', style: TextStyle(color: sub, fontSize: 14)),
            ],
            const SizedBox(height: 20),
            if (_done)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('完成', style: TextStyle(color: YYColors.accentPrimary, fontSize: 16)),
              ),
          ],
        ),
      ),
    );
  }
}

