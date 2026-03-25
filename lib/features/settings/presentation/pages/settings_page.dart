import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../app/l10n/strings.dart';
import '../../../../app/theme/theme.dart';
import '../../data/services/settings_service.dart';
import '../../../library/presentation/providers/library_provider.dart';
import '../../../library/data/services/metadata_scraper.dart';
import '../../../player/data/services/sleep_timer_service.dart';

// ═══════════════════════════════════════════════════════════
//  每区图标色 — 差异化色彩系统 (MiniMax Anti-Slop)
// ═══════════════════════════════════════════════════════════




const _kTransitionColor = Color(0xFFF97316); // 橙 — 播放过渡
const _kEngineColor = Color(0xFFEF4444);     // 红
const _kOptionsColor = Color(0xFF10B981);    // 绿
const _kSleepColor = Color(0xFF6366F1);      // 靛
const _kLibraryColor = Color(0xFF0EA5E9);    // 天蓝
const _kScraperColor = Color(0xFFBA478F);    // 紫粉 — 刮削源
const _kAppearColor = Color(0xFFEC4899);     // 粉
const _kStorageColor = Color(0xFF64748B);    // 灰

/// 设置页 — MiniMax Design + my-nas MusicSettingsSheet 融合重设计
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            // ── 标题栏 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
              child: Row(children: [
                Container(width: 48, height: 48,
                  decoration: BoxDecoration(
                    gradient: YYColors.accentGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: YYColors.accentPrimary.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))]),
                  child: const Icon(CupertinoIcons.gear_alt_fill, color: Colors.white, size: 24)),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('设置', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: context.yyTextPrimary, letterSpacing: -0.5)),
                  const SizedBox(height: 2),
                  Text('自定义你的音乐体验', style: TextStyle(fontSize: 13, color: context.yyTextTertiary)),
                ])),
              ]),
            ),

            // ── 曲库管理（顶部） ──
            _GlassSection(title: '曲库管理', icon: CupertinoIcons.music_note_list, iconColor: _kLibraryColor,
              child: Row(children: [
                _ManageCard(
                  icon: CupertinoIcons.folder_fill,
                  title: '数据源',
                  subtitle: '添加和管理',
                  color: _kLibraryColor,
                  onTap: () => context.push('/sources'),
                ),
                const SizedBox(width: 10),
                _ManageCard(
                  icon: CupertinoIcons.wand_rays,
                  title: '刮削源',
                  subtitle: '排序和配置',
                  color: _kScraperColor,
                  onTap: () => context.push('/scraper-sources'),
                ),
              ]),
            ),

            // ── 播放过渡（合并无缝播放 + 淡入淡出） ──
            _GlassSection(
              title: '播放过渡', icon: CupertinoIcons.arrow_right_arrow_left, iconColor: _kTransitionColor,
              subtitle: '控制歌曲切换的衔接方式',
              child: Column(children: [
                _SwitchTile(icon: CupertinoIcons.waveform_path, title: '无缝播放', subtitle: '歌曲之间无间隙过渡',
                  value: settings.gaplessPlayback, color: _kOptionsColor,
                  onChanged: settings.crossfadeDuration > 0 ? null : (v) => ref.read(settingsProvider.notifier).setGapless(v)),
                const SizedBox(height: 10),
                Row(children: [
                  Container(width: 36, height: 36,
                    decoration: BoxDecoration(color: _kTransitionColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                    child: Icon(CupertinoIcons.arrow_right_arrow_left, color: _kTransitionColor, size: 18)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('淡入淡出', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.yyTextPrimary)),
                    Text('歌曲切换时平滑过渡', style: TextStyle(fontSize: 11, color: context.yyTextTertiary)),
                  ])),
                ]),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [0.0, 1.0, 2.0, 3.0, 5.0].map((d) => _Chip(
                  label: d == 0 ? '关闭' : '${d.toStringAsFixed(0)}秒',
                  isSelected: (settings.crossfadeDuration - d).abs() < 0.1,
                  color: _kTransitionColor,
                  onTap: () {
                    ref.read(settingsProvider.notifier).setCrossfade(d);
                    // 互斥：开启淡入淡出时自动关闭无缝播放
                    if (d > 0 && settings.gaplessPlayback) {
                      ref.read(settingsProvider.notifier).setGapless(false);
                    }
                  },
                )).toList()),
                if (settings.crossfadeDuration > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: context.isDark ? 0.12 : 0.08),
                      borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      Icon(CupertinoIcons.info_circle_fill, color: Colors.amber[700], size: 16),
                      const SizedBox(width: 10),
                      Expanded(child: Text(
                        '淡入淡出已启用，无缝播放自动关闭',
                        style: TextStyle(fontSize: 12, color: context.yyTextSecondary))),
                    ])),
                ],
              ]),
            ),

            // ── 播放引擎 ──
            _GlassSection(
              title: '播放引擎', icon: CupertinoIcons.bolt_fill, iconColor: _kEngineColor,
              subtitle: '切换需要重启应用',
              child: Column(children: [
                Row(children: [
                  _EngineCard(CupertinoIcons.device_phone_portrait, '平台原生',
                    '稳定 · 低功耗', settings.engine == 'just_audio', _kEngineColor,
                    () => ref.read(settingsProvider.notifier).setEngine('just_audio')),
                  const SizedBox(width: 10),
                  _EngineCard(CupertinoIcons.waveform, 'FFmpeg',
                    'AC3 · DTS · Dolby', settings.engine == 'media_kit', _kEngineColor,
                    () => ref.read(settingsProvider.notifier).setEngine('media_kit')),
                ]),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: (settings.engine == 'media_kit' ? Colors.amber : _kOptionsColor).withValues(alpha: context.isDark ? 0.12 : 0.08),
                    borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Icon(CupertinoIcons.info_circle_fill,
                      color: settings.engine == 'media_kit' ? Colors.amber[700] : _kOptionsColor, size: 16),
                    const SizedBox(width: 10),
                    Expanded(child: Text(
                      settings.engine == 'media_kit' ? '当前使用 FFmpeg 引擎，支持 AC3、DTS 等高级格式' : '当前使用平台原生引擎，更省电',
                      style: TextStyle(fontSize: 12, color: context.yyTextSecondary))),
                  ])),
                ]),
            ),

            // ── 播放选项 ──
            _GlassSection(title: '播放选项', icon: CupertinoIcons.slider_horizontal_3, iconColor: _kOptionsColor,
              child: _SwitchTile(icon: CupertinoIcons.text_quote, title: '显示歌词', subtitle: '播放页面显示歌词面板',
                value: settings.showLyrics, color: _kOptionsColor,
                onChanged: (v) => ref.read(settingsProvider.notifier).setShowLyrics(v)),
            ),

            // ── 睡眠定时 ──
            _GlassSection(title: '睡眠定时', icon: CupertinoIcons.moon_fill, iconColor: _kSleepColor,
              child: Consumer(builder: (ctx, ref2, _) {
                final timer = ref2.watch(sleepTimerProvider);
                if (timer.isActive) {
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        _kSleepColor.withValues(alpha: 0.15),
                        _kSleepColor.withValues(alpha: 0.05),
                      ]),
                      borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      Icon(CupertinoIcons.moon_stars_fill, size: 20, color: _kSleepColor),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${timer.remaining.inMinutes}分${timer.remaining.inSeconds % 60}秒后停止',
                          style: TextStyle(color: ctx.yyTextPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('音乐将自动暂停', style: TextStyle(color: ctx.yyTextTertiary, fontSize: 12)),
                      ])),
                      GestureDetector(
                        onTap: () => ref2.read(sleepTimerProvider.notifier).cancelTimer(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: YYColors.statusError.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10)),
                          child: Text('取消', style: TextStyle(color: YYColors.statusError, fontSize: 13, fontWeight: FontWeight.w600)))),
                    ]));
                }
                return Wrap(spacing: 8, runSpacing: 8,
                  children: [15, 30, 45, 60, 90].map((m) => _Chip(
                    label: '$m 分钟', isSelected: false, color: _kSleepColor,
                    onTap: () => ref2.read(sleepTimerProvider.notifier).startTimer(Duration(minutes: m)),
                  )).toList());
              }),
            ),

            // ── 外观 ──
            _GlassSection(title: '外观', icon: CupertinoIcons.paintbrush_fill, iconColor: _kAppearColor,
              child: Column(children: [
                // 主题
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: context.isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    Container(width: 36, height: 36,
                      decoration: BoxDecoration(color: _kAppearColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                      child: Icon(CupertinoIcons.sun_max_fill, color: _kAppearColor, size: 18)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('主题', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.yyTextPrimary)),
                      Text('切换浅色或深色模式', style: TextStyle(fontSize: 11, color: context.yyTextTertiary)),
                    ])),
                    _SegmentedToggle(
                      items: const [('自动', 'system'), ('浅色', 'light'), ('深色', 'dark')],
                      current: settings.themeMode, color: _kAppearColor,
                      onChanged: (m) => ref.read(settingsProvider.notifier).setThemeMode(m)),
                  ]),
                ),
                const SizedBox(height: 8),
                // 语言
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: context.isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    Container(width: 36, height: 36,
                      decoration: BoxDecoration(color: _kOptionsColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                      child: Icon(CupertinoIcons.globe, color: _kOptionsColor, size: 18)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('语言', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.yyTextPrimary)),
                      Text('界面显示语言', style: TextStyle(fontSize: 11, color: context.yyTextTertiary)),
                    ])),
                    Consumer(builder: (ctx, ref2, _) {
                      final locale = ref2.watch(localeProvider);
                      return _SegmentedToggle(
                        items: const [('中文', 'zh'), ('EN', 'en')],
                        current: locale?.languageCode ?? 'zh', color: _kOptionsColor,
                        onChanged: (l) => ref2.read(localeProvider.notifier).state = Locale(l));
                    }),
                  ]),
                ),
              ]),
            ),

            // ── 存储 ──
            _GlassSection(title: '存储与数据', icon: CupertinoIcons.tray_fill, iconColor: _kStorageColor,
              child: GestureDetector(
                onTap: () => _showClearCacheDialog(context),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: YYColors.statusError.withValues(alpha: context.isDark ? 0.08 : 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: YYColors.statusError.withValues(alpha: 0.15))),
                  child: Row(children: [
                    Container(width: 36, height: 36,
                      decoration: BoxDecoration(color: YYColors.statusError.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(CupertinoIcons.trash_fill, color: YYColors.statusError, size: 17)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('清除缓存', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.yyTextPrimary)),
                      Text('清除最近播放记录和临时文件', style: TextStyle(fontSize: 11, color: context.yyTextTertiary)),
                    ])),
                    Icon(CupertinoIcons.chevron_right, size: 14, color: YYColors.statusError.withValues(alpha: 0.6)),
                  ]),
                ),
              ),
            ),

            // ── 关于 ──
            const SizedBox(height: 32),
            Center(child: Column(children: [
              Container(width: 56, height: 56,
                decoration: BoxDecoration(
                  gradient: YYColors.accentGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: YYColors.accentPrimary.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))]),
                child: const Icon(CupertinoIcons.music_note_2, color: Colors.white, size: 26)),
              const SizedBox(height: 12),
              Text('猿音 Primuse', style: TextStyle(color: context.yyTextPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: context.isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8)),
                child: Text('v0.1.0', style: TextStyle(color: context.yyTextTertiary, fontSize: 12, fontWeight: FontWeight.w500))),
              const SizedBox(height: 8),
              Text('用心聆听每一首歌', style: TextStyle(color: context.yyTextTertiary, fontSize: 12)),
            ])),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(context: context, useRootNavigator: true, builder: (ctx) => AlertDialog(
      backgroundColor: context.yyBgElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('清除缓存', style: TextStyle(color: context.yyTextPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
      content: Text('将清除最近播放记录和临时文件', style: TextStyle(color: context.yyTextSecondary, fontSize: 14)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消', style: TextStyle(color: context.yyTextTertiary))),
        TextButton(onPressed: () async { Navigator.pop(ctx); await _performClearCache(context); },
          child: const Text('清除', style: TextStyle(color: YYColors.statusError, fontWeight: FontWeight.w600))),
      ],
    ));
  }

  Future<void> _performClearCache(BuildContext context) async {
    try {
      final recentBox = await Hive.openBox('recent_plays');
      await recentBox.clear();
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        for (final entity in tempDir.listSync()) {
          try { await entity.delete(recursive: true); } catch (_) {}
        }
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('缓存已清除'), behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('清除失败: $e'), behavior: SnackBarBehavior.floating));
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════
//  _GlassSection — Liquid Glass 毛玻璃卡片
//  基于 MiniMax frontend-dev SKILL.md 的 Liquid Glass 技术
// ═══════════════════════════════════════════════════════════

class _GlassSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final String? subtitle;
  final Widget child;
  const _GlassSection({required this.title, required this.icon, required this.iconColor, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: context.isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.8)),
              boxShadow: [
                if (!context.isDark) BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 20, offset: const Offset(0, 4)),
              ]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: iconColor, size: 18)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.yyTextPrimary)),
                  if (subtitle != null)
                    Text(subtitle!, style: TextStyle(fontSize: 12, color: context.yyTextTertiary)),
                ])),
              ]),
              const SizedBox(height: 16),
              child,
            ]),
          ),
        ),
      ),
    );
  }
}


