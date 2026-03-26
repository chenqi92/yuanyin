import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';
import '../../features/player/domain/entities/music_item.dart';
import 'gradient_cover.dart';
import 'glass_widgets.dart';

/// 全局流体背景 - 优化后的 Liquid Glass 2.0 风格
class YYScenicBackground extends StatelessWidget {
  final Widget child;
  final Color? accent;
  final Alignment accentAlignment;

  const YYScenicBackground({
    super.key,
    required this.child,
    this.accent,
    this.accentAlignment = Alignment.topRight,
  });

  @override
  Widget build(BuildContext context) {
    final base = context.yyBgBase;
    final glow = accent ?? YYColors.accentPrimary;
    final isDark = context.isDark;

    return Stack(
      children: [
        // Base Pure Black Layer
        Positioned.fill(child: ColoredBox(color: base)),
        
        // Dynamic Glow Layers
        Positioned(
          top: -120,
          right: accentAlignment.x >= 0 ? -80 : null,
          left: accentAlignment.x < 0 ? -80 : null,
          child: _GlowOrb(
            size: 320,
            colors: [
              glow.withValues(alpha: isDark ? 0.12 : 0.08),
              YYColors.accentSecondary.withValues(alpha: isDark ? 0.05 : 0.03),
              Colors.transparent,
            ],
          ),
        ),
        Positioned(
          bottom: -140,
          left: -100,
          child: _GlowOrb(
            size: 280,
            colors: [
              YYColors.accentTertiary.withValues(alpha: isDark ? 0.08 : 0.04),
              glow.withValues(alpha: isDark ? 0.04 : 0.02),
              Colors.transparent,
            ],
          ),
        ),
        
        // Subtle Surface Texture / Gradient
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.02),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.08),
                  ],
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final List<Color> colors;

  const _GlowOrb({required this.size, required this.colors});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: colors),
          ),
        ),
      ),
    );
  }
}

/// 统一的玻璃面板组件 - 继承 GlassContainer
class YYPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? color;
  final double? radius;
  final bool thick;

  const YYPanel({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.color,
    this.radius,
    this.thick = false,
  });

  @override
  Widget build(BuildContext context) {
    final panel = GlassContainer(
      thick: thick,
      padding: padding ?? const EdgeInsets.all(16),
      margin: margin,
      borderRadius: BorderRadius.circular(radius ?? YYRadius.card),
      tintColor: color,
      child: child,
    );

    if (onTap == null) return panel;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: panel,
    );
  }
}

class YYHeaderActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  const YYHeaderActionButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.primary = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    
    if (primary) {
      return GlassButton(
        onTap: onTap,
        size: 42,
        tintColor: isDark ? YYColors.accentPrimary.withValues(alpha: 0.2) : null,
        child: Icon(icon, color: Colors.white, size: 20),
      );
    }

    return GlassButton(
      onTap: onTap,
      size: 42,
      child: Icon(icon, color: context.yyTextPrimary, size: 20),
    );
  }
}

class YYPageHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const YYPageHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow.toUpperCase(),
                  style: TextStyle(
                    color: context.yyTextTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: context.yyTextTheme.headlineLarge?.copyWith(
                    fontSize: 32,
                    letterSpacing: -1.2,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle!,
                    style: context.yyTextTheme.bodyMedium?.copyWith(
                      color: context.yyTextSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 16), trailing!],
        ],
      ),
    );
  }
}

class YYSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const YYSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.yyTextTheme.titleLarge?.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: context.yyTextTheme.labelMedium?.copyWith(
                      color: context.yyTextTertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class YYPillButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool primary;
  final bool compact;

  const YYPillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.primary = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 20,
          vertical: compact ? 8 : 12,
        ),
        borderRadius: BorderRadius.circular(YYRadius.full),
        tintColor: primary 
          ? isDark ? YYColors.accentPrimary.withValues(alpha: 0.3) : YYColors.accentPrimary
          : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon, 
                color: primary ? Colors.white : context.yyTextPrimary, 
                size: compact ? 16 : 18
              ),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                color: primary ? Colors.white : context.yyTextPrimary,
                fontSize: compact ? 13 : 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class YYTrackRow extends StatelessWidget {
  final MusicItem song;
  final bool active;
  final Widget? leading;
  final Widget? trailing;
  final String? subtitle;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry? margin;

  const YYTrackRow({
    super.key,
    required this.song,
    required this.onTap,
    this.onLongPress,
    this.active = false,
    this.leading,
    this.trailing,
    this.subtitle,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return YYPanel(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      padding: const EdgeInsets.all(12),
      color: active ? YYColors.accentPrimary.withValues(alpha: 0.15) : null,
      onTap: onTap,
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Hero(
            tag: 'track-cover-${song.id}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(YYRadius.sm),
              child: SizedBox(
                width: 52,
                height: 52,
                child: GradientCover(
                  seed: '${song.title}_${song.artist}',
                  coverUrl: song.coverUrl,
                  size: 52,
                  borderRadius: YYRadius.sm,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active ? YYColors.accentPrimary : context.yyTextPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle ?? song.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.yyTextSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing ?? _DefaultTrailing(song: song),
        ],
      ),
    );
  }
}

class _DefaultTrailing extends StatelessWidget {
  final MusicItem song;
  const _DefaultTrailing({required this.song});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          song.durationText,
          style: TextStyle(
            color: context.yyTextTertiary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if ((song.format ?? '').isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            song.format!.toUpperCase(),
            style: TextStyle(
              color: YYColors.accentSecondary.withValues(alpha: 0.8),
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ],
    );
  }
}

extension on BuildContext {
  TextTheme get yyTextTheme => Theme.of(this).textTheme;
}

