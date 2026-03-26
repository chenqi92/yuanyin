import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/theme.dart';
import '../../../../shared/widgets/modern_music_ui.dart';
import '../../data/services/equalizer_service.dart';

const _kEqColor = Color(0xFF8B5CF6);

/// 均衡器页面 — MiniMax Liquid Glass 设计
class EqualizerPage extends ConsumerWidget {
  const EqualizerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eq = ref.watch(equalizerProvider);

    return YYScenicBackground(
      accent: _kEqColor,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              YYPageHeader(
                eyebrow: '音频实验室',
                title: '均衡器',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(eq.enabled ? '已启用' : '已关闭', style: TextStyle(color: eq.enabled ? _kEqColor : context.yyTextTertiary, fontSize: 12, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 12),
                    CupertinoSwitch(value: eq.enabled, activeTrackColor: _kEqColor, onChanged: (v) => ref.read(equalizerProvider.notifier).setEnabled(v)),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),

              // Presets
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: EqualizerService.presets.keys.map((name) {
                    final isActive = eq.presetName == name;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: YYPillButton(
                        label: name,
                        onTap: () => ref.read(equalizerProvider.notifier).setPreset(name),
                        primary: isActive,
                        compact: true,
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 32),

              // EQ Sliders
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: YYPanel(
                    thick: true,
                    padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(5, (i) => _EQBandSlider(
                        label: eqBandLabels[i],
                        value: eq.gains[i],
                        enabled: eq.enabled,
                        onChanged: (v) => ref.read(equalizerProvider.notifier).setBandGain(i, v),
                      )),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              YYPillButton(
                label: '重置所有参数',
                icon: CupertinoIcons.refresh,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  ref.read(equalizerProvider.notifier).resetAll();
                },
              ),

              const SizedBox(height: 40),
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

  const _EQBandSlider({required this.label, required this.value, required this.enabled, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          borderRadius: BorderRadius.circular(6),
          tintColor: enabled ? _kEqColor.withValues(alpha: 0.2) : null,
          child: Text('${value.toInt()}dB', style: TextStyle(color: enabled ? _kEqColor : context.yyTextTertiary, fontSize: 10, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 6,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10, elevation: 4),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                activeTrackColor: enabled ? _kEqColor : Colors.white10,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.05),
                thumbColor: enabled ? Colors.white : Colors.white24,
              ),
              child: Slider(value: value, min: -12, max: 12, onChanged: enabled ? onChanged : null),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(label, style: TextStyle(color: enabled ? Colors.white : Colors.white24, fontSize: 12, fontWeight: FontWeight.w800)),
      ],
    );
  }
}