// ═══════════════════════════════════════════════════════════
//  _Chip — 胶囊选择器（淡化/睡眠）
// ═══════════════════════════════════════════════════════════

class _Chip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.isSelected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap,
      child: AnimatedContainer(duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected ? LinearGradient(colors: [color, color.withValues(alpha: 0.8)]) : null,
          color: isSelected ? null : (context.isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(22)),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? Colors.white : context.yyTextSecondary)),
      ));
  }
}

// ═══════════════════════════════════════════════════════════
//  _EngineCard — 引擎选择卡片
// ═══════════════════════════════════════════════════════════

class _EngineCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _EngineCard(this.icon, this.title, this.subtitle, this.selected, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Expanded(child: GestureDetector(onTap: onTap,
      child: AnimatedContainer(duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          gradient: selected ? LinearGradient(colors: [color, color.withValues(alpha: 0.8)],
            begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
          color: selected ? null : (context.isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))] : null),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(clipBehavior: Clip.none, children: [
            Icon(icon, color: selected ? Colors.white : context.yyTextSecondary, size: 26),
            if (selected) Positioned(right: -6, top: -6, child: Container(
              width: 16, height: 16,
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4)]),
              child: Icon(CupertinoIcons.checkmark, color: color, size: 10))),
          ]),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
            color: selected ? Colors.white : context.yyTextPrimary)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: selected ? Colors.white.withValues(alpha: 0.2) : context.yyTextTertiary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6)),
            child: Text(subtitle, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500,
              color: selected ? Colors.white.withValues(alpha: 0.9) : context.yyTextTertiary))),
        ]),
      ),
    ));
  }
}

