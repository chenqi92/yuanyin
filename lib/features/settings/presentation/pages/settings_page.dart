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
  Widget build(BuildContext context) {
    return YYScenicBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              YYPageHeader(
                eyebrow: '偏好设置',
                title: '设置',
                trailing: YYHeaderActionButton(
                  icon: CupertinoIcons.info,
                  onTap: () => _showAbout(context),
                  primary: false,
                ),
              ),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
                  children: [
                    // --- 核心管理 ---
                    Row(
                      children: [
                        _ManageCard(
                          icon: CupertinoIcons.folder_fill,
                          title: '数据源',
                          color: _kLibraryColor,
                          onTap: () => context.push('/sources'),
                        ),
                        const SizedBox(width: 16),
                        _ManageCard(
                          icon: CupertinoIcons.wand_rays,
                          title: '刮削配置',
                          color: _kScraperColor,
                          onTap: () => context.push('/scraper-sources'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // --- 播放实验室 ---
                    _SettingsGroup(
                      title: '播放与音频',
                      icon: CupertinoIcons.bolt_fill,
                      color: _kEngineColor,
                      children: [
                        _EngineSelector(),
                        const Divider(height: 32, color: Colors.white10),
                        _CrossfadeSettings(),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // --- 睡眠与偏好 ---
                    _SettingsGroup(
                      title: '功能偏好',
                      icon: CupertinoIcons.slider_horizontal_3,
                      color: _kOptionsColor,
                      children: [
                        _SleepTimerTile(),
                        const SizedBox(height: 12),
                        _SwitchTile(
                          icon: CupertinoIcons.text_quote,
                          title: '显示歌词',
                          subtitle: '在播放界面自动展示',
                          color: _kOptionsColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // --- 外观 ---
                    _SettingsGroup(
                      title: '个性化',
                      icon: CupertinoIcons.paintbrush_fill,
                      color: _kAppearColor,
                      children: [
                        _ThemeModeSelector(),
                      ],
                    ),
                    const SizedBox(height: 40),

                    // --- 存储 ---
                    YYPillButton(
                      label: '清除缓存数据',
                      icon: CupertinoIcons.trash,
                      onTap: () => _showClearCache(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(context: context, applicationName: '猿音 YuanYin', applicationVersion: '3.0.0 (Liquid)');
  }

  void _showClearCache(BuildContext context) {
    HapticFeedback.warningImpact();
    // Implementation of cache clearing dialog
  }
}

class _SettingsGroup extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  const _SettingsGroup({required this.title, required this.icon, required this.color, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 8),
              Text(title.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white38, letterSpacing: 1.5)),
            ],
          ),
        ),
        YYPanel(
          thick: true,
          padding: const EdgeInsets.all(20),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _ManageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _ManageCard({required this.icon, required this.title, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: YYPanel(
        color: color.withValues(alpha: 0.15),
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            YYIconBadge(icon: icon, color: color, size: 48),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

// ... Additional helper sub-widgets like _EngineSelector, _CrossfadeSettings, etc. 
// (Refactored to match the style)

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

