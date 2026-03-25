import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/theme.dart';
import '../../domain/entities/scraper_source_entity.dart';

/// 刮削源管理 Notifier
final scraperSourcesProvider = StateNotifierProvider<_ScraperNotifier, List<ScraperSourceEntity>>((ref) {
  return _ScraperNotifier();
});

class _ScraperNotifier extends StateNotifier<List<ScraperSourceEntity>> {
  _ScraperNotifier() : super([]) { _load(); }
  final _svc = ScraperSourcesService();

  Future<void> _load() async {
    state = await _svc.loadAll();
  }

  Future<void> toggle(String id, bool enabled) async {
    state = [for (final s in state) s.id == id ? s.copyWith(isEnabled: enabled) : s];
    await _svc.saveAll(state);
  }

  Future<void> reorder(int oldIdx, int newIdx) async {
    final list = [...state];
    final item = list.removeAt(oldIdx);
    list.insert(newIdx, item);
    // 重设 priority
    state = [for (int i = 0; i < list.length; i++) list[i].copyWith(priority: i)];
    await _svc.saveAll(state);
  }

  Future<void> updateCookie(String id, String? cookie) async {
    state = [for (final s in state) s.id == id ? s.copyWith(cookie: cookie) : s];
    await _svc.saveAll(state);
  }
}

/// 刮削源管理页面 — 参照 my-nas MusicScraperSourcesPage
class ScraperSourcesPage extends ConsumerStatefulWidget {
  const ScraperSourcesPage({super.key});
  @override
  ConsumerState<ScraperSourcesPage> createState() => _ScraperSourcesPageState();
}

class _ScraperSourcesPageState extends ConsumerState<ScraperSourcesPage> {
  bool _reorderMode = false;

  @override
  Widget build(BuildContext context) {
    final sources = ref.watch(scraperSourcesProvider);

    return Scaffold(
      backgroundColor: context.yyBgBase,
      body: SafeArea(child: Column(children: [
        // 顶栏
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
          child: Row(children: [
            CupertinoButton(padding: EdgeInsets.zero,
              child: Icon(CupertinoIcons.back, color: context.yyTextPrimary, size: 24),
              onPressed: () => Navigator.pop(context)),
            const SizedBox(width: 4),
            Expanded(child: Text('刮削源管理', style: TextStyle(
              color: context.yyTextPrimary, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5))),
            GestureDetector(
              onTap: () => setState(() => _reorderMode = !_reorderMode),
              child: Container(padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _reorderMode ? YYColors.accentPrimary.withValues(alpha: 0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10)),
                child: Icon(_reorderMode ? CupertinoIcons.checkmark : CupertinoIcons.arrow_up_arrow_down,
                  color: _reorderMode ? YYColors.accentPrimary : context.yyTextSecondary, size: 20))),
          ]),
        ),

        // 说明
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: YYColors.accentPrimary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Icon(CupertinoIcons.info, color: YYColors.accentPrimary, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text('启用的源按优先级顺序用于元数据刮削。拖拽调整优先级。',
                style: TextStyle(color: YYColors.accentPrimary, fontSize: 12))),
            ])),
        ),

        // 列表
        Expanded(child: _reorderMode
          ? ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              itemCount: sources.length,
              onReorder: (o, n) {
                if (o < n) n--;
                ref.read(scraperSourcesProvider.notifier).reorder(o, n);
              },
              proxyDecorator: (child, _, animation) => AnimatedBuilder(
                animation: animation,
                builder: (_, child) => Material(
                  elevation: Tween<double>(begin: 0, end: 6).evaluate(animation),
                  borderRadius: BorderRadius.circular(16),
                  child: child),
                child: child),
              itemBuilder: (_, i) => _ScraperCard(
                key: ValueKey(sources[i].id),
                source: sources[i], reorderMode: true,
                onToggle: (v) => ref.read(scraperSourcesProvider.notifier).toggle(sources[i].id, v),
                onTap: () => _showConfig(sources[i])),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              itemCount: sources.length,
              itemBuilder: (_, i) => _ScraperCard(
                key: ValueKey(sources[i].id),
                source: sources[i], reorderMode: false,
                onToggle: (v) => ref.read(scraperSourcesProvider.notifier).toggle(sources[i].id, v),
                onTap: () => _showConfig(sources[i])),
            ),
        ),
      ])),
    );
  }

  void _showConfig(ScraperSourceEntity source) {
    if (!source.type.supportsCookie) return;
    final ctrl = TextEditingController(text: source.cookie ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.yyBgElevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(margin: const EdgeInsets.only(top: 12, bottom: 16), width: 40, height: 4,
            decoration: BoxDecoration(color: context.isDark ? Colors.grey[600] : Colors.grey[400],
              borderRadius: BorderRadius.circular(2))),
          Row(children: [
            Container(width: 40, height: 40,
              decoration: BoxDecoration(
                color: source.type.themeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12)),
              child: Icon(source.type.icon, color: source.type.themeColor, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(source.type.displayName, style: TextStyle(
                color: context.yyTextPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
              Text('Cookie 可提升匹配率（可选）', style: TextStyle(color: context.yyTextTertiary, fontSize: 12)),
            ])),
          ]),
          const SizedBox(height: 16),
          TextField(
            controller: ctrl, maxLines: 3,
            style: TextStyle(color: context.yyTextPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: '从浏览器开发者工具复制 Cookie...',
              hintStyle: TextStyle(color: context.yyTextTertiary, fontSize: 13),
              filled: true,
              fillColor: context.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06))),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: context.isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text('取消', style: TextStyle(color: context.yyTextPrimary, fontSize: 15)))),
            )),
            const SizedBox(width: 12),
            Expanded(child: GestureDetector(
              onTap: () {
                ref.read(scraperSourcesProvider.notifier).updateCookie(source.id, ctrl.text.trim().isNotEmpty ? ctrl.text.trim() : null);
                Navigator.pop(ctx);
              },
              child: Container(padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: YYColors.accentPrimary, borderRadius: BorderRadius.circular(12)),
                child: const Center(child: Text('保存', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)))),
            )),
          ]),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

