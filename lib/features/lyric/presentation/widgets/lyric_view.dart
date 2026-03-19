import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/theme.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../data/services/lyric_parser.dart';

/// 实时滚动歌词组件
class LyricView extends ConsumerStatefulWidget {
  final List<LyricLine> lyrics;

  const LyricView({super.key, required this.lyrics});

  @override
  ConsumerState<LyricView> createState() => _LyricViewState();
}

class _LyricViewState extends ConsumerState<LyricView> {
  final ScrollController _scrollController = ScrollController();
  int _currentIndex = -1;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final position = ref.watch(playerProvider.select((s) => s.position));
    final newIndex = LrcParser.findCurrentIndex(widget.lyrics, position);

    if (newIndex != _currentIndex && newIndex >= 0) {
      _currentIndex = newIndex;
      // 滚动到当前行
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          final targetOffset = (newIndex * 48.0) - 120.0;
          _scrollController.animateTo(
            targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }

    if (widget.lyrics.isEmpty) {
      return const Center(
        child: Text('暂无歌词', style: TextStyle(color: YYColors.textTertiary, fontSize: 16)),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 120),
      itemCount: widget.lyrics.length,
      itemBuilder: (context, index) {
        final line = widget.lyrics[index];
        final isCurrent = index == _currentIndex;

        return GestureDetector(
          onTap: () {
            ref.read(playerProvider.notifier).seek(line.time);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
            child: Text(
              line.text,
              style: TextStyle(
                fontSize: isCurrent ? 20 : 16,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                color: isCurrent
                    ? YYColors.textPrimary
                    : YYColors.textTertiary.withValues(alpha: 0.6),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }
}
