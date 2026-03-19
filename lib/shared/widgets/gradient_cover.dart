import 'dart:math';
import 'package:flutter/material.dart';

/// 动态生成的抽象渐变封面 (UI 规范 §5 歌曲无封面处理)
///
/// 根据歌曲信息的 hash 值生成唯一的渐变色彩组合
class GradientCover extends StatelessWidget {
  final String seed;
  final double size;
  final double borderRadius;

  const GradientCover({
    super.key,
    required this.seed,
    this.size = 40,
    this.borderRadius = 6,
  });

  @override
  Widget build(BuildContext context) {
    final hash = seed.hashCode;
    final random = Random(hash);

    // 基于 hash 生成 HSL 色相
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
