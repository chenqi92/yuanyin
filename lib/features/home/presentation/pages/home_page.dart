import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/l10n/strings.dart';
import '../../../../shared/widgets/gradient_cover.dart';
import '../../../../shared/widgets/song_actions_sheet.dart';
import '../../../player/domain/entities/music_item.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../library/presentation/providers/library_provider.dart';
import '../../../favorites/data/services/favorites_service.dart';

/// 首页
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 6) return '夜深了';
    if (h < 12) return '早上好';
    if (h < 18) return '下午好';
    return '晚上好';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final library = ref.watch(libraryProvider);
    final c = _AC(context);

    return Scaffold(
      backgroundColor: c.bg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(YYSpacing.screenH, 12, YYSpacing.screenH, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_greeting(), style: TextStyle(
                              color: c.sub, fontSize: 14, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 2),
                          Text(S.of(context).appName, style: TextStyle(
                              color: c.pri, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/sources'),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: c.card,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(CupertinoIcons.folder, color: c.sub, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 160),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 20),

                if (playerState.hasSong)
                  _HeroPlayingCard(playerState: playerState)
                      .animate().fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0),

                if (library.allSongs.isEmpty && !playerState.hasSong)
                  _EmptyGuide().animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95)),

                if (library.allSongs.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _QuickActions(),
                ],

                if (library.recentPlays.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  _SectionHeader(title: '最近播放'),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 160,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: YYSpacing.screenH),
                      itemCount: library.recentPlays.take(10).length,
                      itemBuilder: (context, index) {
                        final song = library.recentPlays[index];
                        return _RecentCard(song: song, allSongs: library.recentPlays)
                            .animate().fadeIn(delay: (60 * index).ms);
                      },
                    ),
                  ),
                ],

                if (library.allSongs.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  _SectionHeader(title: '全部歌曲', count: library.allSongs.length),
                  const SizedBox(height: 8),
                  ...library.allSongs.take(30).map((song) =>
                      _SongTile(song: song, allSongs: library.allSongs)),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ──── Adaptive Color helper ────
class _AC {
  final BuildContext ctx;
  _AC(this.ctx);
  bool get _d => Theme.of(ctx).brightness == Brightness.dark;
  Color get bg => _d ? YYColors.bgBase : YYLightColors.bgBase;
  Color get card => _d ? YYColors.bgElevated : YYLightColors.bgElevated;
  Color get pri => _d ? YYColors.textPrimary : YYLightColors.textPrimary;
  Color get sub => _d ? YYColors.textSecondary : YYLightColors.textSecondary;
  Color get tri => _d ? YYColors.textTertiary : YYLightColors.textTertiary;
  Color get sep => _d ? YYColors.separator : YYLightColors.separator;
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int? count;
  const _SectionHeader({required this.title, this.count});

  @override
  Widget build(BuildContext context) {
    final c = _AC(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: YYSpacing.screenH),
      child: Row(
        children: [
          Text(title, style: TextStyle(
              color: c.pri, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.3)),
          if (count != null) ...[
            const SizedBox(width: 8),
            Text('$count', style: TextStyle(color: c.tri, fontSize: 14)),
          ],
        ],
      ),
    );
  }
}

