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
import '../../../library/data/services/music_database_service.dart';
import '../../../player/data/services/sleep_timer_service.dart';

/// 设置页 — 参照 my-nas MusicSettingsSheet 的 _SettingsSection 卡片风格
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
            // 标题栏（参照 my-nas _buildHeader）
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
              child: Row(children: [
                Container(width: 44, height: 44,
                  decoration: BoxDecoration(
                    gradient: YYColors.accentGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: YYColors.accentPrimary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))]),
                  child: const Icon(CupertinoIcons.gear, color: Colors.white, size: 24)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('设置', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.yyTextPrimary, letterSpacing: -0.5)),
                  const SizedBox(height: 2),
                  Text('自定义你的音乐体验', style: TextStyle(fontSize: 13, color: context.yyTextTertiary)),
                ])),
              ]),
            ),

            // ── 播放模式 ──
            _SettingsSection(
              title: '播放模式', icon: CupertinoIcons.repeat, subtitle: null,
              child: Row(children: [
                _ModeBtn(CupertinoIcons.repeat, '列表循环', settings.playMode == 'loop', () => ref.read(settingsProvider.notifier).setPlayMode('loop')),
                const SizedBox(width: 12),
                _ModeBtn(CupertinoIcons.repeat_1, '单曲循环', settings.playMode == 'repeat_one', () => ref.read(settingsProvider.notifier).setPlayMode('repeat_one')),
                const SizedBox(width: 12),
                _ModeBtn(CupertinoIcons.shuffle, '随机播放', settings.playMode == 'shuffle', () => ref.read(settingsProvider.notifier).setPlayMode('shuffle')),
              ]),
            ),

            // ── 交叉淡化 ──
            _SettingsSection(
              title: '歌曲切换淡入淡出', icon: CupertinoIcons.arrow_right_arrow_left, subtitle: '歌曲切换时平滑过渡',
              child: Wrap(spacing: 10, runSpacing: 10, children: [0.0, 1.0, 2.0, 3.0, 5.0].map((d) => _DurationChip(
                label: d == 0 ? '关闭' : '${d.toStringAsFixed(0)}秒',
                isSelected: (settings.crossfadeDuration - d).abs() < 0.1,
                onTap: () => ref.read(settingsProvider.notifier).setCrossfade(d),
              )).toList()),
            ),

            // ── 播放引擎 ──
            _SettingsSection(
              title: '播放引擎', icon: CupertinoIcons.bolt, subtitle: '切换需要重启应用',
              child: Column(children: [
                Row(children: [
                  _EngineBtn(CupertinoIcons.phone, '平台原生', '稳定 / 低功耗', settings.engine == 'just_audio',
                    () => ref.read(settingsProvider.notifier).setEngine('just_audio')),
                  const SizedBox(width: 12),
                  _EngineBtn(CupertinoIcons.waveform, 'FFmpeg', 'AC3 / DTS / Dolby', settings.engine == 'media_kit',
                    () => ref.read(settingsProvider.notifier).setEngine('media_kit')),
                ]),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: context.isDark ? 0.15 : 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3))),
                  child: Row(children: [
                    Icon(CupertinoIcons.info, color: Colors.amber[700], size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(
                      settings.engine == 'media_kit' ? '当前使用 FFmpeg 引擎，支持 AC3、DTS 等高级格式' : '当前使用平台原生引擎，更省电',
                      style: TextStyle(fontSize: 12, color: context.isDark ? Colors.amber[300] : Colors.amber[800]))),
                  ])),
              ]),
            ),

            // ── 开关选项 ──
            _SettingsSection(title: '播放选项', icon: CupertinoIcons.slider_horizontal_3, subtitle: null,
              child: Column(children: [
                _SwitchRow(icon: CupertinoIcons.waveform_path, title: '无缝播放', subtitle: '播放列表歌曲之间无间隙',
                  value: settings.gaplessPlayback, onChanged: (v) => ref.read(settingsProvider.notifier).setGapless(v)),
                const SizedBox(height: 12),
                _SwitchRow(icon: CupertinoIcons.text_quote, title: '显示歌词', subtitle: '播放页面显示歌词',
                  value: settings.showLyrics, onChanged: (v) => ref.read(settingsProvider.notifier).setShowLyrics(v)),
              ]),
            ),

            // ── 睡眠定时 ──
            _SettingsSection(title: '睡眠定时', icon: CupertinoIcons.moon, subtitle: null,
              child: Consumer(builder: (ctx, ref2, _) {
                final timer = ref2.watch(sleepTimerProvider);
                if (timer.isActive) {
                  return Row(children: [
                    Icon(CupertinoIcons.moon_fill, size: 18, color: YYColors.accentPrimary),
                    const SizedBox(width: 10),
                    Expanded(child: Text('${timer.remaining.inMinutes}分${timer.remaining.inSeconds % 60}秒后停止',
                      style: TextStyle(color: ctx.yyTextPrimary, fontSize: 14, fontWeight: FontWeight.w600))),
                    GestureDetector(
                      onTap: () => ref2.read(sleepTimerProvider.notifier).cancelTimer(),
                      child: Text('取消', style: TextStyle(color: YYColors.statusError, fontSize: 14, fontWeight: FontWeight.w600))),
                  ]);
                }
                return Wrap(spacing: 10, runSpacing: 10,
                  children: [15, 30, 45, 60, 90].map((m) => _DurationChip(
                    label: '${m}分钟', isSelected: false,
                    onTap: () => ref2.read(sleepTimerProvider.notifier).startTimer(Duration(minutes: m)),
                  )).toList());
              }),
            ),

            // ── 曲库管理 ──
            _SettingsSection(title: '曲库管理', icon: CupertinoIcons.music_note_list, subtitle: null,
              child: Column(children: [
                _ActionRow(icon: CupertinoIcons.folder, title: '数据源管理', color: YYColors.accentPrimary,
                  onTap: () => context.push('/sources')),
                _ActionRow(icon: CupertinoIcons.arrow_2_circlepath, title: '重新扫描', color: const Color(0xFF10B981),
                  onTap: () { ref.read(libraryProvider.notifier).refresh();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('正在扫描...'), behavior: SnackBarBehavior.floating)); }),
                _ActionRow(icon: CupertinoIcons.tag, title: '元数据刮削', color: const Color(0xFFF59E0B),
                  onTap: () => showDialog(context: context, useRootNavigator: true, barrierDismissible: false,
                    builder: (_) => _BatchScrapeDialog(ref: ref))),
                _ActionRow(icon: CupertinoIcons.slider_horizontal_3, title: '均衡器', color: const Color(0xFF06B6D4),
                  onTap: () => context.push('/equalizer')),
              ]),
            ),

            // ── 外观 ──
            _SettingsSection(title: '外观', icon: CupertinoIcons.paintbrush, subtitle: null,
              child: Column(children: [
                Row(children: [
                  Icon(CupertinoIcons.paintbrush, color: YYColors.accentPrimary, size: 18),
                  const SizedBox(width: 10),
                  Text('主题', style: TextStyle(color: context.yyTextPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  _ThemeToggle(current: settings.themeMode,
                    onChanged: (m) => ref.read(settingsProvider.notifier).setThemeMode(m)),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Icon(CupertinoIcons.globe, color: const Color(0xFF10B981), size: 18),
                  const SizedBox(width: 10),
                  Text('语言', style: TextStyle(color: context.yyTextPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Consumer(builder: (ctx, ref2, _) {
                    final locale = ref2.watch(localeProvider);
                    return _LangToggle(current: locale?.languageCode ?? 'zh',
                      onChanged: (l) => ref2.read(localeProvider.notifier).state = Locale(l));
                  }),
                ]),
              ]),
            ),

            // ── 存储 ──
            _SettingsSection(title: '存储', icon: CupertinoIcons.tray, subtitle: null,
              child: _ActionRow(icon: CupertinoIcons.delete, title: '清除缓存', color: YYColors.statusError,
                onTap: () => _showClearCacheDialog(context)),
            ),

            // 关于
            const SizedBox(height: 24),
            Center(child: Column(children: [
              Container(width: 44, height: 44,
                decoration: BoxDecoration(gradient: YYColors.accentGradient, borderRadius: BorderRadius.circular(12)),
                child: const Icon(CupertinoIcons.music_note_2, color: Colors.white, size: 22)),
              const SizedBox(height: 8),
              Text('猿音 Primuse', style: TextStyle(color: context.yyTextSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
              Text('v0.1.0', style: TextStyle(color: context.yyTextTertiary, fontSize: 11)),
            ])),
          ],
        ),
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(context: context, useRootNavigator: true, builder: (ctx) => AlertDialog(
      backgroundColor: context.yyBgElevated,
      title: Text('清除缓存', style: TextStyle(color: context.yyTextPrimary)),
      content: Text('将清除最近播放记录和临时文件', style: TextStyle(color: context.yyTextSecondary, fontSize: 14)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消', style: TextStyle(color: context.yyTextTertiary))),
        TextButton(onPressed: () async { Navigator.pop(ctx); await _performClearCache(context); },
          child: const Text('清除', style: TextStyle(color: YYColors.statusError))),
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
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('缓存已清除'), behavior: SnackBarBehavior.floating));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('清除失败: $e'), behavior: SnackBarBehavior.floating));
    }
  }
}

