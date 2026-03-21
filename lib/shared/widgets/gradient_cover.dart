import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';

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
          errorBuilder: (_, __, ___) => _GradientFallback(
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
    final hash = seed.hashCode;
    final random = Random(hash);
    final hue1 = random.nextDouble() * 360;
    final hue2 = (hue1 + 40 + random.nextDouble() * 80) % 360;
    final color1 = HSLColor.fromAHSL(1.0, hue1, 0.65, 0.45).toColor();
    final color2 = HSLColor.fromAHSL(1.0, hue2, 0.7, 0.35).toColor();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color1, color2],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          color: Colors.white.withValues(alpha: 0.4),
          size: size * 0.4,
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
