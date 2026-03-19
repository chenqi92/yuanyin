import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ============================================================
// 猿音 Design Tokens — 基于 UI 设计规范 §1
// ============================================================

/// 颜色系统 (UI 规范 §1.1)
class YYColors {
  YYColors._();

  // 背景
  static const Color bgBase = Color(0xFF000000);
  static const Color bgGlassThick = Color.fromRGBO(28, 28, 30, 0.75);
  static const Color bgGlassThickSolid = Color(0xFF1C1C1E);
  static const Color bgGlassThin = Color.fromRGBO(44, 44, 46, 0.4);
  static const Color bgGlassThinSolid = Color(0xFF2C2C2E);

  // 文字
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color.fromRGBO(235, 235, 245, 0.6);
  static const Color textTertiary = Color.fromRGBO(235, 235, 245, 0.3);

  // 强调色
  static const Color accentPrimary = Color(0xFF0A84FF);

  // 状态色
  static const Color statusSuccess = Color(0xFF32D74B);
  static const Color statusError = Color(0xFFFF453A);

  // 收藏红心
  static const Color heartRed = Color(0xFFFF453A);

  // 分隔线
  static const Color separator = Color.fromRGBO(84, 84, 88, 0.36);
}

/// 圆角 (UI 规范 §1.3)
class YYRadius {
  YYRadius._();

  static const double coverLarge = 12.0; // 全屏播放器封面
  static const double card = 16.0; // 卡片/列表项
  static const double bottomSheet = 24.0; // 底部弹窗
  static const double coverSmall = 6.0; // 迷你播放器封面
  static const double button = 100.0; // 胶囊按钮
}

/// 阴影 (UI 规范 §1.3)
class YYShadows {
  YYShadows._();

  static List<BoxShadow> get coverFloat => [
        const BoxShadow(
          offset: Offset(0, 16),
          blurRadius: 32,
          color: Color.fromRGBO(0, 0, 0, 0.5),
        ),
      ];
}

/// 模糊参数
class YYBlur {
  YYBlur._();

  static const double thick = 40.0; // 厚玻璃
  static const double thin = 20.0; // 薄玻璃
  static const double playerBg = 100.0; // 播放器背景
}

/// 尺寸参数
class YYSizes {
  YYSizes._();

  static const double miniPlayerHeight = 64.0;
  static const double tabBarHeight = 56.0;
  static const double miniCoverSize = 40.0;
  static const double playButtonLarge = 64.0;
  static const double playButtonMedium = 32.0;
  static const double progressBarHeight = 2.0;
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

/// 构建猿音暗色主题 (UI 规范 §1.2)
ThemeData buildYuanYinTheme() {
  final base = ThemeData.dark();

  final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
    // 全屏播放曲目名: 28sp / Bold
    headlineLarge: GoogleFonts.inter(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      height: 1.2,
      color: YYColors.textPrimary,
    ),
    // 模块大标题 H1: 24sp / Bold
    headlineMedium: GoogleFonts.inter(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      height: 1.3,
      color: YYColors.textPrimary,
    ),
    // 列表主标题 H2: 17sp / SemiBold
    titleMedium: GoogleFonts.inter(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      height: 1.4,
      color: YYColors.textPrimary,
    ),
    // 列表副标题/正文 Body: 15sp / Regular
    bodyLarge: GoogleFonts.inter(
      fontSize: 15,
      fontWeight: FontWeight.normal,
      height: 1.4,
      color: YYColors.textPrimary,
    ),
    bodyMedium: GoogleFonts.inter(
      fontSize: 15,
      fontWeight: FontWeight.normal,
      height: 1.4,
      color: YYColors.textSecondary,
    ),
    // 辅助说明 Caption: 12sp / Medium
    labelSmall: GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 1.2,
      color: YYColors.textTertiary,
    ),
    labelMedium: GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 1.2,
      color: YYColors.textSecondary,
    ),
  );

  return base.copyWith(
    scaffoldBackgroundColor: YYColors.bgBase,
    colorScheme: const ColorScheme.dark(
      surface: YYColors.bgBase,
      primary: YYColors.accentPrimary,
      error: YYColors.statusError,
    ),
    textTheme: textTheme,
    iconTheme: const IconThemeData(
      color: YYColors.textPrimary,
      size: 24,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: YYColors.textPrimary,
      ),
      iconTheme: IconThemeData(color: YYColors.textPrimary),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: YYColors.bgGlassThickSolid,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(YYRadius.bottomSheet),
        ),
      ),
    ),
    dividerColor: YYColors.separator,
    extensions: const [LiquidGlassTheme.dark],
  );
}
