import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../app/theme/theme.dart';

/// iOS 26 Liquid Glass 容器
///
/// 模拟 Apple Liquid Glass 设计语言：
/// - 多层模糊（底层内容模糊 + 表面高斯）
/// - 渐变边框高光（模拟光线折射）
/// - 内部微光效果（顶部高光条纹）
/// - 可选的动态色彩染色
class GlassContainer extends StatelessWidget {
  final Widget child;
  final bool thick;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final double? width;
  final double? height;
  final Color? tintColor; // 可选的动态染色
  final bool showHighlight; // 是否显示顶部高光

  const GlassContainer({
    super.key,
    required this.child,
    this.thick = false,
    this.padding,
    this.margin,
    this.borderRadius,
    this.width,
    this.height,
    this.tintColor,
    this.showHighlight = true,
  });

  @override
  Widget build(BuildContext context) {
    final blur = thick ? YYBlur.thick : YYBlur.thin;
    final radius = borderRadius ?? BorderRadius.circular(YYRadius.card);

    // 基础玻璃颜色
    final baseColor = thick
        ? YYColors.bgGlassThick
        : YYColors.bgGlassThin;

    // 如果有染色，混合染色
    final glassColor = tintColor != null
        ? Color.alphaBlend(tintColor!.withValues(alpha: 0.08), baseColor)
        : baseColor;

    return Container(
      width: width,
      height: height,
      margin: margin,
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              // 多层渐变模拟玻璃深度
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  glassColor,
                  Color.alphaBlend(
                    Colors.black.withValues(alpha: 0.05),
                    glassColor,
                  ),
                ],
              ),
              borderRadius: radius,
            ),
            child: Stack(
              children: [
                // 顶部高光条纹 — 模拟光线从上方照射到玻璃表面
                if (showHighlight)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.only(
                          topLeft: radius.topLeft,
                          topRight: radius.topRight,
                        ),
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.0),
                            Colors.white.withValues(alpha: 0.15),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ),

                // 渐变边框 — 模拟光线折射
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      border: Border.all(
                        color: Colors.transparent,
                        width: 0.5,
                      ),
                      // 用 gradient shader 模拟渐变边框
                    ),
                    foregroundDecoration: BoxDecoration(
                      borderRadius: radius,
                      border: GradientBorder(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.20),
                            Colors.white.withValues(alpha: 0.05),
                            Colors.white.withValues(alpha: 0.02),
                            Colors.white.withValues(alpha: 0.10),
                          ],
                          stops: const [0.0, 0.3, 0.7, 1.0],
                        ),
                        width: 0.5,
                      ),
                    ),
                  ),
                ),

                // 实际内容
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 渐变边框 — 模拟 Liquid Glass 光线折射效果
class GradientBorder extends BoxBorder {
  final Gradient gradient;
  final double width;

  const GradientBorder({
    required this.gradient,
    required this.width,
  });

  @override
  BorderSide get bottom => BorderSide.none;

  @override
  BorderSide get top => BorderSide.none;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(width);

  @override
  bool get isUniform => true;

  @override
  void paint(Canvas canvas, Rect rect,
      {TextDirection? textDirection,
      BoxShape shape = BoxShape.rectangle,
      BorderRadius? borderRadius}) {
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;

    if (borderRadius != null && shape == BoxShape.rectangle) {
      canvas.drawRRect(
        borderRadius.toRRect(rect).deflate(width / 2),
        paint,
      );
    } else if (shape == BoxShape.circle) {
      canvas.drawCircle(rect.center, (rect.shortestSide - width) / 2, paint);
    } else {
      canvas.drawRect(rect.deflate(width / 2), paint);
    }
  }

  @override
  ShapeBorder scale(double t) => GradientBorder(gradient: gradient, width: width * t);
}

/// 玻璃卡片 — 预设了圆角和 padding 的 GlassContainer
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? tintColor;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.tintColor,
  });

  @override
  Widget build(BuildContext context) {
    final card = GlassContainer(
      padding: padding ?? const EdgeInsets.all(16),
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      tintColor: tintColor,
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }
}

/// 大号磨砂玻璃按钮（用于播放控制等场景）
class GlassButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double size;
  final Color? tintColor;

  const GlassButton({
    super.key,
    required this.child,
    this.onTap,
    this.size = 48,
    this.tintColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        width: size,
        height: size,
        borderRadius: BorderRadius.circular(size / 2),
        showHighlight: true,
        tintColor: tintColor,
        child: Center(child: child),
      ),
    );
  }
}

/// 浮动玻璃面板 — 用于底部弹窗等覆盖式容器
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(YYRadius.bottomSheet),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: YYBlur.thick, sigmaY: YYBlur.thick),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                YYColors.bgGlassThick,
                Color.alphaBlend(
                  Colors.black.withValues(alpha: 0.1),
                  YYColors.bgGlassThick,
                ),
              ],
            ),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(YYRadius.bottomSheet),
            ),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.15),
                width: 0.5,
              ),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
