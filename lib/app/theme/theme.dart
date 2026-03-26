import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

class YYColors {
  YYColors._();

  // iOS 26 Liquid Glass - Pure Black Base
  static const Color bgBase = Color(0xFF000000);
  static const Color bgElevated = Color(0xFF0F0F12);
  static const Color bgSurface = Color(0xFF16161C);
  
  // Glass colors as per design spec
  static const Color bgGlassThick = Color.fromRGBO(28, 28, 30, 0.75); // blur(40px)
  static const Color bgGlassThickSolid = Color(0xFF1C1C1E);
  static const Color bgGlassThin = Color.fromRGBO(44, 44, 46, 0.4);   // blur(20px)
  static const Color bgGlassThinSolid = Color(0xFF2C2C2E);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color.fromRGBO(235, 235, 245, 0.6); // iOS systemGray
  static const Color textTertiary = Color.fromRGBO(235, 235, 245, 0.3);
  static const Color textOnAccent = Color(0xFFFFFFFF);

  // iOS Blue as per spec
  static const Color accentPrimary = Color(0xFF0A84FF);
  static const Color accentSecondary = Color(0xFF30D158); // iOS Green
  static const Color accentTertiary = Color(0xFF5E5CE6);  // iOS Indigo

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0A84FF), Color(0xFF007AFF)],
  );

  static const LinearGradient auroraGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF30D158), Color(0xFF0A84FF)],
  );

  static const Color statusSuccess = Color(0xFF32D74B);
  static const Color statusError = Color(0xFFFF453A);
  static const Color statusWarning = Color(0xFFFF9F0A);
  static const Color heartRed = Color(0xFFFF453A);
  static const Color separator = Color.fromRGBO(255, 255, 255, 0.1);

  static const List<List<Color>> categoryGradients = [
    [Color(0xFF0A84FF), Color(0xFF007AFF)],
    [Color(0xFF30D158), Color(0xFF28CD41)],
    [Color(0xFFFF453A), Color(0xFFFF3B30)],
    [Color(0xFF5E5CE6), Color(0xFF5856D6)],
    [Color(0xFFFF9F0A), Color(0xFFFF9500)],
    [Color(0xFF64748B), Color(0xFF94A3B8)],
  ];
}

class YYLightColors {
  YYLightColors._();

  static const Color bgBase = Color(0xFFF2F2F7);
  static const Color bgElevated = Color(0xFFFFFFFF);
  static const Color bgSurface = Color(0xFFE5E5EA);
  static const Color textPrimary = Color(0xFF000000);
  static const Color textSecondary = Color.fromRGBO(60, 60, 67, 0.6);
  static const Color textTertiary = Color.fromRGBO(60, 60, 67, 0.3);
  static const Color separator = Color.fromRGBO(60, 60, 67, 0.1);
}

class YYRadius {
  YYRadius._();

  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 20.0;
  static const double xl = 26.0;
  static const double full = 999.0;

  static const double coverLarge = 12.0; // Per spec: 12px for now playing cover
  static const double coverSmall = 6.0;  // Per spec: 6px for mini player cover
  static const double card = 16.0;       // Per spec: 16px
  static const double bottomSheet = 24.0; // Per spec: 24px
  static const double button = 999.0;
  static const double searchBar = 22.0;
}

class YYShadows {
  YYShadows._();

  static List<BoxShadow> get coverFloat => [
    const BoxShadow(
      offset: Offset(0, 16),
      blurRadius: 32,
      color: Color.fromRGBO(0, 0, 0, 0.5),
    ),
  ];

  static List<BoxShadow> get cardSubtle => [
    const BoxShadow(
      offset: Offset(0, 8),
      blurRadius: 24,
      spreadRadius: -12,
      color: Color.fromRGBO(0, 0, 0, 0.3),
    ),
  ];

  static List<BoxShadow> accentGlow(Color color) => [
    BoxShadow(
      offset: const Offset(0, 8),
      blurRadius: 24,
      spreadRadius: -8,
      color: color.withValues(alpha: 0.3),
    ),
  ];
}

class YYBlur {
  YYBlur._();

  static const double thick = 40.0; // Per spec: blur(40px)
  static const double thin = 20.0;  // Per spec: blur(20px)
  static const double playerBg = 100.0; // Per spec: sigma 100
}