// ═══════════════════════════════════════════════════════════
//  _SettingsSection — 参照 my-nas 的卡片分区
// ═══════════════════════════════════════════════════════════

class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? subtitle;
  final Widget child;
  const _SettingsSection({required this.title, required this.icon, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 32, height: 32,
              decoration: BoxDecoration(color: YYColors.accentPrimary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: YYColors.accentPrimary, size: 18)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.yyTextPrimary)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: TextStyle(fontSize: 12, color: context.yyTextTertiary)),
              ],
            ])),
          ]),
          const SizedBox(height: 16),
          child,
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  播放模式按钮（参照 my-nas _PlayModeButton）
// ═══════════════════════════════════════════════════════════

class _ModeBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ModeBtn(this.icon, this.label, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Expanded(child: GestureDetector(onTap: onTap,
      child: AnimatedContainer(duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? YYColors.accentPrimary
            : (context.isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(12),
          border: selected ? null : Border.all(
            color: context.isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08)),
          boxShadow: selected ? [BoxShadow(color: YYColors.accentPrimary.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))] : null),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: selected ? Colors.white : context.yyTextSecondary, size: 22),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
            color: selected ? Colors.white : context.yyTextSecondary)),
        ]),
      ),
    ));
  }
}

// ═══════════════════════════════════════════════════════════
//  时长选择胶囊（参照 my-nas _DurationChip）
// ═══════════════════════════════════════════════════════════