// ═══════════════════════════════════════════════════════════
//  _ManageCard — 曲库管理卡片（与 _EngineCard 风格一致）
// ═══════════════════════════════════════════════════════════

class _ManageCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;
  const _ManageCard({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: GestureDetector(onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.8)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white, size: 26),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(subtitle, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.9))),
              const SizedBox(width: 4),
              Icon(CupertinoIcons.chevron_right, size: 10, color: Colors.white.withValues(alpha: 0.9)),
            ])),
        ]),
      ),
    ));
  }
}

// ═══════════════════════════════════════════════════════════
//  _SwitchTile — 开关行（紧凑无边框）
// ═══════════════════════════════════════════════════════════

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final bool value;
  final Color color;
  final ValueChanged<bool>? onChanged;
  const _SwitchTile({required this.icon, required this.title, required this.subtitle,
    required this.value, required this.color, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.yyTextPrimary)),
          Text(subtitle, style: TextStyle(fontSize: 11, color: context.yyTextTertiary)),
        ])),
        CupertinoSwitch(value: value, onChanged: onChanged, activeTrackColor: color),
      ]),
    );
  }
}



// ═══════════════════════════════════════════════════════════
//  _SegmentedToggle — iOS 分段控件风格切换器
// ═══════════════════════════════════════════════════════════