class YYSizes {
  YYSizes._();

  static const double miniPlayerHeight = 64.0;
  static const double tabBarHeight = 58.0;
  static const double miniCoverSize = 40.0;
  static const double playButtonLarge = 64.0; // Per spec: 64x64
  static const double playButtonMedium = 32.0; // Per spec: 32x32
  static const double progressBarHeight = 2.0; // Per spec: 2px
  static const double songRowHeight = 72.0;
}

class YYSpacing {
  YYSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double screenH = 20.0;
}

class YYSeedPalette {
  YYSeedPalette._();

  static Color primary(String seed) {
    final hue = (seed.hashCode % 360).abs().toDouble();
    return HSLColor.fromAHSL(1, hue, 0.85, 0.5).toColor();
  }

  static Color secondary(String seed) {
    final hue = ((seed.hashCode % 360) + 40).abs().toDouble() % 360;
    return HSLColor.fromAHSL(1, hue, 0.75, 0.45).toColor();
  }

  static LinearGradient gradient(String seed) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primary(seed), secondary(seed)],
    );
  }

  static Color backdrop(String seed) {
    final hue = (seed.hashCode % 360).abs().toDouble();
    return HSLColor.fromAHSL(1, hue, 0.6, 0.3).toColor();
  }
}

class LiquidGlassTheme extends ThemeExtension<LiquidGlassTheme> {
  final Color glassThick;
  final Color glassThin;
  final double blurThick;
  final double blurThin;

  const LiquidGlassTheme({
    required this.glassThick,
    required this.glassThin,
    required this.blurThick,
    required this.blurThin,
  });

  static const dark = LiquidGlassTheme(
    glassThick: YYColors.bgGlassThick,
    glassThin: YYColors.bgGlassThin,
    blurThick: YYBlur.thick,
    blurThin: YYBlur.thin,
  );

  static const light = LiquidGlassTheme(
    glassThick: Color.fromRGBO(255, 255, 255, 0.84),
    glassThin: Color.fromRGBO(255, 255, 255, 0.66),
    blurThick: YYBlur.thick,
    blurThin: YYBlur.thin,
  );

  @override
  LiquidGlassTheme copyWith({
    Color? glassThick,
    Color? glassThin,
    double? blurThick,
    double? blurThin,
  }) {
    return LiquidGlassTheme(
      glassThick: glassThick ?? this.glassThick,
      glassThin: glassThin ?? this.glassThin,
      blurThick: blurThick ?? this.blurThick,
      blurThin: blurThin ?? this.blurThin,
    );
  }

  @override
  LiquidGlassTheme lerp(LiquidGlassTheme? other, double t) {
    if (other == null) {
      return this;
    }

    return LiquidGlassTheme(
      glassThick: Color.lerp(glassThick, other.glassThick, t)!,
      glassThin: Color.lerp(glassThin, other.glassThin, t)!,
      blurThick: lerpDouble(blurThick, other.blurThick, t)!,
      blurThin: lerpDouble(blurThin, other.blurThin, t)!,
    );
  }
}

ThemeData buildYYDarkTheme() {
  final base = ThemeData.dark(useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: YYColors.bgBase,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    colorScheme: const ColorScheme.dark(
      surface: YYColors.bgElevated,
      primary: YYColors.accentPrimary,
      secondary: YYColors.accentSecondary,
      tertiary: YYColors.accentTertiary,
      error: YYColors.statusError,
    ),
    textTheme: _buildTextTheme(
      base.textTheme,
      primary: YYColors.textPrimary,
      secondary: YYColors.textSecondary,
      tertiary: YYColors.textTertiary,
    ),
    iconTheme: const IconThemeData(color: YYColors.textPrimary, size: 22),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: YYColors.textPrimary,
    ),
    dividerColor: YYColors.separator,
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: YYColors.accentPrimary,
      inactiveTrackColor: Colors.white.withValues(alpha: 0.10),
      thumbColor: YYColors.textPrimary,
      overlayColor: YYColors.accentPrimary.withValues(alpha: 0.14),
      trackHeight: 2.5,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: YYColors.bgElevated.withValues(alpha: 0.96),
      contentTextStyle: const TextStyle(
        color: YYColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(YYRadius.md),
      ),
    ),
    extensions: const [LiquidGlassTheme.dark],
  );
}