class _EmptyGuide extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = _AC(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: YYSpacing.screenH),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(YYRadius.lg),
        border: Border.all(color: c.sep, width: 1),
      ),
      child: Column(
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              gradient: YYColors.accentGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(CupertinoIcons.music_note_2, size: 32, color: Colors.white),
          ).animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), duration: 2000.ms),
          const SizedBox(height: 20),
          Text('开始使用 ${S.of(context).appName}', style: TextStyle(
              color: c.pri, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('添加数据源来扫描你的音乐文件',
              style: TextStyle(color: c.sub, fontSize: 14)),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => context.push('/sources'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                gradient: YYColors.accentGradient,
                borderRadius: BorderRadius.circular(YYRadius.full),
                boxShadow: YYShadows.accentGlow(YYColors.accentPrimary),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.plus, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('添加数据源', style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: YYSpacing.screenH),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _QuickActionCard(
                icon: CupertinoIcons.heart_fill,
                title: '收藏',
                gradient: const [Color(0xFFEF4444), Color(0xFFF87171)],
                onTap: () => context.push('/favorites'),
              )),
              const SizedBox(width: 12),
              Expanded(child: _QuickActionCard(
                icon: CupertinoIcons.shuffle,
                title: '随机播放',
                gradient: const [Color(0xFF10B981), Color(0xFF34D399)],
                onTap: () {
                  final songs = ref.read(libraryProvider).allSongs;
                  if (songs.isNotEmpty) {
                    final shuffled = List<MusicItem>.from(songs)..shuffle();
                    ref.read(playerProvider.notifier).playSong(shuffled.first, queue: shuffled);
                  }
                },
              )),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _QuickActionCard(
                icon: CupertinoIcons.chart_bar_alt_fill,
                title: '统计',
                gradient: const [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
                onTap: () => context.push('/stats'),
              )),
              const SizedBox(width: 12),
              Expanded(child: _QuickActionCard(
                icon: CupertinoIcons.waveform_path_ecg,
                title: '均衡器',
                gradient: const [Color(0xFFEC4899), Color(0xFFF472B6)],
                onTap: () => context.push('/equalizer'),
              )),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _QuickActionCard({required this.icon, required this.title, required this.gradient, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = _AC(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(YYRadius.md),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Text(title, style: TextStyle(
                color: c.pri, fontWeight: FontWeight.w600, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

class _HeroPlayingCard extends ConsumerWidget {
  final PlayerState playerState;
  const _HeroPlayingCard({required this.playerState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = _AC(context);
    final song = playerState.currentSong!;
    final progress = playerState.duration.inMilliseconds > 0
        ? (playerState.position.inMilliseconds / playerState.duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onTap: () => context.push('/player'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: YYSpacing.screenH),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              YYColors.accentPrimary.withValues(alpha: 0.15),
              YYColors.accentSecondary.withValues(alpha: 0.08),
              c.card,
            ],
          ),
          borderRadius: BorderRadius.circular(YYRadius.lg),
          border: Border.all(color: YYColors.accentPrimary.withValues(alpha: 0.1), width: 1),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Hero(
                  tag: 'cover',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(width: 56, height: 56, child: GradientCover(seed: song.title, coverUrl: song.coverUrl, size: 56)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('正在播放', style: TextStyle(
                          color: YYColors.accentPrimary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      Text(song.title, style: TextStyle(
                          color: c.pri, fontSize: 16, fontWeight: FontWeight.w600),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(song.artist, style: TextStyle(color: c.sub, fontSize: 13),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => ref.read(playerProvider.notifier).togglePlay(),
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      gradient: YYColors.accentGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: YYShadows.accentGlow(YYColors.accentPrimary),
                    ),
                    child: Icon(
                      playerState.isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                      color: Colors.white, size: 20,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 3,
                backgroundColor: c.tri.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(YYColors.accentPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentCard extends ConsumerWidget {
  final MusicItem song;
  final List<MusicItem> allSongs;
  const _RecentCard({required this.song, required this.allSongs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = _AC(context);
    return GestureDetector(
      onTap: () => ref.read(playerProvider.notifier).playSong(song, queue: allSongs),
      onLongPress: () => showSongActions(context, ref, song),
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(YYRadius.sm),
              child: SizedBox(width: 120, height: 120, child: GradientCover(seed: song.title, coverUrl: song.coverUrl, size: 120)),
            ),
            const SizedBox(height: 8),
            Text(song.title, style: TextStyle(
                color: c.pri, fontSize: 13, fontWeight: FontWeight.w500),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(song.artist, style: TextStyle(color: c.tri, fontSize: 11),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _SongTile extends ConsumerWidget {
  final MusicItem song;
  final List<MusicItem> allSongs;
  const _SongTile({required this.song, required this.allSongs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = _AC(context);
    final isPlaying = ref.watch(playerProvider).currentSong?.id == song.id;

    return GestureDetector(
      onTap: () => ref.read(playerProvider.notifier).playSong(song, queue: allSongs),
      onLongPress: () => showSongActions(context, ref, song),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: YYSpacing.screenH, vertical: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(YYRadius.coverSmall),
              child: SizedBox(width: 44, height: 44, child: GradientCover(seed: song.title, coverUrl: song.coverUrl, size: 44)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(song.title,
                      style: TextStyle(
                        color: isPlaying ? YYColors.accentPrimary : c.pri,
                        fontWeight: FontWeight.w500, fontSize: 15),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('${song.artist} · ${song.album}',
                      style: TextStyle(color: c.sub, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (isPlaying)
              const Icon(CupertinoIcons.waveform, color: YYColors.accentPrimary, size: 16)
            else
              Text(song.durationText, style: TextStyle(color: c.tri, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
