import 'dart:ui';
import 'package:flutter/material.dart';

// ============================================================
// Primuse Design Tokens v2 — 现代深色主题
// ============================================================

/// 颜色系统
class YYColors {
  YYColors._();

  // 背景层次
  static const Color bgBase = Color(0xFF0A0A12);        // 深蓝黑底色
  static const Color bgElevated = Color(0xFF141420);     // 卡片/抬升背景
  static const Color bgSurface = Color(0xFF1C1C2E);      // 输入框/搜索框
  static const Color bgGlassThick = Color.fromRGBO(20, 20, 32, 0.85);
  static const Color bgGlassThickSolid = Color(0xFF1C1C2E);
  static const Color bgGlassThin = Color.fromRGBO(28, 28, 46, 0.5);
  static const Color bgGlassThinSolid = Color(0xFF2C2C3E);

  // 文字
  static const Color textPrimary = Color(0xFFF5F5F7);    // 主文字（温白）
  static const Color textSecondary = Color(0xFF8E8E9A);  // 副文字
  static const Color textTertiary = Color(0xFF56566A);   // 三级文字
  static const Color textOnAccent = Color(0xFFFFFFFF);    // 强调色上的文字

  // 强调色（靛紫渐变）
  static const Color accentPrimary = Color(0xFF6366F1);  // Indigo
  static const Color accentSecondary = Color(0xFF8B5CF6); // Purple
  static const Color accentTertiary = Color(0xFFA78BFA);  // Light purple

  // 渐变
  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // 状态色
  static const Color statusSuccess = Color(0xFF34D399);
  static const Color statusError = Color(0xFFEF4444);
  static const Color statusWarning = Color(0xFFF59E0B);

  // 收藏红心
  static const Color heartRed = Color(0xFFEF4444);

  // 分隔线
  static const Color separator = Color.fromRGBO(255, 255, 255, 0.06);

  // 分类卡片渐变集
  static const List<List<Color>> categoryGradients = [
    [Color(0xFF6366F1), Color(0xFF8B5CF6)], // 艺术家 - 靛紫
    [Color(0xFFEC4899), Color(0xFFF472B6)], // 专辑 - 粉红
    [Color(0xFF06B6D4), Color(0xFF22D3EE)], // 流派 - 青色
    [Color(0xFF10B981), Color(0xFF34D399)], // 歌曲 - 翠绿
    [Color(0xFFEF4444), Color(0xFFF87171)], // 收藏 - 红色
    [Color(0xFFF59E0B), Color(0xFFFBBF24)], // 下载 - 琥珀
  ];
}

/// 圆角
class YYRadius {
  YYRadius._();

  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double full = 100.0; // 胶囊

  // 语义化
  static const double coverLarge = 16.0;
  static const double coverSmall = 8.0;
  static const double card = 16.0;
  static const double bottomSheet = 24.0;
  static const double button = 100.0;
  static const double searchBar = 16.0;
}

/// 阴影
class YYShadows {
  YYShadows._();

  static List<BoxShadow> get coverFloat => [
        const BoxShadow(
          offset: Offset(0, 16),
          blurRadius: 40,
          color: Color.fromRGBO(0, 0, 0, 0.4),
        ),
      ];

  static List<BoxShadow> get cardSubtle => [
        BoxShadow(
          offset: const Offset(0, 2),
          blurRadius: 8,
          color: Colors.black.withValues(alpha: 0.2),
        ),
      ];

  static List<BoxShadow> accentGlow(Color color) => [
        BoxShadow(
          offset: const Offset(0, 4),
          blurRadius: 16,
          color: color.withValues(alpha: 0.25),
        ),
      ];
}

/// 模糊参数
class YYBlur {
  YYBlur._();

  static const double thick = 40.0;
  static const double thin = 20.0;
  static const double playerBg = 80.0;
}

/// 尺寸参数
class YYSizes {
  YYSizes._();

