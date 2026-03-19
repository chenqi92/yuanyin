import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/theme.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../data/services/settings_service.dart';

/// 设置页
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: YYColors.bgBase,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            floating: true,
            title: const Text('设置',
                style: TextStyle(
                    color: YYColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold)),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 160),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 8),

                // 数据源管理
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('数据源', style: TextStyle(
                          color: YYColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      _SettingsTile(
                        icon: CupertinoIcons.folder,
                        title: '数据源管理',
                        subtitle: '添加、编辑数据源',
                        onTap: () => context.push('/sources'),
                      ),
                    ],
                  ),
                ),

                // 播放设置
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('播放', style: TextStyle(
                          color: YYColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      _SettingsTile(
                        icon: CupertinoIcons.waveform,
                        title: '播放引擎',
                        subtitle: settings.engine == 'justAudio' ? 'just_audio (原生)' : 'media_kit (FFmpeg)',
                        onTap: () => _showEngineSelector(context, ref, settings.engine),
                      ),
                      _divider,
                      _SettingsTile(
                        icon: CupertinoIcons.arrow_2_circlepath,
                        title: '交叉淡化',
                        subtitle: settings.crossfadeDuration > 0
                            ? '${settings.crossfadeDuration.toStringAsFixed(1)} 秒'
                            : '关闭',
                      ),
                      _divider,
                      // 音量滑块
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            const Icon(CupertinoIcons.speaker_2, color: YYColors.accentPrimary, size: 22),
                            const SizedBox(width: 14),
                            const Text('音量', style: TextStyle(color: YYColors.textPrimary, fontSize: 16)),
                            const SizedBox(width: 16),
                            Expanded(
                              child: SliderTheme(
                                data: SliderThemeData(
                                  thumbColor: YYColors.accentPrimary,
                                  activeTrackColor: YYColors.accentPrimary,
                                  inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                  trackHeight: 3,
                                ),
                                child: Slider(
                                  value: settings.volume,
                                  onChanged: (v) => ref.read(settingsProvider.notifier).setVolume(v),
                                ),
                              ),
                            ),
                            Text('${(settings.volume * 100).round()}%',
                                style: const TextStyle(color: YYColors.textTertiary, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 外观
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('外观', style: TextStyle(
                          color: YYColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      _SettingsTile(
                        icon: CupertinoIcons.paintbrush,
                        title: '主题',
                        subtitle: '暗色',
                      ),
                    ],
                  ),
                ),

                // 存储
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('存储与缓存', style: TextStyle(
                          color: YYColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      _SettingsTile(
                        icon: CupertinoIcons.delete,
                        title: '清除缓存',
                        subtitle: '清除音频和图片缓存',
                      ),
                    ],
                  ),
                ),

                // 关于
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(CupertinoIcons.music_note_2, size: 40, color: YYColors.textTertiary),
                        SizedBox(height: 8),
                        Text('猿音', style: TextStyle(color: YYColors.textSecondary, fontSize: 16)),
                        SizedBox(height: 2),
                        Text('v0.1.0', style: TextStyle(color: YYColors.textTertiary, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showEngineSelector(BuildContext context, WidgetRef ref, String current) {
    showModalBottomSheet(
      context: context,
      backgroundColor: YYColors.bgGlassThick,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(CupertinoIcons.checkmark, color: current == 'justAudio' ? YYColors.accentPrimary : Colors.transparent),
              title: const Text('just_audio (原生)', style: TextStyle(color: YYColors.textPrimary)),
              subtitle: const Text('AVFoundation / ExoPlayer', style: TextStyle(color: YYColors.textTertiary, fontSize: 12)),
              onTap: () { ref.read(settingsProvider.notifier).setEngine('justAudio'); Navigator.pop(context); },
            ),
            ListTile(
              leading: Icon(CupertinoIcons.checkmark, color: current == 'mediaKit' ? YYColors.accentPrimary : Colors.transparent),
              title: const Text('media_kit (FFmpeg)', style: TextStyle(color: YYColors.textPrimary)),
              subtitle: const Text('支持更多格式 (DSD/APE/WMA)', style: TextStyle(color: YYColors.textTertiary, fontSize: 12)),
              onTap: () { ref.read(settingsProvider.notifier).setEngine('mediaKit'); Navigator.pop(context); },
            ),
          ],
        ),
      ),
    );
  }

  static const _divider = Divider(
    height: 1, thickness: 0.5, color: Color(0x10FFFFFF), indent: 44,
  );
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _SettingsTile({required this.icon, required this.title, required this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: YYColors.accentPrimary, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: YYColors.textPrimary, fontSize: 16)),
                  Text(subtitle, style: const TextStyle(color: YYColors.textTertiary, fontSize: 12)),
                ],
              ),
            ),
            if (onTap != null) const Icon(CupertinoIcons.chevron_forward, color: YYColors.textTertiary, size: 16),
          ],
        ),
      ),
    );
  }
}
