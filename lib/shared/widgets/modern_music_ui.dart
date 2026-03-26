import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app/theme/theme.dart';
import '../../features/player/domain/entities/music_item.dart';
import 'gradient_cover.dart';
import 'glass_widgets.dart';

/// 动态流体背景 3.0 - 模拟液态流动
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
        // 1. 纯黑底层 (OLED 深度)
        Positioned.fill(child: ColoredBox(color: base)),
        
        // 2. 动态流体层 (多层漂移气泡)
        _MovingOrb(
          initialAlignment: const Alignment(0.8, -0.8),
          size: 380,
          color: glow.withValues(alpha: isDark ? 0.15 : 0.10),
          duration: 15.seconds,
        ),
        _MovingOrb(
          initialAlignment: const Alignment(-0.7, 0.6),
          size: 320,
          color: YYColors.accentSecondary.withValues(alpha: isDark ? 0.10 : 0.06),
          duration: 20.seconds,
          delay: 2.seconds,
        ),
        _MovingOrb(
          initialAlignment: const Alignment(0.2, 0.2),
          size: 260,
          color: YYColors.accentTertiary.withValues(alpha: isDark ? 0.08 : 0.04),
          duration: 12.seconds,
          delay: 5.seconds,
        ),
        
        // 3. 颗粒感纹理层 (Subtle Noise/Grain)
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.03,
              child: Image.asset(
                'assets/icons/logo_512.png', // 借用 logo 缩放作为微弱纹理，或后续替换为噪点图
                fit: BoxFit.cover,
                colorBlendMode: BlendMode.overlay,
              ),
            ),
          ),
        ),

        // 4. 内容层
        child,
      ],
    );
  }
}

class _MovingOrb extends StatelessWidget {
  final Alignment initialAlignment;
  final double size;
  final Color color;
  final Duration duration;
  final Duration delay;

  const _MovingOrb({
    required this.initialAlignment,
    required this.size,
    required this.color,
    required this.duration,
    this.delay = Duration.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          alignment: initialAlignment,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [color, color.withValues(alpha: 0.4), Colors.transparent],
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
          ),
        )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .move(
          begin: const Offset(-20, -20),
          end: const Offset(20, 20),
          duration: duration,
          curve: Curves.easeInOutSine,
        )
        .scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1.1, 1.1),
          duration: duration,
          curve: Curves.easeInOutSine,
        )
        .blur(
          begin: const Offset(60, 60),
          end: const Offset(100, 100),
          duration: duration,
        ),
      ),
    );
  }
}

/// 进阶版玻璃面板 - 强化边缘与光影
class YYPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? color;
  final double? radius;
  final double? width;
  final bool thick;

  const YYPanel({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.color,
    this.radius,
    this.width,
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
      child: SizedBox(width: width, child: child),
    );

    if (onTap == null) return panel;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap!();
      },
      behavior: HitTestBehavior.opaque,
      child: panel.animate(onPlay: (c) => c.stop()).scale(
        begin: const Offset(1, 1),
        end: const Offset(0.98, 0.98),
        duration: 100.ms,
        curve: Curves.easeOut,
      ),
    );
  }
}

// ... (Rest of the widgets remain same, but applying haptic and minor tweaks)

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
    
    return GlassButton(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      size: 42,
      tintColor: primary 
        ? (isDark ? YYColors.accentPrimary.withValues(alpha: 0.25) : YYColors.accentPrimary)
        : null,
      child: Icon(
        icon, 
        color: primary ? Colors.white : context.yyTextPrimary, 
        size: 20
      ),
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
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
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
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.2),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: context.yyTextTheme.headlineLarge?.copyWith(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.5,
                  ),
                ).animate().fadeIn(duration: 500.ms, delay: 100.ms).slideX(begin: -0.1),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle!,
                    style: context.yyTextTheme.bodyMedium?.copyWith(
                      color: context.yyTextSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
                ],
              ],
            ),
          ),
          if (trailing != null) 
            trailing!.animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.8, 0.8)),
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
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
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
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: context.yyTextTheme.labelMedium?.copyWith(
                      color: context.yyTextTertiary,
                      fontWeight: FontWeight.w700,
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
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: GlassContainer(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 16 : 24,
          vertical: compact ? 10 : 14,
        ),
        borderRadius: BorderRadius.circular(YYRadius.full),
        tintColor: primary 
          ? isDark ? YYColors.accentPrimary.withValues(alpha: 0.35) : YYColors.accentPrimary
          : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon, 
                color: primary ? Colors.white : context.yyTextPrimary, 
                size: compact ? 16 : 20
              ),
              const SizedBox(width: 10),
            ],
            Text(
              label,
              style: TextStyle(
                color: primary ? Colors.white : context.yyTextPrimary,
                fontSize: compact ? 13 : 15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
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
      color: active ? YYColors.accentPrimary.withValues(alpha: 0.2) : null,
      onTap: onTap,
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Hero(
            tag: 'track-cover-${song.id}',
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(YYRadius.sm),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
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
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle ?? song.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.yyTextSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if ((song.format ?? '').isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: YYColors.accentSecondary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              song.format!.toUpperCase(),
              style: TextStyle(
                color: YYColors.accentSecondary,
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
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