  static const double miniPlayerHeight = 68.0;
  static const double tabBarHeight = 52.0;
  static const double miniCoverSize = 44.0;
  static const double playButtonLarge = 64.0;
  static const double playButtonMedium = 32.0;
  static const double progressBarHeight = 2.0;
  static const double songRowHeight = 60.0;
}

/// 间距
class YYSpacing {
  YYSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double screenH = 20.0; // 水平屏幕边距
}

/// Liquid Glass 主题扩展
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
    if (other == null) return this;
    return LiquidGlassTheme(
      glassThick: Color.lerp(glassThick, other.glassThick, t)!,
      glassThin: Color.lerp(glassThin, other.glassThin, t)!,
      blurThick: lerpDouble(blurThick, other.blurThick, t)!,
      blurThin: lerpDouble(blurThin, other.blurThin, t)!,
    );
  }
}

/// 构建 Primuse 暗色主题
ThemeData buildPrimuseDarkTheme() {
  final base = ThemeData.dark();
  const fontFamily = '.AppleSystemUIFont';

  return base.copyWith(
    scaffoldBackgroundColor: YYColors.bgBase,
    colorScheme: const ColorScheme.dark(
      surface: YYColors.bgBase,
      primary: YYColors.accentPrimary,
      secondary: YYColors.accentSecondary,
      error: YYColors.statusError,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontFamily: fontFamily, fontSize: 28, fontWeight: FontWeight.bold, height: 1.2, color: YYColors.textPrimary, letterSpacing: -0.5),
      headlineMedium: TextStyle(fontFamily: fontFamily, fontSize: 22, fontWeight: FontWeight.bold, height: 1.3, color: YYColors.textPrimary, letterSpacing: -0.3),
      titleLarge: TextStyle(fontFamily: fontFamily, fontSize: 20, fontWeight: FontWeight.w600, height: 1.3, color: YYColors.textPrimary),
      titleMedium: TextStyle(fontFamily: fontFamily, fontSize: 17, fontWeight: FontWeight.w600, height: 1.4, color: YYColors.textPrimary),
      bodyLarge: TextStyle(fontFamily: fontFamily, fontSize: 16, fontWeight: FontWeight.normal, height: 1.5, color: YYColors.textPrimary),
      bodyMedium: TextStyle(fontFamily: fontFamily, fontSize: 14, fontWeight: FontWeight.normal, height: 1.5, color: YYColors.textSecondary),
      labelLarge: TextStyle(fontFamily: fontFamily, fontSize: 14, fontWeight: FontWeight.w600, height: 1.2, color: YYColors.textPrimary),
      labelMedium: TextStyle(fontFamily: fontFamily, fontSize: 12, fontWeight: FontWeight.w500, height: 1.2, color: YYColors.textSecondary),
      labelSmall: TextStyle(fontFamily: fontFamily, fontSize: 11, fontWeight: FontWeight.w500, height: 1.2, color: YYColors.textTertiary),
    ),
    iconTheme: const IconThemeData(color: YYColors.textPrimary, size: 24),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent, elevation: 0, centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: fontFamily, fontSize: 28, fontWeight: FontWeight.bold, color: YYColors.textPrimary, letterSpacing: -0.5),
      iconTheme: IconThemeData(color: YYColors.textPrimary),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: YYColors.bgElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(YYRadius.xl))),
    ),
    sliderTheme: SliderThemeData(
      thumbColor: YYColors.accentPrimary, activeTrackColor: YYColors.accentPrimary,
      inactiveTrackColor: YYColors.textTertiary.withValues(alpha: 0.3),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6), trackHeight: 3,
    ),
    dividerColor: YYColors.separator,
    extensions: const [LiquidGlassTheme.dark],
  );
}

/// 淡色模式颜色 — 通过 YYLightColors 访问，运行时根据 brightness 选取
class YYLightColors {
  YYLightColors._();
  static const Color bgBase = Color(0xFFF5F5F7);
  static const Color bgElevated = Color(0xFFFFFFFF);
  static const Color bgSurface = Color(0xFFEFEFF1);
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B6B80);
  static const Color textTertiary = Color(0xFFA0A0B0);
  static const Color separator = Color.fromRGBO(0, 0, 0, 0.06);
}

