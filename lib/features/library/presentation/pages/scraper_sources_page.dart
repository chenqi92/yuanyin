import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/theme.dart';
import '../../../../shared/widgets/native_overlay_sheet.dart';
import '../../domain/entities/scraper_source_entity.dart';

/// Scraper sources state notifier
final scraperSourcesProvider =
    StateNotifierProvider<_ScraperNotifier, List<ScraperSourceEntity>>((ref) {
      return _ScraperNotifier();
    });

class _ScraperNotifier extends StateNotifier<List<ScraperSourceEntity>> {
  _ScraperNotifier() : super([]) {
    _load();
  }
  final _svc = ScraperSourcesService();

  Future<void> _load() async {
    state = await _svc.loadAll();
  }

  Future<void> toggle(String id, bool enabled) async {
    state = [
      for (final s in state) s.id == id ? s.copyWith(isEnabled: enabled) : s,
    ];
    await _svc.saveAll(state);
  }

  Future<void> reorder(int oldIdx, int newIdx) async {
    final list = [...state];
    final item = list.removeAt(oldIdx);
    list.insert(newIdx, item);
    state = [
      for (int i = 0; i < list.length; i++) list[i].copyWith(priority: i),
    ];
    await _svc.saveAll(state);
  }

  Future<void> updateCookie(String id, String? cookie) async {
    state = [
      for (final s in state) s.id == id ? s.copyWith(cookie: cookie) : s,
    ];
    await _svc.saveAll(state);
  }
}

/// Scraper sources management page -- iOS native style
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
          '刮削源',
          style: TextStyle(
            color: context.yyTextPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: () => setState(() => _reorderMode = !_reorderMode),
          child: Icon(
            _reorderMode
                ? CupertinoIcons.checkmark
                : CupertinoIcons.arrow_up_arrow_down,
            color: _reorderMode
                ? YYColors.accentPrimary
                : context.yyTextSecondary,
            size: 20,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Info text
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: YYColors.accentPrimary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.info,
                      color: YYColors.accentPrimary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '启用的源按优先级顺序用于元数据刮削。拖拽调整优先级。',
                        style: TextStyle(
                          color: YYColors.accentPrimary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // List
            Expanded(
              child: _reorderMode
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
                          elevation: Tween<double>(
                            begin: 0,
                            end: 6,
                          ).evaluate(animation),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.transparent,
                          child: child,
                        ),
                        child: child,
                      ),
                      itemBuilder: (_, i) => _ScraperRow(
                        key: ValueKey(sources[i].id),
                        source: sources[i],
                        reorderMode: true,
                        onToggle: (v) => ref
                            .read(scraperSourcesProvider.notifier)
                            .toggle(sources[i].id, v),
                        onTap: () => _showConfig(sources[i]),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                      itemCount: sources.length,
                      itemBuilder: (_, i) => _ScraperRow(
                        key: ValueKey(sources[i].id),
                        source: sources[i],
                        reorderMode: false,
                        onToggle: (v) => ref
                            .read(scraperSourcesProvider.notifier)
                            .toggle(sources[i].id, v),
                        onTap: () => _showConfig(sources[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfig(ScraperSourceEntity source) {
    if (!source.type.supportsCookie) return;
    final ctrl = TextEditingController(text: source.cookie ?? '');
    showYYCupertinoPopup(
      context: context,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        decoration: BoxDecoration(
          color: context.yyBgElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: context.isDark ? Colors.grey[600] : Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: source.type.themeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    source.type.icon,
                    color: source.type.themeColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        source.type.displayName,
                        style: TextStyle(
                          color: context.yyTextPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Cookie 可提升匹配率（可选）',
                        style: TextStyle(
                          color: context.yyTextTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Cookie field
            CupertinoTextField(
              controller: ctrl,
              maxLines: 3,
              placeholder: '从浏览器开发者工具复制 Cookie...',
              style: TextStyle(color: context.yyTextPrimary, fontSize: 13),
              placeholderStyle: TextStyle(
                color: context.yyTextTertiary,
                fontSize: 13,
              ),
              decoration: BoxDecoration(
                color: context.isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),
            // Buttons
            Row(
              children: [
                Expanded(
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    color: context.isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      '取消',
                      style: TextStyle(
                        color: context.yyTextPrimary,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    color: YYColors.accentPrimary,
                    borderRadius: BorderRadius.circular(10),
                    onPressed: () {
                      ref
                          .read(scraperSourcesProvider.notifier)
                          .updateCookie(
                            source.id,
                            ctrl.text.trim().isNotEmpty
                                ? ctrl.text.trim()
                                : null,
                          );
                      Navigator.pop(ctx);
                    },
                    child: const Text(
                      '保存',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Scraper source row
class _ScraperRow extends StatelessWidget {
  final ScraperSourceEntity source;
  final bool reorderMode;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTap;

  const _ScraperRow({
    super.key,
    required this.source,
    required this.reorderMode,
    required this.onToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = source.type;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: context.isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: source.isEnabled
                ? t.themeColor.withValues(alpha: 0.2)
                : context.yySeparator,
          ),
        ),
        child: Row(
          children: [
            if (reorderMode) ...[
              Icon(
                CupertinoIcons.line_horizontal_3,
                color: context.yyTextTertiary,
                size: 18,
              ),
              const SizedBox(width: 10),
            ],
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: source.isEnabled
                    ? t.themeColor.withValues(alpha: 0.15)
                    : (context.isDark ? Colors.grey[800] : Colors.grey[200]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                t.icon,
                size: 20,
                color: source.isEnabled ? t.themeColor : context.yyTextTertiary,
              ),
            ),
            const SizedBox(width: 12),
            // Name + capabilities
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        t.displayName,
                        style: TextStyle(
                          color: source.isEnabled
                              ? context.yyTextPrimary
                              : context.yyTextTertiary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (t.supportsCookie) ...[
                        const SizedBox(width: 6),
                        Icon(
                          CupertinoIcons.gear,
                          size: 14,
                          color: context.yyTextTertiary,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      if (t.supportsMetadata)
                        _chip(context, '元数据', t.themeColor),
                      if (t.supportsCover) _chip(context, '封面', t.themeColor),
                      if (t.supportsLyrics) _chip(context, '歌词', t.themeColor),
                    ],
                  ),
                ],
              ),
            ),
            // Switch (only in non-reorder mode)
            if (!reorderMode)
              CupertinoSwitch(
                value: source.isEnabled,
                onChanged: onToggle,
                activeTrackColor: t.themeColor.withValues(alpha: 0.7),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500),
    ),
  );
}