class _DurationChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _DurationChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap,
      child: AnimatedContainer(duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? YYColors.accentPrimary
            : (context.isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? null : Border.all(
            color: context.isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08))),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
          color: isSelected ? Colors.white : context.yyTextSecondary)),
      ));
  }
}

// ═══════════════════════════════════════════════════════════
//  引擎选择按钮（参照 my-nas _EngineButton）
// ═══════════════════════════════════════════════════════════

class _EngineBtn extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _EngineBtn(this.icon, this.title, this.subtitle, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Expanded(child: GestureDetector(onTap: onTap,
      child: AnimatedContainer(duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? YYColors.accentPrimary
            : (context.isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(12),
          border: selected ? null : Border.all(
            color: context.isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08)),
          boxShadow: selected ? [BoxShadow(color: YYColors.accentPrimary.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))] : null),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: selected ? Colors.white : context.yyTextSecondary, size: 22),
          const SizedBox(height: 6),
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
            color: selected ? Colors.white : context.yyTextPrimary)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 10,
            color: selected ? Colors.white.withValues(alpha: 0.8) : context.yyTextTertiary)),
        ]),
      ),
    ));
  }
}

// ═══════════════════════════════════════════════════════════
//  开关行（参照 my-nas _SettingsSwitch）
// ═══════════════════════════════════════════════════════════

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow({required this.icon, required this.title, required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05))),
      child: Row(children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(color: YYColors.accentPrimary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: YYColors.accentPrimary, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.yyTextPrimary)),
          Text(subtitle, style: TextStyle(fontSize: 11, color: context.yyTextTertiary)),
        ])),
        CupertinoSwitch(value: value, onChanged: onChanged, activeTrackColor: YYColors.accentPrimary),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  操作行
