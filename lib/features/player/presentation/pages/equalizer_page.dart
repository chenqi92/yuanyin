import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/theme.dart';
import '../../../../shared/widgets/modern_music_ui.dart';
import '../../data/services/equalizer_service.dart';

/// 均衡器页面
///
/// 5 段 EQ 滑块 + 预设选择器
class EqualizerPage extends ConsumerWidget {
  const EqualizerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eq = ref.watch(equalizerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: YYScenicBackground(
        accent: YYColors.accentSecondary,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // 顶部标题区域
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Icon(CupertinoIcons.back, color: context.yyTextPrimary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: YYPageHeader(
                        eyebrow: '播放体验',
                        title: '均衡器',
                      ),
                    ),
                    Switch.adaptive(
                      value: eq.enabled,
                      activeColor: YYColors.accentPrimary,
                      onChanged: (v) => ref.read(equalizerProvider.notifier).setEnabled(v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 预设选择器
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: EqualizerService.presets.keys.map((name) {
                    final isActive = eq.presetName == name;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => ref.read(equalizerProvider.notifier).setPreset(name),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isActive ? YYColors.accentPrimary : context.yyBgElevated,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(name, style: TextStyle(
                            color: isActive ? Colors.white : context.yyTextSecondary,
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(5, (i) {
                      return _EQBandSlider(
                        label: eqBandLabels[i],
                        value: eq.gains[i],
                        enabled: eq.enabled,
                        onChanged: (v) => ref.read(equalizerProvider.notifier).setBandGain(i, v),
                      );
                    }),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 重置按钮
              TextButton.icon(
                onPressed: () => ref.read(equalizerProvider.notifier).resetAll(),
                icon: Icon(CupertinoIcons.arrow_counterclockwise, size: 16, color: context.yyTextTertiary),
                label: Text('重置', style: TextStyle(color: context.yyTextTertiary)),
              ),

              const SizedBox(height: 24),
            ],
          ),
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

  const _EQBandSlider({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '${value.toStringAsFixed(1)} dB',
          style: TextStyle(color: enabled ? context.yyTextSecondary : context.yyTextTertiary, fontSize: 11),
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
                activeTrackColor: enabled ? YYColors.accentPrimary : context.yyTextTertiary,
                inactiveTrackColor: context.yyTextTertiary.withValues(alpha: 0.2),
                thumbColor: enabled ? YYColors.accentPrimary : context.yyTextTertiary,
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
        Text(label, style: TextStyle(color: enabled ? context.yyTextPrimary : context.yyTextTertiary, fontSize: 11)),
      ],
    );
  }
}
