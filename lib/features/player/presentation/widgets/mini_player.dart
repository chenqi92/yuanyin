import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/theme.dart';
import '../../../../shared/widgets/gradient_cover.dart';
import '../providers/player_provider.dart';

/// 迷你播放器
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerProvider);

    // 没有歌曲时不显示
    if (!state.hasSong) return const SizedBox.shrink();

    final song = state.currentSong!;

    return GestureDetector(
      onTap: () => context.push('/player'),
      child: Container(
        height: YYSizes.miniPlayerHeight,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // 封面缩略图
            Hero(
              tag: 'cover',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 40, height: 40,
                  child: GradientCover(seed: song.title, size: 40),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 歌曲信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(song.title,
                      style: const TextStyle(
                          color: YYColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(song.artist,
                      style: const TextStyle(
                          color: YYColors.textSecondary, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            // 播放/暂停
            GestureDetector(
              onTap: () => ref.read(playerProvider.notifier).togglePlay(),
              child: Icon(
                state.isPlaying
                    ? CupertinoIcons.pause_fill
                    : CupertinoIcons.play_fill,
                color: YYColors.textPrimary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            // 下一首
            GestureDetector(
              onTap: () => ref.read(playerProvider.notifier).next(),
              child: const Icon(CupertinoIcons.forward_fill,
                  color: YYColors.textSecondary, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
