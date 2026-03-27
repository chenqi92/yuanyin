import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/theme.dart';
import '../../../../shared/widgets/gradient_cover.dart';
import '../../../../shared/widgets/modern_music_ui.dart';
import '../../../../shared/widgets/native_overlay_sheet.dart';
import '../../domain/entities/music_item.dart';
import '../providers/player_provider.dart';

void showQueuePanel(BuildContext context) {
  showCupertinoModalPopup(
    context: context,
    useRootNavigator: true,
    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
    builder: (_) => const YYBottomOverlayInset(
      horizontal: 8,
      top: 8,
      bottom: 0,
      child: _QueueSheet(),
    ),
  );
}

class _QueueSheet extends ConsumerWidget {
  const _QueueSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.94,
      builder: (context, scrollController) {
        return YYLiquidGlass(
          thin: true,
          radius: 28,
          padding: EdgeInsets.zero,
          color: context.yyBgElevated.withValues(alpha: 0.80),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.yyTextTertiary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
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
                            style: TextStyle(
                              color: context.yyTextPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${state.queue.length} 首歌曲',
                            style: TextStyle(
                              color: context.yyTextSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(44, 44),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        '关闭',
                        style: TextStyle(
                          color: YYColors.accentPrimary,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Divider(
                height: 1,
                color: context.yySeparator,
                indent: 20,
                endIndent: 20,
              ),
              Expanded(
                child: state.queue.isEmpty
                    ? Center(
                        child: Text(
                          '队列为空',
                          style: TextStyle(
                            color: context.yyTextTertiary,
                            fontSize: 15,
                          ),
                        ),
                      )
                    : ReorderableListView.builder(
                        scrollController: scrollController,
                        padding: const EdgeInsets.only(top: 8, bottom: 28),
                        itemCount: state.queue.length,
                        onReorder: (oldIndex, newIndex) {
                          ref
                              .read(playerProvider.notifier)
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
                              ref
                                  .read(playerProvider.notifier)
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
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerRight,
        color: YYColors.statusError.withValues(alpha: 0.12),
        child: const Icon(
          CupertinoIcons.delete_solid,
          color: YYColors.statusError,
          size: 20,
        ),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            border: current
                ? Border(
                    left: BorderSide(color: YYColors.accentPrimary, width: 3),
                  )
                : null,
          ),
          child: Row(
            children: [
              // Cover art 40x40
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: GradientCover(
                    seed: '${song.title}_${song.artist}',
                    coverUrl: song.coverUrl,
                    filePath: song.filePath,
                    size: 40,
                    borderRadius: 6,
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
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: current
                            ? YYColors.accentPrimary
                            : context.yyTextPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.yyTextSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Duration
              Text(
                song.durationText,
                style: TextStyle(
                  color: context.yyTextTertiary,
                  fontSize: 13,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 12),
              // Drag handle
              Icon(
                CupertinoIcons.line_horizontal_3,
                color: context.yyTextTertiary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
