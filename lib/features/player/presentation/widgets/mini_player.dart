import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/theme.dart';
import '../../../../shared/widgets/gradient_cover.dart';
import '../providers/player_provider.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerProvider);
    final song = state.currentSong;

    if (song == null) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () => context.push('/player'),
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            Hero(
              tag: 'mini-player-cover',
              child: SizedBox(
                width: 38,
                height: 38,
                child: GradientCover(
                  seed: '${song.title}_${song.artist}',
                  coverUrl: song.coverUrl,
                  filePath: song.filePath,
                  size: 38,
                  borderRadius: 12,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.yyTextPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _MiniTransportButton(
              icon: state.isPlaying
                  ? CupertinoIcons.pause_fill
                  : CupertinoIcons.play_fill,
              onTap: () => ref.read(playerProvider.notifier).togglePlay(),
            ),
            const SizedBox(width: 2),
            _MiniTransportButton(
              icon: CupertinoIcons.forward_fill,
              onTap: () => ref.read(playerProvider.notifier).next(),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniTransportButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MiniTransportButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        padding: EdgeInsets.zero,
        splashRadius: 18,
        onPressed: onTap,
        icon: Icon(icon, color: context.yyTextPrimary, size: 18),
      ),
    );
  }
}
