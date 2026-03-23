import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/theme.dart';
import '../../domain/entities/source_entity.dart';
import '../providers/source_provider.dart';

/// 数据源管理页 — 参照 my-nas SourcesPage
class SourcesPage extends ConsumerWidget {
  const SourcesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sourcesProvider);

    return Scaffold(
      backgroundColor: context.yyBgBase,
      body: SafeArea(child: Column(children: [
        // 顶部栏
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
          child: Row(children: [
            CupertinoButton(padding: EdgeInsets.zero,
              child: Icon(CupertinoIcons.back, color: context.yyTextPrimary, size: 24),
              onPressed: () => Navigator.of(context).pop()),
            const SizedBox(width: 4),
            Expanded(child: Text('连接源', style: TextStyle(
              color: context.yyTextPrimary, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5))),
            if (state.isScanning)
              const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: YYColors.accentPrimary)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _pushAdd(context),
              child: Container(padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: YYColors.accentPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10)),
                child: const Icon(CupertinoIcons.add, color: YYColors.accentPrimary, size: 20))),
          ]),
        ),

        // 扫描进度
        if (state.isScanning) _ScanBar(state: state),

        const SizedBox(height: 12),

        // 数据源列表
        Expanded(
          child: state.sources.isEmpty
            ? _EmptyView(onAdd: () => _pushAdd(context))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                itemCount: state.sources.length,
                itemBuilder: (_, i) => _SourceCard(
                  source: state.sources[i],
                  onTap: () => _showOptions(context, ref, state.sources[i]),
                  onRescan: () => ref.read(sourcesProvider.notifier).scanSource(state.sources[i].id),
                ),
              ),
        ),
      ])),
    );
  }

  void _pushAdd(BuildContext context) {
    Navigator.of(context).push(
      CupertinoPageRoute(builder: (_) => const AddSourcePage()));
  }

  // 长按/点击选项 — 参照 my-nas _showSourceOptions
  void _showOptions(BuildContext context, WidgetRef ref, SourceEntity source) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.yyBgElevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        // 拖拽条
        Container(margin: const EdgeInsets.only(top: 12, bottom: 8), width: 40, height: 4,
          decoration: BoxDecoration(
            color: context.isDark ? Colors.grey[600] : Colors.grey[400],
            borderRadius: BorderRadius.circular(2))),
        // 源信息头
        Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(children: [
            Container(width: 48, height: 48,
              decoration: BoxDecoration(
                color: _typeColor(source.type).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12)),
              child: Icon(_typeIcon(source.type), color: _typeColor(source.type), size: 24)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(source.name, style: TextStyle(color: context.yyTextPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
              Text('${source.typeDisplayName} • ${source.host ?? source.path}',
                style: TextStyle(color: context.yyTextTertiary, fontSize: 12)),
            ])),
          ])),
        Divider(height: 1, color: context.isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05)),
        // 操作列表
        _OptionTile(icon: CupertinoIcons.arrow_clockwise, label: '重新扫描',
          onTap: () { Navigator.pop(ctx); ref.read(sourcesProvider.notifier).scanSource(source.id); }),
        _OptionTile(icon: CupertinoIcons.pencil, label: '编辑',
          onTap: () { Navigator.pop(ctx); Navigator.of(context).push(
            CupertinoPageRoute(builder: (_) => AddSourcePage(existingSource: source))); }),
        _OptionTile(icon: CupertinoIcons.delete, label: '删除', color: YYColors.statusError,
          onTap: () { Navigator.pop(ctx); _confirmDelete(context, ref, source); }),
        const SizedBox(height: 16),
      ])),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, SourceEntity source) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: context.yyBgElevated,
      title: Text('删除 "${source.name}"？', style: TextStyle(color: context.yyTextPrimary, fontSize: 17)),
      content: Text('关联歌曲也会被移除', style: TextStyle(color: context.yyTextSecondary, fontSize: 14)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
          child: Text('取消', style: TextStyle(color: context.yyTextTertiary))),
        TextButton(
          onPressed: () { ref.read(sourcesProvider.notifier).removeSource(source.id); Navigator.pop(ctx); },
          child: const Text('删除', style: TextStyle(color: YYColors.statusError))),
      ],
    ));
  }

  static IconData _typeIcon(SourceType t) => switch (t) {
    SourceType.local => CupertinoIcons.folder_fill,
    SourceType.smb => CupertinoIcons.desktopcomputer,
    SourceType.webdav => CupertinoIcons.globe,
    SourceType.synology => CupertinoIcons.cube_box_fill,
    SourceType.qnap => CupertinoIcons.archivebox_fill,
    SourceType.jellyfin => CupertinoIcons.play_rectangle_fill,
    SourceType.emby => CupertinoIcons.dot_radiowaves_left_right,
    SourceType.plex => CupertinoIcons.play_fill,
  };

  static Color _typeColor(SourceType t) => switch (t) {
    SourceType.synology => const Color(0xFF2196F3),
    SourceType.webdav => const Color(0xFF43A047),
    SourceType.smb => const Color(0xFFFF9800),
    SourceType.jellyfin => const Color(0xFF9C27B0),
    SourceType.emby => const Color(0xFF00BCD4),
    SourceType.plex => const Color(0xFFE91E63),
    _ => YYColors.accentPrimary,
  };
}

