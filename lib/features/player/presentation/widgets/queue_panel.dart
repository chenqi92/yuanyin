import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/theme.dart';
import '../../../../shared/widgets/gradient_cover.dart';
import '../../domain/entities/music_item.dart';
import '../providers/player_provider.dart';

/// 播放队列面板 — 自适应亮暗主题
void showQueuePanel(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _QueueSheet(),
  );
}

class _QueueSheet extends ConsumerWidget {
  const _QueueSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerProvider);
    final queue = state.queue;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? YYColors.bgElevated : YYLightColors.bgElevated;
    final pri = isDark ? YYColors.textPrimary : YYLightColors.textPrimary;
    final sub = isDark ? YYColors.textSecondary : YYLightColors.textSecondary;
    final tri = isDark ? YYColors.textTertiary : YYLightColors.textTertiary;
    final sep = isDark ? YYColors.separator : YYLightColors.separator;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(color: tri, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('播放队列', style: TextStyle(color: pri, fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('${queue.length} 首', style: TextStyle(color: tri, fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 0.5, margin: const EdgeInsets.symmetric(horizontal: 20), color: sep),
            Expanded(
              child: queue.isEmpty
                  ? Center(child: Text('队列为空', style: TextStyle(color: tri, fontSize: 15)))
                  : ReorderableListView.builder(
                      scrollController: scrollController,
                      padding: const EdgeInsets.only(bottom: 40),
                      itemCount: queue.length,
                      onReorder: (oldIndex, newIndex) =>
                          ref.read(playerProvider.notifier).reorderQueue(oldIndex, newIndex),
                      proxyDecorator: (child, index, animation) =>
                          Material(color: Colors.transparent, child: child),
                      itemBuilder: (context, index) {
                        final song = queue[index];
                        final isCurrent = index == state.queueIndex;
                        return _QueueItem(
                          key: ValueKey('${song.id}_$index'),
                          song: song, index: index, isCurrent: isCurrent,
                          isPlaying: isCurrent && state.isPlaying,
                          onTap: () {
                            ref.read(playerProvider.notifier).playSong(song, queue: queue);
                            Navigator.pop(context);
                          },
                          onDismissed: () => ref.read(playerProvider.notifier).removeFromQueue(index),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueItem extends StatelessWidget {
  final MusicItem song;
  final int index;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  const _QueueItem({
    super.key, required this.song, required this.index,
    required this.isCurrent, required this.isPlaying,
    required this.onTap, required this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pri = isDark ? YYColors.textPrimary : YYLightColors.textPrimary;
    final sub = isDark ? YYColors.textSecondary : YYLightColors.textSecondary;
    final tri = isDark ? YYColors.textTertiary : YYLightColors.textTertiary;

    return Dismissible(
      key: ValueKey('dismiss_${song.id}_$index'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.redAccent.withValues(alpha: 0.3),
        child: const Icon(CupertinoIcons.delete, color: Colors.redAccent, size: 20),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          color: isCurrent ? YYColors.accentPrimary.withValues(alpha: 0.08) : Colors.transparent,
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: isCurrent
                    ? Icon(isPlaying ? CupertinoIcons.waveform : CupertinoIcons.pause_fill,
                        color: YYColors.accentPrimary, size: 16)
                    : Text('${index + 1}', style: TextStyle(color: tri, fontSize: 14),
                        textAlign: TextAlign.center),
              ),
              const SizedBox(width: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(width: 40, height: 40, child: GradientCover(seed: song.title, coverUrl: song.coverUrl, size: 40)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(song.title, style: TextStyle(
                        color: isCurrent ? YYColors.accentPrimary : pri,
                        fontWeight: FontWeight.w500, fontSize: 15),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(song.artist, style: TextStyle(color: sub, fontSize: 12),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Text(song.durationText, style: TextStyle(color: tri, fontSize: 12)),
              const SizedBox(width: 8),
              Icon(CupertinoIcons.line_horizontal_3, color: tri, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