ThemeData buildYYLightTheme() {
  final base = ThemeData.light(useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: YYLightColors.bgBase,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    colorScheme: const ColorScheme.light(
      surface: YYLightColors.bgElevated,
      primary: YYColors.accentPrimary,
      secondary: YYColors.accentSecondary,
      tertiary: YYColors.accentTertiary,
      error: YYColors.statusError,
    ),
    textTheme: _buildTextTheme(
      base.textTheme,
      primary: YYLightColors.textPrimary,
      secondary: YYLightColors.textSecondary,
      tertiary: YYLightColors.textTertiary,
    ),
    iconTheme: const IconThemeData(color: YYLightColors.textPrimary, size: 22),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: YYLightColors.textPrimary,
    ),
    dividerColor: YYLightColors.separator,
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: YYColors.accentPrimary,
      inactiveTrackColor: YYLightColors.textTertiary.withValues(alpha: 0.24),
      thumbColor: YYColors.accentPrimary,
      overlayColor: YYColors.accentPrimary.withValues(alpha: 0.12),
      trackHeight: 2.5,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: YYLightColors.bgElevated.withValues(alpha: 0.98),
      contentTextStyle: const TextStyle(
        color: YYLightColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(YYRadius.md),
      ),
    ),
    extensions: const [LiquidGlassTheme.light],
  );
}

TextTheme _buildTextTheme(
  TextTheme base, {
  required Color primary,
  required Color secondary,
  required Color tertiary,
}) {
  const fontFamily = 'SF Pro Display';
  const fallback = ['PingFang SC', 'SF Pro Text', 'Avenir Next', 'sans-serif'];

  TextStyle style(
    double size,
    FontWeight weight,
    Color color, {
    double height = 1.2,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fallback,
      fontSize: size,
      fontWeight: weight,
      height: height,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  return base.copyWith(
    headlineLarge: style(
      24,
      FontWeight.w800,
      primary,
      height: 1.08,
      letterSpacing: -0.7,
    ),
    headlineMedium: style(
      20,
      FontWeight.w800,
      primary,
      height: 1.10,
      letterSpacing: -0.3,
    ),
    titleLarge: style(
      17,
      FontWeight.w700,
      primary,
      height: 1.15,
      letterSpacing: -0.15,
    ),
    titleMedium: style(15, FontWeight.w700, primary, height: 1.20),
    bodyLarge: style(15, FontWeight.w500, primary, height: 1.35),
    bodyMedium: style(13, FontWeight.w500, secondary, height: 1.35),
    labelLarge: style(13, FontWeight.w700, primary, height: 1.2),
    labelMedium: style(
      12,
      FontWeight.w700,
      secondary,
      height: 1.2,
      letterSpacing: 0.2,
    ),
    labelSmall: style(
      11,
      FontWeight.w700,
      tertiary,
      height: 1.2,
      letterSpacing: 0.5,
    ),
  );
}

extension YYAdaptiveColors on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get yyBgBase => isDark ? YYColors.bgBase : YYLightColors.bgBase;
  Color get yyBgElevated =>
      isDark ? YYColors.bgElevated : YYLightColors.bgElevated;
  Color get yyBgSurface =>
      isDark ? YYColors.bgSurface : YYLightColors.bgSurface;
  Color get yyTextPrimary =>
      isDark ? YYColors.textPrimary : YYLightColors.textPrimary;
  Color get yyTextSecondary =>
      isDark ? YYColors.textSecondary : YYLightColors.textSecondary;
  Color get yyTextTertiary =>
      isDark ? YYColors.textTertiary : YYLightColors.textTertiary;
  Color get yySeparator =>
      isDark ? YYColors.separator : YYLightColors.separator;

  Color yyBlend(Color color, {double amount = 0.12}) {
    return Color.alphaBlend(color.withValues(alpha: amount), yyBgElevated);
  }

  LinearGradient yySeedGradient(String seed) => YYSeedPalette.gradient(seed);
}

Color yyMix(Color a, Color b, double t) {
  return Color.lerp(a, b, t)!;
}

double yyClamp(double value, double min, double max) {
  return math.max(min, math.min(max, value));
}
