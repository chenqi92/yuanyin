import 'dart:ui';

import 'package:flutter/cupertino.dart';
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
                  yyMix(base, const Color(0xFF18181B), 0.60),
                  const Color(0xFF040506),
                ],
                stops: const [0, 0.42, 1],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.92),
                  radius: 1.05,
                  colors: [
                    const Color(0xFF3A2144).withValues(alpha: 0.14),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, 1.08),
                  radius: 1.18,
                  colors: [
                    const Color(0xFF05303A).withValues(alpha: 0.10),
                    Colors.transparent,
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
      color:
          color ?? context.yyBgElevated.withValues(alpha: isDark ? 0.92 : 0.96),
      gradient: gradient,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.05),
        width: 0.7,
      ),
    );

    final panelBody = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: panelDecoration,
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );

    if (onTap == null) {
      return Container(margin: margin, child: panelBody);
    }

    return Container(
      margin: margin,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          overlayColor: WidgetStatePropertyAll(
            Colors.white.withValues(alpha: isDark ? 0.05 : 0.03),
          ),
          child: panelBody,
        ),
      ),
    );
  }
}

class YYLiquidGlass extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final bool thin;
  final double? blurSigma;
  final Color? color;

  const YYLiquidGlass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.margin,
    this.radius = YYRadius.xl,
    this.thin = false,
    this.blurSigma,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final glass =
        Theme.of(context).extension<LiquidGlassTheme>() ??
        (context.isDark ? LiquidGlassTheme.dark : LiquidGlassTheme.light);
    final fill = color ?? (thin ? glass.glassThin : glass.glassThick);

    final surface = CupertinoTheme(
      data: CupertinoThemeData(
        brightness: context.isDark ? Brightness.dark : Brightness.light,
      ),
      child: CupertinoPopupSurface(
        blurSigma: blurSigma ?? (thin ? glass.blurThin : glass.blurThick),
        isSurfacePainted: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: Colors.white.withValues(
                alpha: context.isDark ? 0.10 : 0.18,
              ),
              width: 0.8,
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );

    if (margin == null) return surface;
    return Padding(padding: margin!, child: surface);
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
    );

    return Material(
      color: Colors.transparent,
      child: Ink(
        width: 44,
        height: 44,
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

/// iOS Large Title style page header.
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
                  eyebrow.toUpperCase(),
                  style: TextStyle(
                    color: context.yyTextTertiary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    color: context.yyTextPrimary,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.7,
                    height: 1.08,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: context.yyTextSecondary,
                      fontSize: 13,
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

/// iOS grouped-list section header style.
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
            Text(
              title.toUpperCase(),
              style: TextStyle(
                color: context.yyTextSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: TextStyle(color: context.yyTextTertiary, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    ];

    if (trailing != null) {
      rowChildren.add(trailing!);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
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
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
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
    );

    return Material(
      color: Colors.transparent,
      child: Ink(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 16,
          vertical: compact ? 10 : 12,
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
                  fontSize: compact ? 13 : 14,
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
        constraints: const BoxConstraints(minHeight: 44),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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

/// Standardised track row: cover 44x44 rounded 6, title 15px medium,
/// subtitle 13px secondary, trailing duration or custom widget.
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
    return Padding(
      padding: margin ?? const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          overlayColor: WidgetStatePropertyAll(
            context.yyTextPrimary.withValues(alpha: 0.04),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 10)],
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: GradientCover(
                      seed: '${song.title}_${song.artist}',
                      coverUrl: song.coverUrl,
                      size: 44,
                      borderRadius: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
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
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle ?? '${song.artist} · ${song.album}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.yyTextSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                trailing ??
                    Text(
                      song.durationText,
                      style: TextStyle(
                        color: context.yyTextTertiary,
                        fontSize: 13,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