class _SegmentedToggle extends StatelessWidget {
  final List<(String label, String value)> items;
  final String current;
  final Color color;
  final ValueChanged<String> onChanged;
  const _SegmentedToggle({required this.items, required this.current, required this.color, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min,
        children: items.map((item) {
          final active = current == item.$2;
          return GestureDetector(
            onTap: () => onChanged(item.$2),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: active ? color : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: active ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))] : null),
              child: Text(item.$1, style: TextStyle(
                color: active ? Colors.white : context.yyTextTertiary,
                fontSize: 13, fontWeight: active ? FontWeight.w600 : FontWeight.w400))),
          );
        }).toList()),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  批量刮削对话框
// ═══════════════════════════════════════════════════════════

class _BatchScrapeDialog extends StatefulWidget {
  final WidgetRef ref;
  const _BatchScrapeDialog({required this.ref});
  @override
  State<_BatchScrapeDialog> createState() => _BatchScrapeDialogState();
}

class _BatchScrapeDialogState extends State<_BatchScrapeDialog> {
  // 配置阶段
  bool _configDone = false;
  bool _useMusicBrainz = true;
  // bool _useDiscogs = false;  // 未来支持
  // bool _useLastFm = false;   // 未来支持
  String _sortMode = 'missing'; // missing | name | artist | year
  bool _onlyMissing = true;

