import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/theme.dart';
import '../../domain/entities/source_entity.dart';
import '../providers/source_provider.dart';

/// 数据源管理页面 — 自适应亮暗主题
class SourcesPage extends ConsumerWidget {
  const SourcesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sourcesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? YYColors.bgBase : YYLightColors.bgBase;
    final card = isDark ? YYColors.bgElevated : YYLightColors.bgElevated;
    final pri = isDark ? YYColors.textPrimary : YYLightColors.textPrimary;
    final sub = isDark ? YYColors.textSecondary : YYLightColors.textSecondary;
    final tri = isDark ? YYColors.textTertiary : YYLightColors.textTertiary;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('数据源管理'),
        backgroundColor: Colors.transparent,
        foregroundColor: pri,
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.plus, size: 22),
            onPressed: () => _showAddSheet(context, ref, card, pri, tri),
          ),
        ],
      ),
      body: state.sources.isEmpty
          ? _EmptyState(onAdd: () => _showAddSheet(context, ref, card, pri, tri))
          : ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                if (state.isScanning)
                  _ScanProgress(count: state.scannedCount, file: state.scanningFile ?? ''),
                ...state.sources.map((source) => _SourceTile(
                  source: source,
                  onRescan: () => ref.read(sourcesProvider.notifier).scanSource(source.id),
                  onDelete: () => _confirmDelete(context, ref, source, card, pri, sub),
                )),
              ],
            ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref, Color card, Color pri, Color tri) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddSourceSheet(ref: ref),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, SourceEntity source,
      Color card, Color pri, Color sub) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: card,
        title: Text('删除数据源', style: TextStyle(color: pri)),
        content: Text('确定删除 "${source.name}" 及其所有歌曲？',
            style: TextStyle(color: sub)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              ref.read(sourcesProvider.notifier).removeSource(source.id);
              Navigator.pop(ctx);
            },
            child: const Text('删除', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sub = isDark ? YYColors.textSecondary : YYLightColors.textSecondary;
    final tri = isDark ? YYColors.textTertiary : YYLightColors.textTertiary;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.folder_badge_plus, size: 56, color: tri),
          const SizedBox(height: 16),
          Text('还没有数据源', style: TextStyle(color: sub, fontSize: 16)),
          const SizedBox(height: 8),
          Text('添加本地目录、WebDAV 或 NAS 来获取音乐',
              style: TextStyle(color: tri, fontSize: 13)),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: YYColors.accentPrimary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('添加数据源', style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanProgress extends StatelessWidget {
  final int count;
  final String file;
  const _ScanProgress({required this.count, required this.file});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? YYColors.bgElevated : YYLightColors.bgElevated;
    final pri = isDark ? YYColors.textPrimary : YYLightColors.textPrimary;
    final tri = isDark ? YYColors.textTertiary : YYLightColors.textTertiary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: YYColors.accentPrimary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('正在扫描... $count 个文件', style: TextStyle(
                    color: pri, fontSize: 14, fontWeight: FontWeight.w500)),
                Text(file, style: TextStyle(color: tri, fontSize: 11),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final SourceEntity source;
  final VoidCallback onRescan;
  final VoidCallback onDelete;
  const _SourceTile({required this.source, required this.onRescan, required this.onDelete});

  IconData get _typeIcon {
    switch (source.type) {
      case SourceType.local: return CupertinoIcons.folder;
      case SourceType.smb: return CupertinoIcons.desktopcomputer;
      case SourceType.webdav: return CupertinoIcons.globe;
      case SourceType.synology: return CupertinoIcons.cube;
      default: return CupertinoIcons.cloud;
    }
  }

  Color get _statusColor {
    switch (source.status) {
      case SourceStatus.connected: return const Color(0xFF43E97B);
      case SourceStatus.connecting: return YYColors.accentPrimary;
      case SourceStatus.error: return Colors.redAccent;
      case SourceStatus.disconnected: return YYColors.textTertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? YYColors.bgElevated : YYLightColors.bgElevated;
    final pri = isDark ? YYColors.textPrimary : YYLightColors.textPrimary;
    final sub = isDark ? YYColors.textSecondary : YYLightColors.textSecondary;
    final tri = isDark ? YYColors.textTertiary : YYLightColors.textTertiary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(_typeIcon, color: YYColors.accentPrimary, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(source.name, style: TextStyle(color: pri, fontWeight: FontWeight.w500, fontSize: 15)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(width: 6, height: 6,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: _statusColor)),
                    const SizedBox(width: 6),
                    Text('${source.typeDisplayName} · ${source.songCount} 首',
                        style: TextStyle(color: tri, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onRescan,
            child: Icon(CupertinoIcons.arrow_2_circlepath, color: sub, size: 18),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(CupertinoIcons.delete, color: Colors.redAccent, size: 18),
          ),
        ],
      ),
    );
  }
}

// ---- 添加数据源底部弹窗 ----
class _AddSourceSheet extends StatefulWidget {
  final WidgetRef ref;
  const _AddSourceSheet({required this.ref});

  @override
  State<_AddSourceSheet> createState() => _AddSourceSheetState();
}

class _AddSourceSheetState extends State<_AddSourceSheet> {
  int _selectedType = 0;
  final _nameCtrl = TextEditingController();
  final _pathCtrl = TextEditingController();
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '5000');
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose(); _pathCtrl.dispose(); _hostCtrl.dispose();
    _portCtrl.dispose(); _userCtrl.dispose(); _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pri = isDark ? YYColors.textPrimary : YYLightColors.textPrimary;
    final tri = isDark ? YYColors.textTertiary : YYLightColors.textTertiary;
    final surface = isDark ? YYColors.bgSurface : YYLightColors.bgSurface;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: tri, borderRadius: BorderRadius.circular(2)),
            )),
            const SizedBox(height: 16),
            Text('添加数据源', style: TextStyle(color: pri, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            CupertinoSlidingSegmentedControl<int>(
              groupValue: _selectedType,
              backgroundColor: surface,
              thumbColor: YYColors.accentPrimary.withValues(alpha: 0.3),
              children: {
                0: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Text('本地', style: TextStyle(color: pri, fontSize: 13))),
                1: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Text('WebDAV', style: TextStyle(color: pri, fontSize: 13))),
                2: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Text('群晖', style: TextStyle(color: pri, fontSize: 13))),
                3: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Text('SMB', style: TextStyle(color: pri, fontSize: 13))),
              },
              onValueChanged: (v) => setState(() => _selectedType = v ?? 0),
            ),
            const SizedBox(height: 16),
            _field(_nameCtrl, '数据源名称', CupertinoIcons.tag, pri, tri, surface),
            if (_selectedType == 0) ...[
              _field(_pathCtrl, '目录路径 (/path/to/music)', CupertinoIcons.folder, pri, tri, surface),
            ],
            if (_selectedType == 1) ...[
              _field(_pathCtrl, 'WebDAV URL (https://...)', CupertinoIcons.globe, pri, tri, surface),
              _field(_userCtrl, '用户名 (可选)', CupertinoIcons.person, pri, tri, surface),
              _field(_passCtrl, '密码 (可选)', CupertinoIcons.lock, pri, tri, surface, obscure: true),
            ],
            if (_selectedType == 2) ...[
              _field(_hostCtrl, 'NAS 地址 (192.168.1.100)', CupertinoIcons.desktopcomputer, pri, tri, surface),
              _field(_portCtrl, '端口 (默认 5000)', CupertinoIcons.number, pri, tri, surface),
              _field(_userCtrl, '用户名', CupertinoIcons.person, pri, tri, surface),
              _field(_passCtrl, '密码', CupertinoIcons.lock, pri, tri, surface, obscure: true),
              _field(_pathCtrl, '共享文件夹路径 (/music)', CupertinoIcons.folder, pri, tri, surface),
            ],
            if (_selectedType == 3) ...[
              _field(_hostCtrl, 'SMB 主机地址 (192.168.1.100)', CupertinoIcons.desktopcomputer, pri, tri, surface),
              _field(_portCtrl, '端口 (默认 445)', CupertinoIcons.number, pri, tri, surface),
              _field(_userCtrl, '用户名 (可选)', CupertinoIcons.person, pri, tri, surface),
              _field(_passCtrl, '密码 (可选)', CupertinoIcons.lock, pri, tri, surface, obscure: true),
              _field(_pathCtrl, '共享路径 (/share/music)', CupertinoIcons.folder, pri, tri, surface),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                color: YYColors.accentPrimary,
                borderRadius: BorderRadius.circular(12),
                onPressed: _submit,
                child: const Text('添加并扫描', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint, IconData icon,
      Color pri, Color tri, Color surface, {bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(icon, color: tri, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: ctrl,
                obscureText: obscure,
                style: TextStyle(color: pri, fontSize: 15),
                decoration: InputDecoration(
                  hintText: hint, hintStyle: TextStyle(color: tri),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    final path = _pathCtrl.text.trim();
    if (name.isEmpty || path.isEmpty) return;
    final notifier = widget.ref.read(sourcesProvider.notifier);
    switch (_selectedType) {
      case 0: notifier.addLocalSource(name, path);
      case 1: notifier.addWebDavSource(name: name, url: path,
          username: _userCtrl.text.trim().isNotEmpty ? _userCtrl.text.trim() : null,
          password: _passCtrl.text.trim().isNotEmpty ? _passCtrl.text.trim() : null);
      case 2: notifier.addSynologySource(name: name, host: _hostCtrl.text.trim(),
          port: int.tryParse(_portCtrl.text.trim()) ?? 5000,
          username: _userCtrl.text.trim(), password: _passCtrl.text.trim(), folderPath: path);
      case 3: notifier.addSmbSource(name: name, host: _hostCtrl.text.trim(),
          port: int.tryParse(_portCtrl.text.trim()) ?? 445,
          username: _userCtrl.text.trim().isNotEmpty ? _userCtrl.text.trim() : null,
          password: _passCtrl.text.trim().isNotEmpty ? _passCtrl.text.trim() : null, sharePath: path);
    }
    Navigator.pop(context);
  }
}