// ─── 选项行 ───
class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;
  const _OptionTile({required this.icon, required this.label, this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color ?? context.yyTextPrimary, size: 22),
      title: Text(label, style: TextStyle(color: color ?? context.yyTextPrimary, fontSize: 15)),
      onTap: onTap,
    );
  }
}

// ─── 扫描进度条 ───
class _ScanBar extends StatelessWidget {
  final SourcesState state;
  const _ScanBar({required this.state});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: YYColors.accentPrimary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const SizedBox(width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: YYColors.accentPrimary)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('扫描中 · ${state.scannedCount} 个文件',
              style: TextStyle(color: context.yyTextPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
            if (state.scanningFile != null && state.scanningFile!.isNotEmpty)
              Text(state.scanningFile!, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: context.yyTextTertiary, fontSize: 11)),
          ])),
        ])),
    );
  }
}

// ─── 空状态 ───
class _EmptyView extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyView({required this.onAdd});
  @override
  Widget build(BuildContext context) {
    return Center(child: Padding(padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 80, height: 80,
          decoration: BoxDecoration(color: YYColors.accentPrimary.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: const Icon(CupertinoIcons.folder_badge_plus, size: 40, color: YYColors.accentPrimary)),
        const SizedBox(height: 24),
        Text('尚未添加任何源', style: TextStyle(color: context.yyTextPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('添加 NAS、WebDAV 或 SMB 源\n以开始播放音乐', textAlign: TextAlign.center,
          style: TextStyle(color: context.yyTextTertiary, fontSize: 14)),
        const SizedBox(height: 24),
        GestureDetector(onTap: onAdd,
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(color: YYColors.accentPrimary, borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(CupertinoIcons.add, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              const Text('添加源', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            ]))),
      ])));
  }
}

// ─── 数据源卡片（参照 my-nas _SourceCard）───
class _SourceCard extends StatelessWidget {
  final SourceEntity source;
  final VoidCallback onTap;
  final VoidCallback onRescan;
  const _SourceCard({required this.source, required this.onTap, required this.onRescan});

  Color get _statusColor => switch (source.status) {
    SourceStatus.connected => YYColors.statusSuccess,
    SourceStatus.connecting => YYColors.accentPrimary,
    SourceStatus.error => YYColors.statusError,
    SourceStatus.disconnected => YYColors.textTertiary,
  };

  String get _statusLabel => switch (source.status) {
    SourceStatus.connected => '已连接',
    SourceStatus.connecting => '连接中',
    SourceStatus.error => '异常',
    SourceStatus.disconnected => '未连接',
  };

