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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: YYScenicBackground(
        accent: _kEqColor,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // 顶部标题区域
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: context.isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10)),
                      child: Icon(CupertinoIcons.back, color: context.yyTextPrimary, size: 18))),
                  const SizedBox(width: 12),
                  Expanded(child: YYPageHeader(eyebrow: '播放体验', title: '均衡器')),
                  // 开关
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: eq.enabled ? _kEqColor.withValues(alpha: 0.12) : context.yyTextTertiary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 8, height: 8,
                        decoration: BoxDecoration(
                          color: eq.enabled ? _kEqColor : context.yyTextTertiary,
                          shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(eq.enabled ? '已开启' : '已关闭', style: TextStyle(
                        color: eq.enabled ? _kEqColor : context.yyTextTertiary,
                        fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 4),
                      CupertinoSwitch(value: eq.enabled, activeTrackColor: _kEqColor,
                        onChanged: (v) => ref.read(equalizerProvider.notifier).setEnabled(v)),
                    ])),
                ]),
              ),
              const SizedBox(height: 20),

              // 预设选择器 — Glass 胶囊
              SizedBox(height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: EqualizerService.presets.keys.map((name) {
                    final isActive = eq.presetName == name;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => ref.read(equalizerProvider.notifier).setPreset(name),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: isActive ? LinearGradient(colors: [_kEqColor, _kEqColor.withValues(alpha: 0.8)]) : null,
                            color: isActive ? null : (context.isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)),
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: isActive ? [BoxShadow(color: _kEqColor.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))] : null),
                          child: Text(name, style: TextStyle(
                            color: isActive ? Colors.white : context.yyTextSecondary,
                            fontSize: 13, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500))),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 24),

              // 5 段 EQ 滑块 — Glass 容器
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                        decoration: BoxDecoration(
                          color: context.isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: context.isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.8)),
                          boxShadow: [if (!context.isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, 4))]),
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
                ),
              ),

              const SizedBox(height: 16),

              // 重置按钮
              GestureDetector(
                onTap: () => ref.read(equalizerProvider.notifier).resetAll(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: context.isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(CupertinoIcons.arrow_counterclockwise, size: 14, color: context.yyTextTertiary),
                    const SizedBox(width: 6),
                    Text('重置均衡器', style: TextStyle(color: context.yyTextTertiary, fontSize: 13, fontWeight: FontWeight.w500)),
                  ])),
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
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: enabled ? _kEqColor.withValues(alpha: 0.1) : context.yyTextTertiary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6)),
        child: Text('${value.toStringAsFixed(1)}', style: TextStyle(
          color: enabled ? _kEqColor : context.yyTextTertiary, fontSize: 11, fontWeight: FontWeight.w600))),
      const SizedBox(height: 8),
      Expanded(
        child: RotatedBox(
          quarterTurns: 3,
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8, elevation: 3),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: enabled ? _kEqColor : context.yyTextTertiary,
              inactiveTrackColor: context.yyTextTertiary.withValues(alpha: 0.15),
              thumbColor: enabled ? Colors.white : context.yyTextTertiary.withValues(alpha: 0.5),
              overlayColor: _kEqColor.withValues(alpha: 0.1)),
            child: Slider(value: value, min: -12, max: 12, onChanged: enabled ? onChanged : null),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(label, style: TextStyle(
        color: enabled ? context.yyTextPrimary : context.yyTextTertiary,
        fontSize: 11, fontWeight: FontWeight.w600)),
    ]);
  }
}
