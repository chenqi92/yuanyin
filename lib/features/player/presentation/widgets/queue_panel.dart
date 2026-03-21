import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/theme.dart';
import '../../../../shared/widgets/modern_music_ui.dart';
import '../../domain/entities/music_item.dart';
import '../providers/player_provider.dart';

void showQueuePanel(BuildContext context) {
  showModalBottomSheet(
    context: context,
    useRootNavigator: true,
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

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.42,
      maxChildSize: 0.94,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(YYRadius.bottomSheet),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Container(
              decoration: BoxDecoration(
                color: YYColors.bgGlassThickSolid.withValues(alpha: 0.96),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(YYRadius.bottomSheet),
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color: YYColors.textTertiary.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(YYRadius.full),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '播放队列',
                                style: Theme.of(context).textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${state.queue.length} 首歌曲 · 拖动调整顺序',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        YYPillButton(
                          label: '关闭',
                          compact: true,
                          onTap: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: state.queue.isEmpty
                        ? Center(
                            child: Text(
                              '队列为空',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          )
                        : ReorderableListView.builder(
                            scrollController: scrollController,
                            padding: const EdgeInsets.only(
                              left: 0,
                              right: 0,
                              top: 0,
                              bottom: 28,
                            ),
                            itemCount: state.queue.length,
                            onReorder: (oldIndex, newIndex) {
                              ref.read(playerProvider.notifier)
                                  .reorderQueue(oldIndex, newIndex);
                            },
                            proxyDecorator: (child, index, animation) {
                              return Material(
                                color: Colors.transparent,
                                child: child,
                              );
                            },
                            itemBuilder: (context, index) {
                              final song = state.queue[index];
                              final current = index == state.queueIndex;

                              return _QueueItem(
                                key: ValueKey('${song.id}_$index'),
                                index: index,
                                song: song,
                                current: current,
                                isPlaying: current && state.isPlaying,
                                onTap: () {
                                  ref.read(playerProvider.notifier)
                                      .playSong(song, queue: state.queue);
                                  Navigator.pop(context);
                                },
                                onDismissed: () => ref
                                    .read(playerProvider.notifier)
                                    .removeFromQueue(index),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _QueueItem extends StatelessWidget {
  final int index;
  final MusicItem song;
  final bool current;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  const _QueueItem({
    super.key,
    required this.index,
    required this.song,
    required this.current,
    required this.isPlaying,
    required this.onTap,
    required this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('queue-dismiss-${song.id}-$index'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(),
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: YYColors.statusError.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(YYRadius.lg),
        ),
        alignment: Alignment.centerRight,
        child: const Icon(
          CupertinoIcons.delete_solid,
          color: YYColors.statusError,
        ),
      ),
      child: YYTrackRow(
        song: song,
        active: current,
        onTap: onTap,
        leading: SizedBox(
          width: 26,
          child: current
              ? Icon(
                  isPlaying
                      ? CupertinoIcons.waveform
                      : CupertinoIcons.pause_circle_fill,
                  color: YYColors.accentPrimary,
                  size: 18,
                )
              : Text(
                  '${index + 1}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.yyTextTertiary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              song.durationText,
              style: TextStyle(
                color: context.yyTextTertiary,
                fontSize: 12,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              CupertinoIcons.line_horizontal_3,
              color: context.yyTextTertiary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