/// 构建 Primuse 淡色主题
ThemeData buildPrimuseLightTheme() {
  final base = ThemeData.light();
  const fontFamily = '.AppleSystemUIFont';

  return base.copyWith(
    scaffoldBackgroundColor: YYLightColors.bgBase,
    colorScheme: const ColorScheme.light(
      surface: YYLightColors.bgBase,
      primary: YYColors.accentPrimary,
      secondary: YYColors.accentSecondary,
      error: YYColors.statusError,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontFamily: fontFamily, fontSize: 28, fontWeight: FontWeight.bold, height: 1.2, color: YYLightColors.textPrimary, letterSpacing: -0.5),
      headlineMedium: TextStyle(fontFamily: fontFamily, fontSize: 22, fontWeight: FontWeight.bold, height: 1.3, color: YYLightColors.textPrimary, letterSpacing: -0.3),
      titleLarge: TextStyle(fontFamily: fontFamily, fontSize: 20, fontWeight: FontWeight.w600, height: 1.3, color: YYLightColors.textPrimary),
      titleMedium: TextStyle(fontFamily: fontFamily, fontSize: 17, fontWeight: FontWeight.w600, height: 1.4, color: YYLightColors.textPrimary),
      bodyLarge: TextStyle(fontFamily: fontFamily, fontSize: 16, fontWeight: FontWeight.normal, height: 1.5, color: YYLightColors.textPrimary),
      bodyMedium: TextStyle(fontFamily: fontFamily, fontSize: 14, fontWeight: FontWeight.normal, height: 1.5, color: YYLightColors.textSecondary),
      labelLarge: TextStyle(fontFamily: fontFamily, fontSize: 14, fontWeight: FontWeight.w600, height: 1.2, color: YYLightColors.textPrimary),
      labelMedium: TextStyle(fontFamily: fontFamily, fontSize: 12, fontWeight: FontWeight.w500, height: 1.2, color: YYLightColors.textSecondary),
      labelSmall: TextStyle(fontFamily: fontFamily, fontSize: 11, fontWeight: FontWeight.w500, height: 1.2, color: YYLightColors.textTertiary),
    ),
    iconTheme: const IconThemeData(color: YYLightColors.textPrimary, size: 24),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent, elevation: 0, centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: fontFamily, fontSize: 28, fontWeight: FontWeight.bold, color: YYLightColors.textPrimary, letterSpacing: -0.5),
      iconTheme: IconThemeData(color: YYLightColors.textPrimary),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: YYLightColors.bgElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(YYRadius.xl))),
    ),
    sliderTheme: SliderThemeData(
      thumbColor: YYColors.accentPrimary, activeTrackColor: YYColors.accentPrimary,
      inactiveTrackColor: YYLightColors.textTertiary.withValues(alpha: 0.3),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6), trackHeight: 3,
    ),
    dividerColor: YYLightColors.separator,
  );
}

/// 便捷方法：根据 Brightness 获取对应颜色
extension YYAdaptiveColors on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get yyBgBase => isDark ? YYColors.bgBase : YYLightColors.bgBase;
  Color get yyBgElevated => isDark ? YYColors.bgElevated : YYLightColors.bgElevated;
  Color get yyBgSurface => isDark ? YYColors.bgSurface : YYLightColors.bgSurface;
  Color get yyTextPrimary => isDark ? YYColors.textPrimary : YYLightColors.textPrimary;
  Color get yyTextSecondary => isDark ? YYColors.textSecondary : YYLightColors.textSecondary;
  Color get yyTextTertiary => isDark ? YYColors.textTertiary : YYLightColors.textTertiary;
  Color get yySeparator => isDark ? YYColors.separator : YYLightColors.separator;
}

