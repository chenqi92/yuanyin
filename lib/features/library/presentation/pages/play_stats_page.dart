import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/theme.dart';
import '../../../../shared/widgets/gradient_cover.dart';
import '../../../../shared/widgets/modern_music_ui.dart';
import '../../../library/data/services/play_stats_service.dart';
import '../../../library/presentation/providers/library_provider.dart';
import '../../../player/domain/entities/music_item.dart';

/// 播放统计页
class PlayStatsPage extends ConsumerWidget {
  const PlayStatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: YYScenicBackground(
        accent: const Color(0xFF8B5CF6),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // 顶部标题区域
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 10, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(CupertinoIcons.back, color: context.yyTextPrimary, size: 22),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: YYPageHeader(
                        eyebrow: '曲库维护',
                        title: '播放统计',
                      ),
                    ),
                  ],
                ),
              ),
              // 内容
              Expanded(
                child: FutureBuilder<_StatsData>(
                  future: _loadStats(ref),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator(color: YYColors.accentPrimary));
                    }
                    final data = snapshot.data!;

                    return ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      children: [
                        // 总览卡片
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: YYColors.accentGradient,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _StatItem(value: '${data.overall.totalPlays}', label: '总播放次数', color: Colors.white),
                              _StatItem(value: data.overall.totalDurationText, label: '总时长', color: Colors.white),
                              _StatItem(value: '${data.overall.uniqueSongs}', label: '歌曲数', color: Colors.white),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // 最常播放
                        if (data.topSongs.isNotEmpty) ...[
                          Text('最常播放', style: TextStyle(color: context.yyTextPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          ...data.topSongs.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final item = entry.value;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: context.yyBgElevated,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 24,
                                    child: Text(
                                      '${idx + 1}',
                                      style: TextStyle(
                                        color: idx < 3 ? YYColors.accentPrimary : context.yyTextTertiary,
                                        fontWeight: idx < 3 ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 40, height: 40,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: GradientCover(
                                        seed: '${item.song?.title ?? ''}_${item.song?.artist ?? ''}',
                                        size: 40,
                                        coverUrl: item.song?.coverUrl,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.song?.title ?? item.stats.songId,
                                            style: TextStyle(color: context.yyTextPrimary, fontSize: 15),
                                            maxLines: 1, overflow: TextOverflow.ellipsis),
                                        Text(item.song?.artist ?? '',
                                            style: TextStyle(color: context.yyTextSecondary, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('${item.stats.playCount} 次',
                                          style: const TextStyle(color: YYColors.accentPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                                      Text(_formatDuration(item.stats.totalDuration),
                                          style: TextStyle(color: context.yyTextTertiary, fontSize: 11)),
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
            ],
          ),
        ),
      ),
    );
  }

  Future<_StatsData> _loadStats(WidgetRef ref) async {
    final statsService = ref.read(playStatsProvider);
    final overall = await statsService.getOverallStats();
    final topPlayed = await statsService.getTopPlayed(limit: 20);

    // 关联歌曲信息
    final db = ref.read(musicDatabaseProvider);
    final allSongs = await db.getAllSongs();
    final songMap = <String, MusicItem>{};
    for (final s in allSongs) songMap[s.id] = s;

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

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _StatItem({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 12)),
      ],
    );
  }
}
