import 'package:flutter/material.dart';
import '../../app/theme/theme.dart';
import '../utils/cover_art_resolver.dart';

/// 智能封面组件
///
/// - 有 coverUrl 时显示真实封面图片
/// - 无 coverUrl 时使用 seed 生成唯一的渐变色彩占位
class SmartCover extends StatefulWidget {
  final String seed;
  final String? coverUrl;
  final String? filePath;
  final double size;
  final double borderRadius;

  const SmartCover({
    super.key,
    required this.seed,
    this.coverUrl,
    this.filePath,
    this.size = 40,
    this.borderRadius = 6,
  });

  @override
  State<SmartCover> createState() => _SmartCoverState();
}

class _SmartCoverState extends State<SmartCover> {
  late List<String> _candidates;
  int _candidateIndex = 0;

  @override
  void initState() {
    super.initState();
    _rebuildCandidates();
  }

  @override
  void didUpdateWidget(covariant SmartCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coverUrl != widget.coverUrl ||
        oldWidget.filePath != widget.filePath ||
        oldWidget.seed != widget.seed) {
      _rebuildCandidates();
    }
  }

  void _rebuildCandidates() {
    _candidates = yyResolveCoverCandidates(
      coverUrl: widget.coverUrl,
      filePath: widget.filePath,
    );
    _candidateIndex = 0;
  }

  @override
  Widget build(BuildContext context) {
    final errorWidget = _GradientFallback(
      seed: widget.seed,
      size: widget.size,
      borderRadius: widget.borderRadius,
    );
    final provider = _candidates.isEmpty
        ? null
        : yyBuildCoverImageProviderFromCandidate(_candidates[_candidateIndex]);

    if (provider == null) {
      if (_candidateIndex < _candidates.length - 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _candidateIndex += 1);
        });
      }
      return errorWidget;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Image(
        key: ValueKey(_candidates[_candidateIndex]),
        image: provider,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) {
            return child;
          }
          return Stack(fit: StackFit.expand, children: [errorWidget, child]);
        },
        errorBuilder: (_, error, stackTrace) {
          if (_candidateIndex < _candidates.length - 1) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() => _candidateIndex += 1);
            });
          }
          return errorWidget;
        },
      ),
    );
  }
}

/// 渐变占位封面 (原 GradientCover)
class _GradientFallback extends StatelessWidget {
  final String seed;
  final double size;
  final double borderRadius;

  const _GradientFallback({
    required this.seed,
    required this.size,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final primary = yyMix(
      const Color(0xFF15171B),
      YYSeedPalette.primary(seed),
      0.16,
    );
    final secondary = yyMix(
      const Color(0xFF0C0D10),
      YYSeedPalette.secondary(seed),
      0.12,
    );
    final accent = yyMix(YYSeedPalette.backdrop(seed), Colors.white, 0.18);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primary, secondary],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -size * 0.2,
            right: -size * 0.14,
            child: IgnorePointer(
              child: Container(
                width: size * 0.76,
                height: size * 0.76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accent.withValues(alpha: 0.28),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: size * 0.16,
            right: size * 0.16,
            top: size * 0.18,
            child: Container(
              height: size * 0.045,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(size * 0.05),
              ),
            ),
          ),
          Positioned(
            right: -size * 0.08,
            bottom: -size * 0.06,
            child: Container(
              width: size * 0.6,
              height: size * 0.6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accent.withValues(alpha: 0.18),
                    accent.withValues(alpha: 0.02),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: size * 0.34,
              height: size * 0.34,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(size * 0.12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Icon(
                Icons.music_note_rounded,
                color: Colors.white.withValues(alpha: 0.86),
                size: size * 0.18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 向后兼容别名 — 在遗留代码中仍可使用 GradientCover
class GradientCover extends StatelessWidget {
  final String seed;
  final String? coverUrl;
  final String? filePath;
  final double size;
  final double borderRadius;

  const GradientCover({
    super.key,
    required this.seed,
    this.coverUrl,
    this.filePath,
    this.size = 40,
    this.borderRadius = 6,
  });

  @override
  Widget build(BuildContext context) {
    return SmartCover(
      seed: seed,
      coverUrl: coverUrl,
      filePath: filePath,
      size: size,
      borderRadius: borderRadius,
    );
  }
}
