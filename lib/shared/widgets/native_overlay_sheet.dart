import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';
import '../services/native_tab_bar_service.dart';
import 'modern_music_ui.dart';

class YYBottomOverlayInset extends StatelessWidget {
  final Widget child;
  final double horizontal;
  final double top;
  final double bottom;

  const YYBottomOverlayInset({
    super.key,
    required this.child,
    this.horizontal = 12,
    this.top = 8,
    this.bottom = 8,
  });

  @override
  Widget build(BuildContext context) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final extraBottom = isIOS
        ? NativeTabBarService.instance.currentMetrics.totalHeight + 12
        : MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontal,
          top,
          horizontal,
          bottom + extraBottom,
        ),
        child: child,
      ),
    );
  }
}

Future<T?> showYYSurfaceSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useRootNavigator = true,
  bool isScrollControlled = false,
  Color? color,
  BorderRadiusGeometry borderRadius = const BorderRadius.vertical(
    top: Radius.circular(20),
  ),
  double horizontalPadding = 12,
  double topPadding = 8,
  double bottomPadding = 8,
}) {
  final resolvedRadius = borderRadius is BorderRadius
      ? borderRadius.topLeft.x
      : YYRadius.bottomSheet;

  return showCupertinoModalPopup<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
    builder: (sheetContext) {
      return YYBottomOverlayInset(
        horizontal: horizontalPadding,
        top: topPadding,
        bottom: bottomPadding,
        child: YYLiquidGlass(
          thin: true,
          radius: resolvedRadius,
          color: color ?? sheetContext.yyBgElevated.withValues(alpha: 0.84),
          padding: EdgeInsets.zero,
          child: builder(sheetContext),
        ),
      );
    },
  );
}

Future<T?> showYYCupertinoPopup<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useRootNavigator = true,
}) {
  return showCupertinoModalPopup<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
    builder: (popupContext) {
      return YYBottomOverlayInset(
        horizontal: 10,
        top: 8,
        bottom: 0,
        child: YYLiquidGlass(
          thin: true,
          radius: YYRadius.bottomSheet,
          padding: EdgeInsets.zero,
          child: builder(popupContext),
        ),
      );
    },
  );
}

Future<T?> showYYNativeCupertinoPopup<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useRootNavigator = true,
  double horizontalPadding = 0,
  double topPadding = 0,
  double bottomPadding = 0,
}) {
  return showCupertinoModalPopup<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    builder: (popupContext) {
      return YYBottomOverlayInset(
        horizontal: horizontalPadding,
        top: topPadding,
        bottom: bottomPadding,
        child: builder(popupContext),
      );
    },
  );
}