  // 执行阶段
  int _total = 0, _current = 0, _updated = 0, _skipped = 0;
  String _currentSong = '';
  bool _done = false, _cancelled = false;

  void _startScrape() {
    setState(() => _configDone = true);
    _run();
  }

  Future<void> _run() async {
    final db = widget.ref.read(musicDatabaseProvider);
    final scraper = MetadataScraper();
    var allSongs = await db.getAllSongs();

    // 排序
    switch (_sortMode) {
      case 'name': allSongs.sort((a, b) => a.title.compareTo(b.title));
      case 'artist': allSongs.sort((a, b) => a.artist.compareTo(b.artist));
      case 'year': allSongs.sort((a, b) => (a.year ?? 9999).compareTo(b.year ?? 9999));
      case 'missing': allSongs.sort((a, b) {
        final aMissing = _missingScore(a);
        final bMissing = _missingScore(b);
        return bMissing.compareTo(aMissing);
      });
    }

    setState(() => _total = allSongs.length);

    for (int i = 0; i < allSongs.length; i++) {
      if (_cancelled) break;
      final song = allSongs[i];

      // 仅处理缺失元数据
      if (_onlyMissing && _missingScore(song) == 0) {
        setState(() { _current = i + 1; _skipped++; });
        continue;
      }

      setState(() { _current = i + 1; _currentSong = song.title; });
      try {
        if (_useMusicBrainz) {
          final enriched = await scraper.scrape(song);
          if (enriched != null) { await db.updateSong(enriched); setState(() => _updated++); }
        }
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 1100));
    }
    setState(() => _done = true);
    widget.ref.read(libraryProvider.notifier).refresh();
  }

  int _missingScore(dynamic song) {
    int score = 0;
    if (song.genre == null || song.genre == '未知') score++;
    if (song.year == null || song.year == 0) score++;
    if (song.album == '未知专辑') score++;
    if (song.coverUrl == null || song.coverUrl!.isEmpty) score++;
    return score;
  }

  @override
  Widget build(BuildContext context) {
    if (!_configDone) return _buildConfig(context);
    return _buildProgress(context);
  }

  Widget _buildConfig(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.yyBgElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        Container(width: 32, height: 32,
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFEF4444)]),
            borderRadius: BorderRadius.circular(8)),
          child: const Icon(CupertinoIcons.tag_fill, color: Colors.white, size: 16)),
        const SizedBox(width: 10),
        Text('元数据刮削', style: TextStyle(color: context.yyTextPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
      ]),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 平台选择
        Text('数据源', style: TextStyle(color: context.yyTextSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _ConfigSwitch(icon: CupertinoIcons.globe, title: 'MusicBrainz', subtitle: '开源音乐数据库',
          value: _useMusicBrainz, color: const Color(0xFFF97316),
          onChanged: (v) => setState(() => _useMusicBrainz = v)),
        _ConfigSwitch(icon: CupertinoIcons.music_albums, title: 'Discogs', subtitle: '即将支持',
          value: false, color: const Color(0xFF64748B), onChanged: null),
        _ConfigSwitch(icon: CupertinoIcons.radiowaves_left, title: 'Last.fm', subtitle: '即将支持',
          value: false, color: const Color(0xFF64748B), onChanged: null),

        const SizedBox(height: 16),

        // 排序方式
        Text('排序方式', style: TextStyle(color: context.yyTextSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          _SortChip('缺失优先', 'missing', _sortMode, const Color(0xFFEF4444), (v) => setState(() => _sortMode = v)),
          _SortChip('按名称', 'name', _sortMode, const Color(0xFF3B82F6), (v) => setState(() => _sortMode = v)),
          _SortChip('按艺术家', 'artist', _sortMode, const Color(0xFF8B5CF6), (v) => setState(() => _sortMode = v)),
          _SortChip('按年份', 'year', _sortMode, const Color(0xFF10B981), (v) => setState(() => _sortMode = v)),
        ]),

        const SizedBox(height: 16),

        // 仅缺失
        _ConfigSwitch(icon: CupertinoIcons.sparkles, title: '仅处理缺失', subtitle: '跳过已有完整元数据的歌曲',
          value: _onlyMissing, color: const Color(0xFF10B981),
          onChanged: (v) => setState(() => _onlyMissing = v)),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
          child: Text('取消', style: TextStyle(color: context.yyTextTertiary))),
        TextButton(onPressed: _useMusicBrainz ? _startScrape : null,
          child: Text('开始刮削', style: TextStyle(
            color: _useMusicBrainz ? YYColors.accentPrimary : context.yyTextTertiary,
            fontWeight: FontWeight.w600))),
      ]);
  }

  Widget _buildProgress(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.yyBgElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(_done ? '刮削完成' : '正在刮削...', style: TextStyle(color: context.yyTextPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!_done) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: _total > 0 ? _current / _total : null,
              color: YYColors.accentPrimary, minHeight: 6,
              backgroundColor: context.yyTextTertiary.withValues(alpha: 0.12))),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: Text('$_current / $_total', style: TextStyle(color: context.yyTextPrimary, fontSize: 15, fontWeight: FontWeight.w600))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _kOptionsColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
              child: Text('更新 $_updated', style: TextStyle(color: _kOptionsColor, fontSize: 11, fontWeight: FontWeight.w600))),
            if (_skipped > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: context.yyTextTertiary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text('跳过 $_skipped', style: TextStyle(color: context.yyTextTertiary, fontSize: 11, fontWeight: FontWeight.w600))),
            ],
          ]),
          const SizedBox(height: 6),
          Text(_currentSong, style: TextStyle(color: context.yyTextTertiary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
        ] else
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(CupertinoIcons.checkmark_circle_fill, color: _kOptionsColor, size: 20),
              const SizedBox(width: 8),
              Text('更新 $_updated / $_total 首', style: TextStyle(color: context.yyTextPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
            ]),
            if (_skipped > 0) ...[
              const SizedBox(height: 8),
              Text('跳过 $_skipped 首（元数据完整）', style: TextStyle(color: context.yyTextTertiary, fontSize: 13)),
            ],
          ]),
      ]),
      actions: [
        if (!_done) TextButton(onPressed: () { _cancelled = true; Navigator.pop(context); },
          child: Text('取消', style: TextStyle(color: context.yyTextTertiary))),
        if (_done) TextButton(onPressed: () => Navigator.pop(context),
          child: const Text('完成', style: TextStyle(color: YYColors.accentPrimary, fontWeight: FontWeight.w600))),
      ]);
  }
}