/// 刮削源卡片
class _ScraperCard extends StatelessWidget {
  final ScraperSourceEntity source;
  final bool reorderMode;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTap;
  const _ScraperCard({super.key, required this.source, required this.reorderMode,
    required this.onToggle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = source.type;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: source.isEnabled
            ? t.themeColor.withValues(alpha: 0.2)
            : (context.isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06))),
        boxShadow: [if (!context.isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Row(children: [
        if (reorderMode) ...[
          Icon(CupertinoIcons.line_horizontal_3, color: context.yyTextTertiary, size: 18),
          const SizedBox(width: 10),
        ],
        Container(width: 42, height: 42,
          decoration: BoxDecoration(
            gradient: source.isEnabled
              ? LinearGradient(colors: [t.themeColor, t.themeColor.withValues(alpha: 0.7)])
              : null,
            color: source.isEnabled ? null : (context.isDark ? Colors.grey[800] : Colors.grey[200]),
            borderRadius: BorderRadius.circular(11)),
          child: Icon(t.icon, size: 20,
            color: source.isEnabled ? Colors.white : context.yyTextTertiary)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(t.displayName, style: TextStyle(
              color: source.isEnabled ? context.yyTextPrimary : context.yyTextTertiary,
              fontSize: 15, fontWeight: FontWeight.w600)),
            if (t.supportsCookie) ...[
              const SizedBox(width: 6),
              GestureDetector(onTap: onTap,
                child: Icon(CupertinoIcons.gear, size: 14, color: context.yyTextTertiary)),
            ],
          ]),
          const SizedBox(height: 3),
          Wrap(spacing: 4, runSpacing: 4, children: [
            if (t.supportsMetadata) _chip(context, '元数据', t.themeColor),
            if (t.supportsCover) _chip(context, '封面', t.themeColor),
            if (t.supportsLyrics) _chip(context, '歌词', t.themeColor),
          ]),
        ])),
        if (!reorderMode) CupertinoSwitch(
          value: source.isEnabled,
          onChanged: onToggle,
          activeTrackColor: t.themeColor.withValues(alpha: 0.6),
        ),
      ]),
    );
  }

  Widget _chip(BuildContext context, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
    child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)));
}
