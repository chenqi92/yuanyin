import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/theme.dart';
import '../../data/services/equalizer_service.dart';

/// 均衡器页面
///
/// 5 段 EQ 滑块 + 预设选择器
class EqualizerPage extends ConsumerWidget {
  const EqualizerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eq = ref.watch(equalizerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? YYColors.bgBase : YYLightColors.bgBase;
    final card = isDark ? YYColors.bgElevated : YYLightColors.bgElevated;
    final pri = isDark ? YYColors.textPrimary : YYLightColors.textPrimary;
    final sub = isDark ? YYColors.textSecondary : YYLightColors.textSecondary;
    final tri = isDark ? YYColors.textTertiary : YYLightColors.textTertiary;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text('均衡器', style: TextStyle(color: pri, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: Icon(CupertinoIcons.back, color: pri),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Switch.adaptive(
            value: eq.enabled,
            activeColor: YYColors.accentPrimary,
            onChanged: (v) => ref.read(equalizerProvider.notifier).setEnabled(v),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 16),

            // 预设选择器
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: EqualizerService.presets.keys.map((name) {
                  final isActive = eq.presetName == name;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => ref.read(equalizerProvider.notifier).setPreset(name),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isActive ? YYColors.accentPrimary : card,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(name, style: TextStyle(
                          color: isActive ? Colors.white : sub,
                          fontSize: 13,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                        )),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 32),

            // 5 段 EQ 滑块
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(5, (i) {
                  return _EQBandSlider(
                    label: eqBandLabels[i],
                    value: eq.gains[i],
                    enabled: eq.enabled,
                    onChanged: (v) => ref.read(equalizerProvider.notifier).setBandGain(i, v),
                    pri: pri,
                    sub: sub,
                    tri: tri,
                  );
                }),
              ),
            ),

            const SizedBox(height: 16),

            // 重置按钮
            TextButton.icon(
              onPressed: () => ref.read(equalizerProvider.notifier).resetAll(),
              icon: const Icon(CupertinoIcons.arrow_counterclockwise, size: 16),
              label: Text('重置', style: TextStyle(color: tri)),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _EQBandSlider extends StatelessWidget {
  final String label;
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;
  final Color pri;
  final Color sub;
  final Color tri;

  const _EQBandSlider({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.pri,
    required this.sub,
    required this.tri,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '${value.toStringAsFixed(1)} dB',
          style: TextStyle(color: enabled ? sub : tri, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: enabled ? YYColors.accentPrimary : tri,
                inactiveTrackColor: tri.withValues(alpha: 0.2),
                thumbColor: enabled ? YYColors.accentPrimary : tri,
              ),
              child: Slider(
                value: value,
                min: -12,
                max: 12,
                onChanged: enabled ? onChanged : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: enabled ? pri : tri, fontSize: 11)),
      ],
    );
  }
}