// ═══════════════════════════════════════════════════════════

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;
  const _ActionRow({required this.icon, required this.title, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque,
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Container(width: 32, height: 32,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 16)),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.yyTextPrimary))),
          Icon(CupertinoIcons.chevron_right, size: 14, color: context.yyTextTertiary),
        ])),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  主题/语言切换
// ═══════════════════════════════════════════════════════════

class _ThemeToggle extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;
  const _ThemeToggle({required this.current, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: context.yyBgSurface, borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [_c('自动', 'system', context), _c('浅', 'light', context), _c('暗', 'dark', context)]));
  }
  Widget _c(String label, String mode, BuildContext context) {
    final active = current == mode;
    return GestureDetector(onTap: () => onChanged(mode),
      child: AnimatedContainer(duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: active ? YYColors.accentPrimary : Colors.transparent, borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: TextStyle(color: active ? Colors.white : context.yyTextTertiary, fontSize: 12, fontWeight: active ? FontWeight.w600 : FontWeight.w400))));
  }
}

class _LangToggle extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;
  const _LangToggle({required this.current, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: context.yyBgSurface, borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [_c('中文', 'zh', context), _c('EN', 'en', context)]));
  }
  Widget _c(String label, String lang, BuildContext context) {
    final active = current == lang;
    return GestureDetector(onTap: () => onChanged(lang),
      child: AnimatedContainer(duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: active ? YYColors.accentPrimary : Colors.transparent, borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: TextStyle(color: active ? Colors.white : context.yyTextTertiary, fontSize: 12, fontWeight: active ? FontWeight.w600 : FontWeight.w400))));
  }
}

// ─── 批量刮削对话框 ───
class _BatchScrapeDialog extends StatefulWidget {
  final WidgetRef ref;
  const _BatchScrapeDialog({required this.ref});
  @override
  State<_BatchScrapeDialog> createState() => _BatchScrapeDialogState();
}

class _BatchScrapeDialogState extends State<_BatchScrapeDialog> {
  int _total = 0, _current = 0, _updated = 0;
  String _currentSong = '';
  bool _done = false, _cancelled = false;
  @override
  void initState() { super.initState(); _run(); }
  Future<void> _run() async {
    final db = widget.ref.read(musicDatabaseProvider);
    final scraper = MetadataScraper();
    final allSongs = await db.getAllSongs();
    setState(() => _total = allSongs.length);
    for (int i = 0; i < allSongs.length; i++) {
      if (_cancelled) break;
      setState(() { _current = i + 1; _currentSong = allSongs[i].title; });
      try {
        final enriched = await scraper.scrape(allSongs[i]);
        if (enriched != null) { await db.updateSong(enriched); setState(() => _updated++); }
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 1100));
    }
    setState(() => _done = true);
    widget.ref.read(libraryProvider.notifier).refresh();
  }
  @override
  Widget build(BuildContext context) {
    return AlertDialog(backgroundColor: context.yyBgElevated,
      title: Text(_done ? '刮削完成' : '正在刮削...', style: TextStyle(color: context.yyTextPrimary, fontSize: 17)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!_done) ...[
          LinearProgressIndicator(value: _total > 0 ? _current / _total : null, color: YYColors.accentPrimary,
            backgroundColor: context.yyTextTertiary.withValues(alpha: 0.15)),
          const SizedBox(height: 12),
          Text('$_current / $_total', style: TextStyle(color: context.yyTextPrimary, fontSize: 14)),
          Text(_currentSong, style: TextStyle(color: context.yyTextTertiary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
        ] else Text('更新 $_updated / $_total 首', style: TextStyle(color: context.yyTextPrimary, fontSize: 14)),
      ]),
      actions: [
        if (!_done) TextButton(onPressed: () { _cancelled = true; Navigator.pop(context); },
          child: Text('取消', style: TextStyle(color: context.yyTextTertiary))),
        if (_done) TextButton(onPressed: () => Navigator.pop(context),
          child: const Text('完成', style: TextStyle(color: YYColors.accentPrimary))),
      ]);
  }
}
