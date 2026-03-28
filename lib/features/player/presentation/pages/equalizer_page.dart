import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/theme.dart';
import '../../data/services/equalizer_service.dart';

const _kEqColor = Color(0xFF8B5CF6);

/// Equalizer page -- iOS native style
class EqualizerPage extends ConsumerWidget {
  const EqualizerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eq = ref.watch(equalizerProvider);

    return CupertinoPageScaffold(
      backgroundColor: context.yyBgBase,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: context.yyBgBase.withValues(alpha: 0.9),
        border: Border(
          bottom: BorderSide(color: context.yySeparator, width: 0.5),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          child: Icon(
            CupertinoIcons.chevron_back,
            color: YYColors.accentPrimary,
            size: 22,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        middle: Text(
          '均衡器',
          style: TextStyle(
            color: context.yyTextPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: CupertinoSwitch(
          value: eq.enabled,
          activeTrackColor: _kEqColor,
          onChanged: (v) => ref.read(equalizerProvider.notifier).setEnabled(v),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Preset selector: horizontal scrollable chips
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: EqualizerService.presets.keys.map((name) {
                  final isActive = eq.presetName == name;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () =>
                          ref.read(equalizerProvider.notifier).setPreset(name),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? _kEqColor
                              : (context.isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black.withValues(alpha: 0.05)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          name,
                          style: TextStyle(
                            color: isActive
                                ? Colors.white
                                : context.yyTextSecondary,
                            fontSize: 14,
                            fontWeight: isActive
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 32),

            // 5-band vertical sliders
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 20, 12, 16),
                  decoration: BoxDecoration(
                    color: context.isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(
                      5,
                      (i) => _EQBandSlider(
                        label: eqBandLabels[i],
                        value: eq.gains[i],
                        enabled: eq.enabled,
                        onChanged: (v) => ref
                            .read(equalizerProvider.notifier)
                            .setBandGain(i, v),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Reset button
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: () => ref.read(equalizerProvider.notifier).resetAll(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.arrow_counterclockwise,
                    size: 14,
                    color: context.yyTextTertiary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '重置均衡器',
                    style: TextStyle(
                      color: context.yyTextTertiary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
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
        // Value label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: enabled
                ? _kEqColor.withValues(alpha: 0.12)
                : context.yyTextTertiary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            value.toStringAsFixed(1),
            style: TextStyle(
              color: enabled ? _kEqColor : context.yyTextTertiary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Vertical slider
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 8,
                  elevation: 2,
                ),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                activeTrackColor: enabled ? _kEqColor : context.yyTextTertiary,
                inactiveTrackColor: context.yyTextTertiary.withValues(
                  alpha: 0.15,
                ),
                thumbColor: enabled
                    ? Colors.white
                    : context.yyTextTertiary.withValues(alpha: 0.5),
                overlayColor: _kEqColor.withValues(alpha: 0.1),
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
        const SizedBox(height: 8),
        // Frequency label
        Text(
          label,
          style: TextStyle(
            color: enabled ? context.yyTextPrimary : context.yyTextTertiary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
