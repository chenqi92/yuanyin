import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../app/theme/theme.dart';
import '../../../../shared/widgets/modern_music_ui.dart';
import '../../data/services/settings_service.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: YYPageHeader(eyebrow: '系统与播放', title: '设置'),
            ),
            const SliverToBoxAdapter(child: YYSectionTitle(title: '媒体源')),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: YYLiquidGlass(
                  thin: true,
                  radius: 28,
                  padding: EdgeInsets.zero,
                  color: context.isDark
                      ? context.yyBgElevated.withValues(alpha: 0.80)
                      : Colors.white.withValues(alpha: 0.72),
                  child: Column(
                    children: [
                      _SettingsNavRow(
                        icon: CupertinoIcons.link_circle_fill,
                        color: YYColors.accentPrimary,
                        title: '数据源管理',
                        onTap: () => context.push('/sources'),
                      ),
                      _separator(context),
                      _SettingsNavRow(
                        icon: CupertinoIcons.sparkles,
                        color: YYColors.accentSecondary,
                        title: '刮削源管理',
                        onTap: () => context.push('/scraper-sources'),
                        isLast: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: YYSectionTitle(title: '播放')),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: YYLiquidGlass(
                  thin: true,
                  radius: 28,
                  padding: EdgeInsets.zero,
                  color: context.isDark
                      ? context.yyBgElevated.withValues(alpha: 0.80)
                      : Colors.white.withValues(alpha: 0.72),
                  child: Column(
                    children: [
                      _SettingsSwitchRow(
                        icon: CupertinoIcons.waveform_path,
                        color: YYColors.accentSecondary,
                        title: '无缝播放',
                        value: settings.gaplessPlayback,
                        onChanged: settings.crossfadeDuration > 0
                            ? null
                            : (value) => ref
                                  .read(settingsProvider.notifier)
                                  .setGapless(value),
                      ),
                      _separator(context),
                      _SettingsSwitchRow(
                        icon: CupertinoIcons.arrow_2_circlepath,
                        color: YYColors.accentPrimary,
                        title: '交叉淡化',
                        value: settings.crossfadeDuration > 0,
                        onChanged: (value) {
                          if (value) {
                            ref
                                .read(settingsProvider.notifier)
                                .setCrossfade(2.0);
                            if (settings.gaplessPlayback) {
                              ref
                                  .read(settingsProvider.notifier)
                                  .setGapless(false);
                            }
                          } else {
                            ref
                                .read(settingsProvider.notifier)
                                .setCrossfade(0.0);
                          }
                        },
                      ),
                      if (settings.crossfadeDuration > 0) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [1.0, 2.0, 3.0, 5.0]
                                  .map(
                                    (duration) => _DurationOption(
                                      label: '${duration.toStringAsFixed(0)}s',
                                      selected:
                                          (settings.crossfadeDuration -
                                                  duration)
                                              .abs() <
                                          0.1,
                                      onTap: () => ref
                                          .read(settingsProvider.notifier)
                                          .setCrossfade(duration),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ),
                      ],
                      _separator(context),
                      _EngineRow(
                        currentEngine: settings.engine,
                        onChanged: (engine) => ref
                            .read(settingsProvider.notifier)
                            .setEngine(engine),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: YYSectionTitle(title: '显示与音效')),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: YYLiquidGlass(
                  thin: true,
                  radius: 28,
                  padding: EdgeInsets.zero,
                  color: context.isDark
                      ? context.yyBgElevated.withValues(alpha: 0.80)
                      : Colors.white.withValues(alpha: 0.72),
                  child: Column(
                    children: [
                      _SettingsNavRow(
                        icon: CupertinoIcons.slider_horizontal_3,
                        color: YYColors.accentTertiary,
                        title: '均衡器',
                        onTap: () => context.push('/equalizer'),
                      ),
                      _separator(context),
                      _SettingsSwitchRow(
                        icon: CupertinoIcons.quote_bubble_fill,
                        color: YYColors.heartRed,
                        title: '歌词',
                        value: settings.showLyrics,
                        onChanged: (value) => ref
                            .read(settingsProvider.notifier)
                            .setShowLyrics(value),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: YYSectionTitle(title: '关于')),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: YYLiquidGlass(
                  thin: true,
                  radius: 28,
                  padding: EdgeInsets.zero,
                  color: context.isDark
                      ? context.yyBgElevated.withValues(alpha: 0.80)
                      : Colors.white.withValues(alpha: 0.72),
                  child: Column(
                    children: [
                      _SettingsInfoRow(
                        icon: CupertinoIcons.info_circle_fill,
                        color: YYColors.accentTertiary,
                        title: '版本号',
                        value: 'v0.1.0',
                      ),
                      _separator(context),
                      _SettingsNavRow(
                        icon: CupertinoIcons.delete_solid,
                        color: YYColors.statusError,
                        title: '清除缓存',
                        onTap: () => _showClearCacheDialog(context),
                        destructive: true,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: YYSizes.bottomInset(context)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _separator(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 72),
      child: Container(height: 0.5, color: context.yySeparator),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('清除缓存'),
        content: const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('这会清除最近播放记录和临时文件，不会删除你的音乐源配置。'),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              await _performClearCache(context);
            },
            child: const Text('清除'),
          ),
        ],
      ),
    );
  }

  Future<void> _performClearCache(BuildContext context) async {
    try {
      final recentBox = await Hive.openBox('recent_plays');
      await recentBox.clear();
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        for (final entity in tempDir.listSync()) {
          try {
            await entity.delete(recursive: true);
          } catch (_) {}
        }
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('缓存已清除'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('清除失败: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _SettingsNavRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final VoidCallback onTap;
  final bool isLast;
  final bool destructive;

  const _SettingsNavRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
    this.isLast = false,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(26))
            : BorderRadius.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              YYIconBadge(icon: icon, color: color, size: 40),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: destructive
                        ? CupertinoColors.destructiveRed.resolveFrom(context)
                        : context.yyTextPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                CupertinoIcons.chevron_right,
                size: 15,
                color: context.yyTextTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSwitchRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _SettingsSwitchRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          YYIconBadge(icon: icon, color: color, size: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: context.yyTextPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: YYColors.accentPrimary,
          ),
        ],
      ),
    );
  }
}

class _SettingsInfoRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String value;

  const _SettingsInfoRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          YYIconBadge(icon: icon, color: color, size: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: context.yyTextPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: context.yyTextTertiary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DurationOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DurationOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: selected
              ? YYColors.accentPrimary
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(YYRadius.full),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(YYRadius.full),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : context.yyTextSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EngineRow extends StatelessWidget {
  final String currentEngine;
  final ValueChanged<String> onChanged;

  const _EngineRow({required this.currentEngine, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const YYIconBadge(
            icon: CupertinoIcons.hifispeaker_fill,
            color: YYColors.accentTertiary,
            size: 40,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '解码方式',
                  style: TextStyle(
                    color: context.yyTextPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _EngineOption(
                          label: '原生',
                          selected: currentEngine == 'just_audio',
                          onTap: () => onChanged('just_audio'),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _EngineOption(
                          label: 'FFmpeg',
                          selected: currentEngine == 'media_kit',
                          onTap: () => onChanged('media_kit'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EngineOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _EngineOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: selected ? YYColors.accentGradient : null,
          color: selected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : context.yyTextSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
