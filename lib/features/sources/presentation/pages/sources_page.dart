import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/theme.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../domain/entities/source_entity.dart';
import '../providers/source_provider.dart';

/// 数据源管理页面
class SourcesPage extends ConsumerWidget {
  const SourcesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sourcesProvider);

    return Scaffold(
      backgroundColor: YYColors.bgBase,
      appBar: AppBar(
        title: const Text('数据源管理'),
        backgroundColor: Colors.transparent,
        foregroundColor: YYColors.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.plus, size: 22),
            onPressed: () => _showAddSheet(context, ref),
          ),
        ],
      ),
      body: state.sources.isEmpty
          ? _EmptyState(onAdd: () => _showAddSheet(context, ref))
          : ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                // 扫描进度
                if (state.isScanning)
                  _ScanProgress(count: state.scannedCount, file: state.scanningFile ?? ''),

                // 源列表
                ...state.sources.map((source) => _SourceTile(
                  source: source,
                  onRescan: () => ref.read(sourcesProvider.notifier).scanSource(source.id),
                  onDelete: () => _confirmDelete(context, ref, source),
                )),
              ],
            ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: YYColors.bgGlassThick,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddSourceSheet(ref: ref),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, SourceEntity source) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: YYColors.bgGlassThick,
        title: const Text('删除数据源', style: TextStyle(color: YYColors.textPrimary)),
        content: Text('确定删除 "${source.name}" 及其所有歌曲？',
            style: const TextStyle(color: YYColors.textSecondary)),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(CupertinoIcons.folder_badge_plus, size: 56, color: YYColors.textTertiary),
          const SizedBox(height: 16),
          const Text('还没有数据源', style: TextStyle(color: YYColors.textSecondary, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('添加本地目录、WebDAV 或 NAS 来获取音乐',
              style: TextStyle(color: YYColors.textTertiary, fontSize: 13)),
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
    return GlassCard(
      tintColor: YYColors.accentPrimary,
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
                Text('正在扫描... $count 个文件', style: const TextStyle(
                    color: YYColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                Text(file, style: const TextStyle(color: YYColors.textTertiary, fontSize: 11),
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
    return GlassCard(
      child: Row(
        children: [
          Icon(_typeIcon, color: YYColors.accentPrimary, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(source.name, style: const TextStyle(
                    color: YYColors.textPrimary, fontWeight: FontWeight.w500, fontSize: 15)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: _statusColor),
                    ),
                    const SizedBox(width: 6),
                    Text('${source.typeDisplayName} · ${source.songCount} 首',
                        style: const TextStyle(color: YYColors.textTertiary, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onRescan,
            child: const Icon(CupertinoIcons.arrow_2_circlepath, color: YYColors.textSecondary, size: 18),
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
  int _selectedType = 0; // 0=本地, 1=WebDAV, 2=群晖
  final _nameCtrl = TextEditingController();
  final _pathCtrl = TextEditingController();
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '5000');
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _pathCtrl.dispose();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: YYColors.textTertiary, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('添加数据源', style: TextStyle(
                color: YYColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // 类型选择
            CupertinoSlidingSegmentedControl<int>(
              groupValue: _selectedType,
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              thumbColor: YYColors.accentPrimary.withValues(alpha: 0.3),
              children: const {
                0: Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text('本地', style: TextStyle(color: YYColors.textPrimary, fontSize: 13))),
                1: Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text('WebDAV', style: TextStyle(color: YYColors.textPrimary, fontSize: 13))),
                2: Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text('群晖', style: TextStyle(color: YYColors.textPrimary, fontSize: 13))),
              },
              onValueChanged: (v) => setState(() => _selectedType = v ?? 0),
            ),
            const SizedBox(height: 16),

            // 名称
            _field(_nameCtrl, '数据源名称', CupertinoIcons.tag),

            // 按类型显示不同表单
            if (_selectedType == 0) ...[
              _field(_pathCtrl, '目录路径 (/path/to/music)', CupertinoIcons.folder),
            ],
            if (_selectedType == 1) ...[
              _field(_pathCtrl, 'WebDAV URL (https://...)', CupertinoIcons.globe),
              _field(_userCtrl, '用户名 (可选)', CupertinoIcons.person),
              _field(_passCtrl, '密码 (可选)', CupertinoIcons.lock, obscure: true),
            ],
            if (_selectedType == 2) ...[
              _field(_hostCtrl, 'NAS 地址 (192.168.1.100)', CupertinoIcons.desktopcomputer),
              _field(_portCtrl, '端口 (默认 5000)', CupertinoIcons.number),
              _field(_userCtrl, '用户名', CupertinoIcons.person),
              _field(_passCtrl, '密码', CupertinoIcons.lock, obscure: true),
              _field(_pathCtrl, '共享文件夹路径 (/music)', CupertinoIcons.folder),
            ],

            const SizedBox(height: 16),
            // 添加按钮
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

  Widget _field(TextEditingController ctrl, String hint, IconData icon, {bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(icon, color: YYColors.textTertiary, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: ctrl,
                obscureText: obscure,
                style: const TextStyle(color: YYColors.textPrimary, fontSize: 15),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(color: YYColors.textTertiary),
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
      case 0: // 本地
        notifier.addLocalSource(name, path);
        break;
      case 1: // WebDAV
        notifier.addWebDavSource(
          name: name,
          url: path,
          username: _userCtrl.text.trim().isNotEmpty ? _userCtrl.text.trim() : null,
          password: _passCtrl.text.trim().isNotEmpty ? _passCtrl.text.trim() : null,
        );
        break;
      case 2: // 群晖
        notifier.addSynologySource(
          name: name,
          host: _hostCtrl.text.trim(),
          port: int.tryParse(_portCtrl.text.trim()) ?? 5000,
          username: _userCtrl.text.trim(),
          password: _passCtrl.text.trim(),
          folderPath: path,
        );
        break;
    }

    Navigator.pop(context);
  }
}
