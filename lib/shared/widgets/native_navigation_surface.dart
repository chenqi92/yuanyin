import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/theme.dart';

class YYNativeNavigationSurface extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  const YYNativeNavigationSurface({
    super.key,
    required this.child,
    this.radius = YYRadius.xl,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: YYShadows.cardSubtle,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: _SurfaceBackground(radius: radius),
            ),
          ),
          Padding(
            padding: padding,
            child: child,
          ),
        ],
      ),
    );
  }
}

class _SurfaceBackground extends StatelessWidget {
  final double radius;

  const _SurfaceBackground({
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        viewType: 'yy/native_surface',
        creationParamsCodec: const StandardMessageCodec(),
        creationParams: <String, Object>{
          'radius': radius,
        },
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            context.yyBgElevated.withValues(alpha: context.isDark ? 0.96 : 0.94),
            context.yyBgElevated.withValues(alpha: context.isDark ? 0.92 : 0.98),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: context.isDark ? 0.08 : 0.72),
        ),
      ),
    );
  }
}