  @override
  Widget build(BuildContext context) {
    final typeColor = SourcesPage._typeColor(source.type);
    final icon = SourcesPage._typeIcon(source.type);
    final detail = (source.host != null && source.host!.trim().isNotEmpty)
        ? '${source.host}${source.port != null ? ':${source.port}' : ''}' : source.path;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
          boxShadow: context.isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))]),
        child: Row(children: [
          // 图标
          Container(width: 48, height: 48,
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: typeColor, size: 24)),
          const SizedBox(width: 16),
          // 信息
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(source.name, style: TextStyle(color: context.yyTextPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('${source.typeDisplayName} • $detail', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.yyTextTertiary, fontSize: 12)),
            if (source.songCount > 0) ...[
              const SizedBox(height: 4),
              Text('${source.songCount} 首歌曲', style: TextStyle(color: context.yyTextSecondary, fontSize: 11)),
            ],
            if (source.errorMessage != null) ...[
              const SizedBox(height: 4),
              Text(source.errorMessage!, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: YYColors.statusError, fontSize: 11)),
            ],
          ])),
          // 状态标签
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16)),
            child: Text(_statusLabel, style: TextStyle(
              color: _statusColor, fontSize: 12, fontWeight: FontWeight.w500))),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  添加/编辑源页面 — 参照 my-nas AddSourceSheet（全屏页面版）
// ═══════════════════════════════════════════════════════════

class _TypeCfg {
  final String label;
  final SourceType type;
  final IconData icon;
  final Color color;
  final bool ok;
  const _TypeCfg(this.label, this.type, this.icon, this.color, {this.ok = true});
}

const _types = [
  _TypeCfg('群晖', SourceType.synology, CupertinoIcons.cube_box, Color(0xFF2196F3)),
  _TypeCfg('WebDAV', SourceType.webdav, CupertinoIcons.globe, Color(0xFF43A047)),
  _TypeCfg('SMB', SourceType.smb, CupertinoIcons.desktopcomputer, Color(0xFFFF9800)),
  _TypeCfg('本地', SourceType.local, CupertinoIcons.folder, YYColors.accentPrimary),
  _TypeCfg('Jellyfin', SourceType.jellyfin, CupertinoIcons.play_rectangle, Color(0xFF9C27B0), ok: false),
  _TypeCfg('Emby', SourceType.emby, CupertinoIcons.dot_radiowaves_left_right, Color(0xFF00BCD4), ok: false),
  _TypeCfg('Plex', SourceType.plex, CupertinoIcons.play, Color(0xFFE91E63), ok: false),
];

class AddSourcePage extends ConsumerStatefulWidget {
  final SourceEntity? existingSource;
  const AddSourcePage({super.key, this.existingSource});
  @override
  ConsumerState<AddSourcePage> createState() => _AddSourcePageState();
}

