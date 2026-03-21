import 'dart:io';
import 'package:flutter/material.dart';
import '../../app/theme/theme.dart';

/// 智能封面组件
///
/// - 有 coverUrl 时显示真实封面图片
/// - 无 coverUrl 时使用 seed 生成唯一的渐变色彩占位
class SmartCover extends StatelessWidget {
  final String seed;
  final String? coverUrl;
  final double size;
  final double borderRadius;

  const SmartCover({
    super.key,
    required this.seed,
    this.coverUrl,
    this.size = 40,
    this.borderRadius = 6,
  });

  @override
  Widget build(BuildContext context) {
    // 优先使用真实封面
    if (coverUrl != null && coverUrl!.isNotEmpty) {
      final file = File(coverUrl!);
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.file(
          file,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _GradientFallback(
            seed: seed, size: size, borderRadius: borderRadius),
        ),
      );
    }

    return _GradientFallback(seed: seed, size: size, borderRadius: borderRadius);
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
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: YYSeedPalette.gradient(seed),
      ),
      child: Center(
        child: Container(
          width: size * 0.38,
          height: size * 0.38,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(size * 0.14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
          child: Icon(
            Icons.graphic_eq_rounded,
            color: Colors.white.withValues(alpha: 0.78),
            size: size * 0.20,
          ),
        ),
      ),
    );
  }
}

/// 向后兼容别名 — 在遗留代码中仍可使用 GradientCover
class GradientCover extends StatelessWidget {
  final String seed;
  final String? coverUrl;
  final double size;
  final double borderRadius;

  const GradientCover({
    super.key,
    required this.seed,
    this.coverUrl,
    this.size = 40,
    this.borderRadius = 6,
  });

  @override
  Widget build(BuildContext context) {
    return SmartCover(
      seed: seed,
      coverUrl: coverUrl,
      size: size,
      borderRadius: borderRadius,
    );
  }
}
