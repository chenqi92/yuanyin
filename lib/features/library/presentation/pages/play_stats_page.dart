import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/theme.dart';
import '../../../../shared/widgets/gradient_cover.dart';
import '../../../library/data/services/play_stats_service.dart';
import '../../../library/presentation/providers/library_provider.dart';
import '../../../player/domain/entities/music_item.dart';

/// Play stats page -- iOS native style
class PlayStatsPage extends ConsumerWidget {
  const PlayStatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          '播放统计',
          style: TextStyle(
            color: context.yyTextPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: FutureBuilder<_StatsData>(
          future: _loadStats(ref),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: CupertinoActivityIndicator(radius: 14),
              );
            }
            final data = snapshot.data!;

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                // Stats summary: 3 cards in a row
                Row(
                  children: [
                    _StatCard(
                      value: '${data.overall.totalPlays}',
                      label: '总播放',
                      color: YYColors.accentPrimary,
                    ),
                    const SizedBox(width: 10),
                    _StatCard(
                      value: data.overall.totalDurationText,
                      label: '总时长',
                      color: YYColors.accentSecondary,
                    ),
                    const SizedBox(width: 10),
                    _StatCard(
                      value: '${data.overall.uniqueSongs}',
                      label: '歌曲数',
                      color: const Color(0xFF8B5CF6),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // Top songs section
                if (data.topSongs.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '最常播放',
                      style: TextStyle(
                        color: context.yyTextPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  ...data.topSongs.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final item = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          // Rank number
                          SizedBox(
                            width: 28,
                            child: Text(
                              '${idx + 1}',
                              style: TextStyle(
                                color: idx < 3
                                    ? YYColors.accentPrimary
                                    : context.yyTextTertiary,
                                fontWeight: idx < 3
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Cover
                          SizedBox(
                            width: 44,
                            height: 44,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: GradientCover(
                                seed:
                                    '${item.song?.title ?? ''}_${item.song?.artist ?? ''}',
                                size: 44,
                                coverUrl: item.song?.coverUrl,
                                filePath: item.song?.filePath,
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
                                  item.song?.title ?? item.stats.songId,
                                  style: TextStyle(
                                    color: context.yyTextPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.song?.artist ?? '',
                                  style: TextStyle(
                                    color: context.yyTextSecondary,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          // Play count
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${item.stats.playCount} 次',
                                style: const TextStyle(
                                  color: YYColors.accentPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                _formatDuration(item.stats.totalDuration),
                                style: TextStyle(
                                  color: context.yyTextTertiary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<_StatsData> _loadStats(WidgetRef ref) async {
    final statsService = ref.read(playStatsProvider);
    final overall = await statsService.getOverallStats();
    final topPlayed = await statsService.getTopPlayed(limit: 20);

    final db = ref.read(musicDatabaseProvider);
    final allSongs = await db.getAllSongs();
    final songMap = <String, MusicItem>{};
    for (final s in allSongs) {
      songMap[s.id] = s;
    }

    final topSongs = topPlayed.map((stat) {
      return _SongWithStats(song: songMap[stat.songId], stats: stat);
    }).toList();

    return _StatsData(overall: overall, topSongs: topSongs);
  }

  static String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '$h 小时 $m 分';
    return '$m 分钟';
  }
}

class _StatsData {
  final OverallStats overall;
  final List<_SongWithStats> topSongs;
  _StatsData({required this.overall, required this.topSongs});
}

class _SongWithStats {
  final MusicItem? song;
  final SongPlayStats stats;
  _SongWithStats({this.song, required this.stats});
}

/// Stat card widget
class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _StatCard({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: context.isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: context.yyTextSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
