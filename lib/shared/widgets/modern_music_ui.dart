import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';
import '../../features/player/domain/entities/music_item.dart';
import 'gradient_cover.dart';

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
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  base,
                  Color.alphaBlend(Colors.black.withValues(alpha: 0.08), base),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -96,
          right: accentAlignment.x >= 0 ? -70 : null,
          left: accentAlignment.x < 0 ? -70 : null,
          child: _GlowOrb(
            size: 132,
            colors: [
              glow.withValues(alpha: isDark ? 0.08 : 0.05),
              YYColors.accentSecondary.withValues(alpha: isDark ? 0.03 : 0.015),
              Colors.transparent,
            ],
          ),
        ),
        Positioned(
          bottom: -96,
          left: -40,
          child: _GlowOrb(
            size: 120,
            colors: [
              YYColors.accentSecondary.withValues(alpha: isDark ? 0.05 : 0.02),
              YYColors.accentTertiary.withValues(alpha: isDark ? 0.03 : 0.015),
              Colors.transparent,
            ],
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.03),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.10),
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
        imageFilter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
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

class YYPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final Color? color;
  final double radius;

  const YYPanel({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.gradient,
    this.color,
    this.radius = YYRadius.lg,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final panelDecoration = BoxDecoration(
      gradient: gradient,
      color: gradient == null
          ? color ??
                context.yyBgElevated.withValues(alpha: isDark ? 0.94 : 0.985)
          : null,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          offset: Offset(0, isDark ? 18 : 12),
          blurRadius: isDark ? 34 : 24,
          spreadRadius: isDark ? -24 : -18,
          color: Colors.black.withValues(alpha: isDark ? 0.34 : 0.08),
        ),
      ],
    );

    final panelBody = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: isDark ? 0.02 : 0.16),
            Colors.transparent,
          ],
        ),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );

    if (onTap == null) {
      return Container(
        margin: margin,
        decoration: panelDecoration,
        child: panelBody,
      );
    }

    return Container(
      margin: margin,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: panelDecoration,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(radius),
            overlayColor: WidgetStatePropertyAll(
              Colors.white.withValues(alpha: isDark ? 0.05 : 0.03),
            ),
            child: panelBody,
          ),
        ),
      ),
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
    final decoration = BoxDecoration(
      color: primary && !isDark ? YYColors.accentPrimary : null,
      gradient: primary && isDark ? YYColors.accentGradient : null,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: primary
            ? Colors.transparent
            : isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.05),
      ),
      boxShadow: primary
          ? [
              BoxShadow(
                offset: const Offset(0, 10),
                blurRadius: 20,
                spreadRadius: -12,
                color: YYColors.accentPrimary.withValues(
                  alpha: isDark ? 0.30 : 0.18,
                ),
              ),
            ]
          : null,
    );

    return Material(
      color: Colors.transparent,
      child: Ink(
        width: 40,
        height: 40,
        decoration: decoration,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          overlayColor: WidgetStatePropertyAll(
            primary
                ? Colors.white.withValues(alpha: 0.12)
                : context.yyTextPrimary.withValues(alpha: 0.05),
          ),
          child: Icon(
            icon,
            color: primary ? Colors.white : context.yyTextPrimary,
            size: 19,
          ),
        ),
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
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: TextStyle(
                    color: context.yyTextTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.35,
                  ),
                ),
                const SizedBox(height: 6),
                Text(title, style: Theme.of(context).textTheme.headlineLarge),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodyMedium,
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
    final rowChildren = <Widget>[
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: Theme.of(context).textTheme.labelMedium),
            ],
          ],
        ),
      ),
    ];

    if (trailing != null) {
      rowChildren.add(trailing!);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: rowChildren,
      ),
    );
  }
}

class YYIconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const YYIconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 42,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size / 3.2),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.95),
            Color.alphaBlend(
              YYColors.accentSecondary.withValues(alpha: 0.10),
              color,
            ),
          ],
        ),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 14),
            blurRadius: 28,
            spreadRadius: -18,
            color: color.withValues(alpha: isDark ? 0.38 : 0.18),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.44),
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
    final bg = primary
        ? null
        : context.yyBgSurface.withValues(alpha: isDark ? 0.84 : 0.96);
    final textColor = primary ? Colors.white : context.yyTextPrimary;
    final decoration = BoxDecoration(
      color: primary && !isDark ? YYColors.accentPrimary : bg,
      gradient: primary && isDark ? YYColors.accentGradient : null,
      borderRadius: BorderRadius.circular(YYRadius.full),
      border: Border.all(
        color: primary
            ? Colors.transparent
            : isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.05),
      ),
      boxShadow: primary
          ? [
              BoxShadow(
                offset: const Offset(0, 10),
                blurRadius: 22,
                spreadRadius: -14,
                color: YYColors.accentPrimary.withValues(
                  alpha: isDark ? 0.30 : 0.16,
                ),
              ),
            ]
          : null,
    );

    return Material(
      color: Colors.transparent,
      child: Ink(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 15,
          vertical: compact ? 8 : 10,
        ),
        decoration: decoration,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(YYRadius.full),
          overlayColor: WidgetStatePropertyAll(
            primary
                ? Colors.white.withValues(alpha: 0.12)
                : context.yyTextPrimary.withValues(alpha: 0.05),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: textColor, size: compact ? 16 : 18),
                SizedBox(width: compact ? 6 : 8),
              ],
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: compact ? 12 : 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class YYStatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const YYStatChip({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: context.yyBgSurface.withValues(
            alpha: context.isDark ? 0.72 : 0.90,
          ),
          borderRadius: BorderRadius.circular(YYRadius.md),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: context.yyTextPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: context.yyTextSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class YYTag extends StatelessWidget {
  final String text;
  final Color? color;
  final IconData? icon;
  final VoidCallback? onTap;

  const YYTag({
    super.key,
    required this.text,
    this.color,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? context.yyBgSurface;
    final decoration = BoxDecoration(
      color: chipColor.withValues(alpha: context.isDark ? 0.22 : 0.75),
      borderRadius: BorderRadius.circular(YYRadius.full),
      border: Border.all(color: chipColor.withValues(alpha: 0.18)),
    );
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: context.yyTextSecondary),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(
              color: context.yyTextSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return Container(decoration: decoration, child: content);
    }

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: decoration,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(YYRadius.full),
          overlayColor: WidgetStatePropertyAll(
            context.yyTextPrimary.withValues(alpha: 0.04),
          ),
          child: content,
        ),
      ),
    );
  }
}

class YYMetricBandItem {
  const YYMetricBandItem({required this.label, required this.value, this.tint});

  final String label;
  final String value;
  final Color? tint;
}

class YYMetricBand extends StatelessWidget {
  final List<YYMetricBandItem> items;

  const YYMetricBand({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: context.yyBgSurface.withValues(
          alpha: context.isDark ? 0.56 : 0.84,
        ),
        borderRadius: BorderRadius.circular(YYRadius.md),
        border: Border.all(
          color: context.isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Row(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            Expanded(child: _MetricBandCell(item: items[index])),
            if (index != items.length - 1)
              Container(width: 1, height: 34, color: context.yySeparator),
          ],
        ],
      ),
    );
  }
}

class _MetricBandCell extends StatelessWidget {
  final YYMetricBandItem item;

  const _MetricBandCell({required this.item});

  @override
  Widget build(BuildContext context) {
    final tint = item.tint ?? context.yyTextPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.value,
            style: TextStyle(
              color: tint,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.label,
            style: TextStyle(
              color: context.yyTextTertiary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class YYActionRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const YYActionRow({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        overlayColor: WidgetStatePropertyAll(
          context.yyTextPrimary.withValues(alpha: 0.04),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              YYIconBadge(icon: icon, color: color, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: context.yyTextTertiary,
              ),
            ],
          ),
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
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      padding: const EdgeInsets.all(11),
      color: active
          ? YYColors.accentPrimary.withValues(
              alpha: context.isDark ? 0.14 : 0.12,
            )
          : null,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: onLongPress,
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            ClipRRect(
              borderRadius: BorderRadius.circular(YYRadius.sm),
              child: SizedBox(
                width: 54,
                height: 54,
                child: GradientCover(
                  seed: '${song.title}_${song.artist}',
                  coverUrl: song.coverUrl,
                  size: 54,
                  borderRadius: YYRadius.sm,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: active
                          ? YYColors.accentPrimary
                          : context.yyTextPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle ?? '${song.artist} · ${song.album}',
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
            const SizedBox(width: 10),
            trailing ??
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      song.durationText,
                      style: TextStyle(
                        color: context.yyTextTertiary,
                        fontSize: 12,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    if ((song.format ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        song.format!,
                        style: TextStyle(
                          color: YYColors.accentSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ],
                ),
          ],
        ),
      ),
    );
  }
}