// 配置项开关
class _ConfigSwitch extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final bool value;
  final Color color;
  final ValueChanged<bool>? onChanged;
  const _ConfigSwitch({required this.icon, required this.title, required this.subtitle,
    required this.value, required this.color, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return Padding(padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Container(width: 28, height: 28,
          decoration: BoxDecoration(color: color.withValues(alpha: enabled ? 0.12 : 0.06), borderRadius: BorderRadius.circular(7)),
          child: Icon(icon, color: enabled ? color : context.yyTextTertiary, size: 14)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
            color: enabled ? context.yyTextPrimary : context.yyTextTertiary)),
          Text(subtitle, style: TextStyle(fontSize: 10, color: context.yyTextTertiary)),
        ])),
        SizedBox(height: 28, child: CupertinoSwitch(value: value, onChanged: onChanged,
          activeTrackColor: color)),
      ]));
  }
}

// 排序胶囊
class _SortChip extends StatelessWidget {
  final String label, value, current;
  final Color color;
  final ValueChanged<String> onChanged;
  const _SortChip(this.label, this.value, this.current, this.color, this.onChanged);

  @override
  Widget build(BuildContext context) {
    final active = current == value;
    return GestureDetector(onTap: () => onChanged(value),
      child: AnimatedContainer(duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          gradient: active ? LinearGradient(colors: [color, color.withValues(alpha: 0.8)]) : null,
          color: active ? null : (context.isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(16),
          boxShadow: active ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))] : null),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: active ? FontWeight.w600 : FontWeight.w500,
          color: active ? Colors.white : context.yyTextSecondary))));
  }
}