class _AddSourcePageState extends ConsumerState<AddSourcePage> {
  int _sel = 0;
  final _nameCtrl = TextEditingController();
  final _pathCtrl = TextEditingController();
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '5001');
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _ssl = true;
  bool _obscure = true;
  bool _submitting = false;
  String? _errorMsg;
  String? _pickedFolder;
  String? _deviceToken;

  bool get _editing => widget.existingSource != null;

  @override
  void initState() {
    super.initState();
    final src = widget.existingSource;
    if (src != null) {
      _sel = _types.indexWhere((t) => t.type == src.type).clamp(0, _types.length - 1);
      _nameCtrl.text = src.name;
      _pathCtrl.text = src.path;
      _hostCtrl.text = src.host ?? '';
      _portCtrl.text = (src.port ?? 5001).toString();
      _userCtrl.text = src.username ?? '';
      _passCtrl.text = src.password ?? '';
      _ssl = src.useSsl;
      _pickedFolder = src.path;
      _deviceToken = src.deviceToken;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _pathCtrl.dispose(); _hostCtrl.dispose();
    _portCtrl.dispose(); _userCtrl.dispose(); _passCtrl.dispose();
    super.dispose();
  }

  SourceType get _type => _types[_sel].type;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.yyBgBase,
      body: SafeArea(child: Column(children: [
        // 顶栏
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
          child: Row(children: [
            CupertinoButton(padding: EdgeInsets.zero,
              child: Icon(CupertinoIcons.back, color: context.yyTextPrimary, size: 24),
              onPressed: () => Navigator.of(context).pop()),
            const SizedBox(width: 4),
            Expanded(child: Text(_editing ? '编辑源' : '添加源', style: TextStyle(
              color: context.yyTextPrimary, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5))),
          ]),
        ),

        // 表单
        Expanded(child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            // 类型选择 — FilterChip 风格
            Text('源类型', style: TextStyle(color: context.yyTextPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8,
              children: List.generate(_types.length, (i) {
                final t = _types[i];
                final active = _sel == i;
                return GestureDetector(
                  onTap: t.ok ? () => setState(() {
                    _sel = i;
                    _portCtrl.text = _defaultPort(t.type).toString();
                    _ssl = t.type == SourceType.synology || t.type == SourceType.webdav;
                    _errorMsg = null;
                  }) : null,
                  child: AnimatedContainer(duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: active ? t.color : (context.isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)),
                      borderRadius: BorderRadius.circular(20),
                      border: active ? null : Border.all(
                        color: context.isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08)),
                      boxShadow: active ? [BoxShadow(color: t.color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))] : null),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(t.icon, size: 16, color: active ? Colors.white : (t.ok ? context.yyTextSecondary : context.yyTextTertiary)),
                      const SizedBox(width: 6),
                      Text(t.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: active ? Colors.white : (t.ok ? context.yyTextPrimary : context.yyTextTertiary))),
                      if (!t.ok) ...[
                        const SizedBox(width: 4),
                        Text('即将', style: TextStyle(fontSize: 10, color: context.yyTextTertiary)),
                      ],
                    ])),
                );
              }),
            ),

            const SizedBox(height: 24),

            // 名称
            _FormField(label: '名称（可选）', hint: '例如: 我的 NAS', ctrl: _nameCtrl, icon: CupertinoIcons.tag),

            // 远程源字段
            if (_type != SourceType.local) ...[
              const SizedBox(height: 16),
              _FormField(label: '主机地址', hint: '192.168.1.100', ctrl: _hostCtrl, icon: CupertinoIcons.wifi,
                keyboardType: TextInputType.url),
              const SizedBox(height: 16),
              // 端口 + SSL
              if (_type != SourceType.smb)
                Row(children: [
                  Expanded(child: _FormField(label: '端口', hint: '5001', ctrl: _portCtrl, icon: CupertinoIcons.number,
                    keyboardType: TextInputType.number)),
                  const SizedBox(width: 16),
                  Column(children: [
                    Text('SSL', style: TextStyle(color: context.yyTextTertiary, fontSize: 12)),
                    const SizedBox(height: 4),
                    CupertinoSwitch(value: _ssl, onChanged: (v) => setState(() => _ssl = v),
                      activeTrackColor: YYColors.accentPrimary),
                  ]),
                ]),
              if (_type != SourceType.smb) const SizedBox(height: 16),

              _FormField(label: '用户名', hint: 'admin', ctrl: _userCtrl, icon: CupertinoIcons.person),
              const SizedBox(height: 16),
              _FormField(label: _editing ? '密码（留空保持不变）' : '密码', hint: '••••••', ctrl: _passCtrl,
                icon: CupertinoIcons.lock, obscure: _obscure,
                suffix: GestureDetector(onTap: () => setState(() => _obscure = !_obscure),
                  child: Icon(_obscure ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                    color: context.yyTextTertiary, size: 18))),
            ],

            // 文件夹选择（群晖）
            if (_type == SourceType.synology) ...[
              const SizedBox(height: 16),
              _FormField(label: '音乐目录', hint: '/music', ctrl: _pathCtrl, icon: CupertinoIcons.folder),
            ],

            // 本地路径
            if (_type == SourceType.local) ...[
              const SizedBox(height: 16),
              Container(padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(CupertinoIcons.info, color: Color(0xFF2196F3), size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text('将访问设备媒体库和文档目录',
                    style: TextStyle(color: const Color(0xFF2196F3), fontSize: 13))),
                ])),
            ],

            // 错误消息
            if (_errorMsg != null) ...[
              const SizedBox(height: 16),
              Container(padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: YYColors.statusError.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(CupertinoIcons.xmark_circle, color: YYColors.statusError, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_errorMsg!, style: const TextStyle(color: YYColors.statusError, fontSize: 13))),
                ])),
            ],

            const SizedBox(height: 32),

            // 提交按钮
            GestureDetector(
              onTap: _submitting ? null : _doSubmit,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _submitting ? YYColors.accentPrimary.withValues(alpha: 0.5) : YYColors.accentPrimary,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: YYColors.accentPrimary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))]),
                child: Center(child: _submitting
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_editing ? '保存' : '添加并扫描',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700))),
              ),
            ),
          ],
        )),
      ])),
    );
  }

  int _defaultPort(SourceType t) => switch (t) {
    SourceType.synology => 5001,
    SourceType.webdav => 443,
    SourceType.smb => 445,
    _ => 0,
  };

  Future<void> _doSubmit() async {
    setState(() { _submitting = true; _errorMsg = null; });
    try {
      final n = ref.read(sourcesProvider.notifier);

      if (_editing) {
        final updated = widget.existingSource!.copyWith(
          name: _name, path: _pathCtrl.text.trim().isNotEmpty ? _pathCtrl.text.trim() : widget.existingSource!.path,
          host: _hostCtrl.text.trim().isNotEmpty ? _hostCtrl.text.trim() : null,
          port: int.tryParse(_portCtrl.text.trim()),
          username: _userCtrl.text.trim().isNotEmpty ? _userCtrl.text.trim() : null,
          password: _passCtrl.text.trim().isNotEmpty ? _passCtrl.text.trim() : null,
          useSsl: _ssl, deviceToken: _deviceToken);
        await n.editSource(updated);
        if (mounted) Navigator.pop(context);
        return;
      }

      switch (_type) {
        case SourceType.local: n.addLocalSource(_name, _pathCtrl.text.trim()); break;
        case SourceType.webdav: n.addWebDavSource(name: _name, url: _pathCtrl.text.trim(),
          username: _userCtrl.text.trim().isNotEmpty ? _userCtrl.text.trim() : null,
          password: _passCtrl.text.trim().isNotEmpty ? _passCtrl.text.trim() : null); break;
        case SourceType.synology:
          // 先测试连接
          final tempSource = SourceEntity(
            id: 'test_${DateTime.now().millisecondsSinceEpoch}',
            name: _name, type: SourceType.synology,
            path: _pathCtrl.text.trim().isNotEmpty ? _pathCtrl.text.trim() : '/music',
            host: _hostCtrl.text.trim(),
            port: int.tryParse(_portCtrl.text.trim()) ?? 5001,
            username: _userCtrl.text.trim(),
            password: _passCtrl.text.trim(),
            useSsl: _ssl);
          final result = await n.testConnection(tempSource);
          final success = result.$1;
          final errMsg = result.$2;
          // testConnection returns (bool, String?) — $2 contains 'otp_required' when OTP needed
          if (errMsg != null && errMsg.contains('otp')) {
            if (mounted) {
              final otp = await _showOtpSheet(context);
              if (otp != null) {
                _deviceToken = otp.$2;
                n.addSynologySource(name: _name, host: _hostCtrl.text.trim(),
                  port: int.tryParse(_portCtrl.text.trim()) ?? 5001,
                  username: _userCtrl.text.trim(), password: _passCtrl.text.trim(),
                  folderPath: _pathCtrl.text.trim().isNotEmpty ? _pathCtrl.text.trim() : '/music',
                  useSsl: _ssl, deviceToken: _deviceToken, otpCode: otp.$1);
              }
            }
          } else if (success) {
            n.addSynologySource(name: _name, host: _hostCtrl.text.trim(),
              port: int.tryParse(_portCtrl.text.trim()) ?? 5001,
              username: _userCtrl.text.trim(), password: _passCtrl.text.trim(),
              folderPath: _pathCtrl.text.trim().isNotEmpty ? _pathCtrl.text.trim() : '/music',
              useSsl: _ssl, deviceToken: _deviceToken);
          } else {
            setState(() => _errorMsg = errMsg ?? '连接失败');
            return;
          }
          break;
        case SourceType.smb: n.addSmbSource(name: _name, host: _hostCtrl.text.trim(),
          port: int.tryParse(_portCtrl.text.trim()) ?? 445,
          sharePath: _pathCtrl.text.trim().isNotEmpty ? _pathCtrl.text.trim() : '/share',
          username: _userCtrl.text.trim().isNotEmpty ? _userCtrl.text.trim() : null,
          password: _passCtrl.text.trim().isNotEmpty ? _passCtrl.text.trim() : null); break;
        default: break;
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _errorMsg = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String get _name {
    final n = _nameCtrl.text.trim();
    if (n.isNotEmpty) return n;
    return _types[_sel].label;
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('Connection refused')) return '连接被拒绝，请检查地址和端口';
    if (msg.contains('Connection timed out')) return '连接超时，请检查网络';
    if (msg.contains('HandshakeException')) return 'SSL 握手失败，请检查 SSL 设置';
    if (msg.contains('SocketException')) return '网络连接失败';
    return msg;
  }

  // OTP 底部面板 — 参照 my-nas TwoFASheet
  Future<(String, String?)?> _showOtpSheet(BuildContext context) async {
    final otpCtrls = List.generate(6, (_) => TextEditingController());
    final focusNodes = List.generate(6, (_) => FocusNode());
    bool remember = false;
    String? resultToken;
    String? resultOtp;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        return Container(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          decoration: BoxDecoration(
            color: ctx.yyBgElevated,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // 拖拽条
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
            // 图标 + 标题
            Container(width: 56, height: 56,
              decoration: BoxDecoration(
                gradient: YYColors.accentGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: YYColors.accentPrimary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))]),
              child: const Icon(CupertinoIcons.lock_shield_fill, color: Colors.white, size: 28)),
            const SizedBox(height: 16),
            Text('二次验证', style: TextStyle(color: ctx.yyTextPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('请输入验证器应用中的 6 位验证码', style: TextStyle(color: ctx.yyTextTertiary, fontSize: 13)),
            const SizedBox(height: 24),
            // 6 位输入框
            Row(mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (i) => Container(
                width: 44, height: 52,
                margin: EdgeInsets.only(left: i > 0 ? 8 : 0),
                child: TextField(
                  controller: otpCtrls[i], focusNode: focusNodes[i],
                  textAlign: TextAlign.center, maxLength: 1,
                  keyboardType: TextInputType.number,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: ctx.yyTextPrimary),
                  decoration: InputDecoration(
                    counterText: '',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: ctx.yyTextTertiary.withValues(alpha: 0.3))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: YYColors.accentPrimary, width: 2)),
                    filled: true,
                    fillColor: ctx.isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.03)),
                  onChanged: (v) {
                    if (v.isNotEmpty && i < 5) focusNodes[i + 1].requestFocus();
                    if (v.isEmpty && i > 0) focusNodes[i - 1].requestFocus();
                  },
                ),
              ))),
            const SizedBox(height: 16),
            // 记住设备
            GestureDetector(
              onTap: () => setS(() => remember = !remember),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(remember ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
                  color: remember ? YYColors.accentPrimary : ctx.yyTextTertiary, size: 20),
                const SizedBox(width: 8),
                Text('记住此设备', style: TextStyle(color: ctx.yyTextSecondary, fontSize: 14)),
              ])),
            const SizedBox(height: 24),
            // 按钮
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(ctx, false),
                child: Container(padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: ctx.isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text('取消', style: TextStyle(color: ctx.yyTextSecondary, fontSize: 15, fontWeight: FontWeight.w600)))))),
              const SizedBox(width: 12),
              Expanded(child: GestureDetector(
                onTap: () {
                  resultOtp = otpCtrls.map((c) => c.text).join();
                  if (resultOtp!.length == 6) Navigator.pop(ctx, true);
                },
                child: Container(padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(color: YYColors.accentPrimary, borderRadius: BorderRadius.circular(12)),
                  child: const Center(child: Text('验证', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)))))),
            ]),
          ]),
        );
      }),
    );

    for (final c in otpCtrls) c.dispose();
    for (final f in focusNodes) f.dispose();

    if (confirmed == true && resultOtp != null && resultOtp!.length == 6) {
      return (resultOtp!, resultToken);
    }
    return null;
  }
}

// ─── 表单输入框 ───
class _FormField extends StatelessWidget {
  final String label, hint;
  final TextEditingController ctrl;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscure;
  final Widget? suffix;
  const _FormField({required this.label, required this.hint, required this.ctrl, required this.icon,
    this.keyboardType, this.obscure = false, this.suffix});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: context.yyTextSecondary, fontSize: 13)),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(
          color: context.isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06))),
        child: TextField(
          controller: ctrl, obscureText: obscure,
          keyboardType: keyboardType,
          style: TextStyle(color: context.yyTextPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint, hintStyle: TextStyle(color: context.yyTextTertiary.withValues(alpha: 0.5)),
            prefixIcon: Icon(icon, color: context.yyTextTertiary, size: 18),
            suffixIcon: suffix != null ? Padding(padding: const EdgeInsets.all(12), child: suffix) : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14))),
      ),
    ]);
  }
}
