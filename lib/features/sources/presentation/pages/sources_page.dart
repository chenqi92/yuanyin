import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/theme.dart';
import '../../../../shared/widgets/modern_music_ui.dart';
import '../../domain/entities/source_entity.dart';
import '../providers/source_provider.dart';

class SourcesPage extends ConsumerWidget {
  const SourcesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sourcesProvider);
    final connectedCount = state.sources
        .where((source) => source.status == SourceStatus.connected)
        .length;
    final totalSongs = state.sources.fold<int>(
      0,
      (sum, source) => sum + source.songCount,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: YYScenicBackground(
        accent: YYColors.accentSecondary,
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 28),
            children: [
              YYPageHeader(
                eyebrow: '内容入口',
                title: '数据源管理',
                subtitle: state.sources.isEmpty
                    ? '连接本地目录、NAS、SMB 或 WebDAV，曲库会自动补全。'
                    : '所有音乐入口都在这里统一管理，扫描和删除也更直接。',
                trailing: YYHeaderActionButton(
                  icon: CupertinoIcons.plus,
                  onTap: () => _showAddSheet(
                    context,
                    ref,
                    context.yyBgElevated,
                    context.yyTextPrimary,
                    context.yyTextTertiary,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _SourcesOverviewCard(
                  sourceCount: state.sources.length,
                  connectedCount: connectedCount,
                  songCount: totalSongs,
                  scanning: state.isScanning,
                ),
              ),
              if (state.isScanning)
                _ScanProgress(
                  count: state.scannedCount,
                  file: state.scanningFile ?? '',
                ),
              if (state.sources.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _SourceEmptyState(
                    onAdd: () => _showAddSheet(
                      context,
                      ref,
                      context.yyBgElevated,
                      context.yyTextPrimary,
                      context.yyTextTertiary,
                    ),
                  ),
                ),
              if (state.sources.isNotEmpty) ...[
                YYSectionTitle(
                  title: '已连接入口',
                  subtitle: '每个数据源都能单独重扫和删除',
                  trailing: YYPillButton(
                    label: '添加',
                    compact: true,
                    icon: CupertinoIcons.plus,
                    onTap: () => _showAddSheet(
                      context,
                      ref,
                      context.yyBgElevated,
                      context.yyTextPrimary,
                      context.yyTextTertiary,
                    ),
                  ),
                ),
                ...state.sources.map((source) {
                  return _SourceTile(
                    source: source,
                    onRescan: () => ref
                        .read(sourcesProvider.notifier)
                        .scanSource(source.id),
                    onDelete: () => _confirmDelete(
                      context,
                      ref,
                      source,
                      context.yyBgElevated,
                      context.yyTextPrimary,
                      context.yyTextSecondary,
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showAddSheet(
    BuildContext context,
    WidgetRef ref,
    Color card,
    Color pri,
    Color tri,
  ) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddSourceSheet(ref: ref, card: card, pri: pri, tri: tri),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    SourceEntity source,
    Color card,
    Color pri,
    Color sub,
  ) {
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: card,
        title: Text('删除数据源', style: TextStyle(color: pri)),
        content: Text(
          '确定删除“${source.name}”以及关联歌曲吗？',
          style: TextStyle(color: sub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: sub)),
          ),
          TextButton(
            onPressed: () {
              ref.read(sourcesProvider.notifier).removeSource(source.id);
              Navigator.pop(ctx);
            },
            child: const Text(
              '删除',
              style: TextStyle(color: YYColors.statusError),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: YYPanel(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            YYColors.accentSecondary.withValues(alpha: 0.22),
            context.yyBgElevated,
          ],
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: YYColors.accentPrimary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '正在扫描 · $count 个文件',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    file,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourcesOverviewCard extends StatelessWidget {
  const _SourcesOverviewCard({
    required this.sourceCount,
    required this.connectedCount,
    required this.songCount,
    required this.scanning,
  });

  final int sourceCount;
  final int connectedCount;
  final int songCount;
  final bool scanning;

  @override
  Widget build(BuildContext context) {
    return YYPanel(
      color: context.yyBlend(YYColors.accentSecondary, amount: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('入口总览', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            scanning
                ? '当前有扫描任务在运行，新歌曲会在完成后自动进入曲库。'
                : '连接好入口之后，首页和音乐库会自动切到完整模式。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          YYMetricBand(
            items: [
              YYMetricBandItem(
                label: '数据源',
                value: '$sourceCount',
                tint: YYColors.accentPrimary,
              ),
              YYMetricBandItem(
                label: '在线',
                value: '$connectedCount',
                tint: YYColors.accentSecondary,
              ),
              YYMetricBandItem(
                label: '歌曲',
                value: '$songCount',
                tint: YYColors.accentTertiary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SourceEmptyState extends StatelessWidget {
  const _SourceEmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return YYPanel(
      child: Column(
        children: [
          const YYIconBadge(
            icon: CupertinoIcons.waveform_path_badge_plus,
            color: YYColors.accentSecondary,
            size: 54,
          ),
          const SizedBox(height: 18),
          Text('还没有数据源', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            '先接入一个本地目录或 NAS，之后应用会自动扫描并建立曲库。',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              YYTag(text: '本地目录', icon: CupertinoIcons.folder),
              YYTag(text: 'WebDAV', icon: CupertinoIcons.globe),
              YYTag(text: 'SMB / NAS', icon: CupertinoIcons.desktopcomputer),
            ],
          ),
          const SizedBox(height: 18),
          YYPillButton(
            label: '添加第一个数据源',
            icon: CupertinoIcons.plus,
            primary: true,
            onTap: onAdd,
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

  const _SourceTile({
    required this.source,
    required this.onRescan,
    required this.onDelete,
  });

  IconData get _typeIcon {
    switch (source.type) {
      case SourceType.local:
        return CupertinoIcons.folder_fill;
      case SourceType.smb:
        return CupertinoIcons.desktopcomputer;
      case SourceType.webdav:
        return CupertinoIcons.globe;
      case SourceType.synology:
        return CupertinoIcons.cube_box_fill;
      case SourceType.qnap:
        return CupertinoIcons.archivebox_fill;
      case SourceType.jellyfin:
        return CupertinoIcons.play_rectangle_fill;
      case SourceType.emby:
        return CupertinoIcons.dot_radiowaves_left_right;
      case SourceType.plex:
        return CupertinoIcons.play_fill;
    }
  }

  Color get _statusColor {
    switch (source.status) {
      case SourceStatus.connected:
        return YYColors.statusSuccess;
      case SourceStatus.connecting:
        return YYColors.accentPrimary;
      case SourceStatus.error:
        return YYColors.statusError;
      case SourceStatus.disconnected:
        return YYColors.textTertiary;
    }
  }

  String get _statusText {
    switch (source.status) {
      case SourceStatus.connected:
        return '已连接';
      case SourceStatus.connecting:
        return '扫描中';
      case SourceStatus.error:
        return '异常';
      case SourceStatus.disconnected:
        return '未连接';
    }
  }

  String get _detailText {
    final host = source.host?.trim();
    if (host != null && host.isNotEmpty) {
      final port = source.port != null ? ':${source.port}' : '';
      return '$host$port · ${source.path}';
    }
    return source.path;
  }

  String get _lastScanLabel {
    if (source.lastScanTime == null) {
      return '还没有扫描记录';
    }

    final stamp = source.lastScanTime!;
    final date =
        '${stamp.month.toString().padLeft(2, '0')}-${stamp.day.toString().padLeft(2, '0')}';
    final time =
        '${stamp.hour.toString().padLeft(2, '0')}:${stamp.minute.toString().padLeft(2, '0')}';
    return '上次扫描 $date $time';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: YYPanel(
        color: _statusColor.withValues(alpha: context.isDark ? 0.08 : 0.045),
        child: Column(
          children: [
            Row(
              children: [
                YYIconBadge(icon: _typeIcon, color: _statusColor, size: 46),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        source.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _detailText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(YYRadius.full),
                  ),
                  child: Text(
                    _statusText,
                    style: TextStyle(
                      color: _statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            YYMetricBand(
              items: [
                YYMetricBandItem(
                  label: '类型',
                  value: source.typeDisplayName,
                  tint: _statusColor,
                ),
                YYMetricBandItem(
                  label: '歌曲',
                  value: '${source.songCount}',
                  tint: YYColors.accentPrimary,
                ),
                YYMetricBandItem(label: '状态', value: _statusText),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _lastScanLabel,
                    style: TextStyle(
                      color: context.yyTextTertiary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _SourceAction(
                  icon: CupertinoIcons.arrow_clockwise,
                  onTap: onRescan,
                ),
                const SizedBox(width: 8),
                _SourceAction(
                  icon: CupertinoIcons.delete_solid,
                  color: YYColors.statusError,
                  onTap: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceAction extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;

  const _SourceAction({required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: context.yyBgSurface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          overlayColor: WidgetStatePropertyAll(
            context.yyTextPrimary.withValues(alpha: 0.05),
          ),
          child: Icon(icon, color: color ?? context.yyTextPrimary, size: 16),
        ),
      ),
    );
  }
}

class _AddSourceSheet extends StatefulWidget {
  final WidgetRef ref;
  final Color card;
  final Color pri;
  final Color tri;

  const _AddSourceSheet({
    required this.ref,
    required this.card,
    required this.pri,
    required this.tri,
  });

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
    final surface = context.yyBgSurface;

    return Container(
      decoration: BoxDecoration(
        color: widget.card,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(YYRadius.bottomSheet),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 14,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: widget.tri.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(YYRadius.full),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text('添加数据源', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                '选择协议并填写连接信息，保存后会立即开始扫描。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              CupertinoSlidingSegmentedControl<int>(
                groupValue: _selectedType,
                backgroundColor: surface,
                thumbColor: YYColors.accentPrimary.withValues(alpha: 0.32),
                children: {
                  0: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Text('本地', style: TextStyle(color: widget.pri)),
                  ),
                  1: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Text('WebDAV', style: TextStyle(color: widget.pri)),
                  ),
                  2: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Text('群晖', style: TextStyle(color: widget.pri)),
                  ),
                  3: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Text('SMB', style: TextStyle(color: widget.pri)),
                  ),
                },
                onValueChanged: (value) {
                  setState(() {
                    _selectedType = value ?? 0;
                    _portCtrl.text = _selectedType == 3 ? '445' : '5000';
                  });
                },
              ),
              const SizedBox(height: 14),
              YYPanel(
                padding: const EdgeInsets.all(14),
                color: surface.withValues(alpha: context.isDark ? 0.72 : 0.92),
                child: Row(
                  children: [
                    YYIconBadge(
                      icon: _protocolIcon,
                      color: _protocolColor,
                      size: 38,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _protocolTitle,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _protocolHint,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _field(_nameCtrl, '数据源名称', CupertinoIcons.tag, surface),
              if (_selectedType == 0)
                _field(
                  _pathCtrl,
                  '目录路径 (/path/to/music)',
                  CupertinoIcons.folder,
                  surface,
                ),
              if (_selectedType == 1) ...[
                _field(
                  _pathCtrl,
                  'WebDAV URL (https://...)',
                  CupertinoIcons.globe,
                  surface,
                ),
                _field(_userCtrl, '用户名 (可选)', CupertinoIcons.person, surface),
                _field(
                  _passCtrl,
                  '密码 (可选)',
                  CupertinoIcons.lock,
                  surface,
                  obscure: true,
                ),
              ],
              if (_selectedType == 2) ...[
                _field(
                  _hostCtrl,
                  'NAS 地址 (192.168.1.100)',
                  CupertinoIcons.desktopcomputer,
                  surface,
                ),
                _field(
                  _portCtrl,
                  '端口 (默认 5000)',
                  CupertinoIcons.number,
                  surface,
                ),
                _field(_userCtrl, '用户名', CupertinoIcons.person, surface),
                _field(
                  _passCtrl,
                  '密码',
                  CupertinoIcons.lock,
                  surface,
                  obscure: true,
                ),
                _field(
                  _pathCtrl,
                  '共享文件夹路径 (/music)',
                  CupertinoIcons.folder,
                  surface,
                ),
              ],
              if (_selectedType == 3) ...[
                _field(
                  _hostCtrl,
                  'SMB 主机地址 (192.168.1.100)',
                  CupertinoIcons.desktopcomputer,
                  surface,
                ),
                _field(
                  _portCtrl,
                  '端口 (默认 445)',
                  CupertinoIcons.number,
                  surface,
                ),
                _field(_userCtrl, '用户名 (可选)', CupertinoIcons.person, surface),
                _field(
                  _passCtrl,
                  '密码 (可选)',
                  CupertinoIcons.lock,
                  surface,
                  obscure: true,
                ),
                _field(
                  _pathCtrl,
                  '共享路径 (/share/music)',
                  CupertinoIcons.folder,
                  surface,
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: YYColors.accentPrimary,
                  borderRadius: BorderRadius.circular(16),
                  onPressed: _submit,
                  child: const Text(
                    '添加并扫描',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String hint,
    IconData icon,
    Color surface, {
    bool obscure = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: widget.tri),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                obscureText: obscure,
                style: TextStyle(
                  color: widget.pri,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(color: widget.tri),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData get _protocolIcon {
    switch (_selectedType) {
      case 0:
        return CupertinoIcons.folder;
      case 1:
        return CupertinoIcons.globe;
      case 2:
        return CupertinoIcons.cube_box;
      case 3:
        return CupertinoIcons.desktopcomputer;
      default:
        return CupertinoIcons.folder;
    }
  }

  Color get _protocolColor {
    switch (_selectedType) {
      case 0:
        return YYColors.accentPrimary;
      case 1:
        return YYColors.accentSecondary;
      case 2:
        return YYColors.accentTertiary;
      case 3:
        return const Color(0xFF8B5CF6);
      default:
        return YYColors.accentPrimary;
    }
  }

  String get _protocolTitle {
    switch (_selectedType) {
      case 0:
        return '本地目录';
      case 1:
        return 'WebDAV';
      case 2:
        return 'Synology / 群晖';
      case 3:
        return 'SMB';
      default:
        return '本地目录';
    }
  }

  String get _protocolHint {
    switch (_selectedType) {
      case 0:
        return '适合本机目录或沙盒内已授权的音乐文件夹。';
      case 1:
        return '适合已经暴露成 HTTP/WebDAV 的音乐目录。';
      case 2:
        return '输入 NAS 地址、账号和共享路径后会立即发起扫描。';
      case 3:
        return '适合传统 SMB/CIFS 共享，推荐局域网内使用。';
      default:
        return '';
    }
  }

  String get _resolvedName {
    final name = _nameCtrl.text.trim();
    if (name.isNotEmpty) {
      return name;
    }

    switch (_selectedType) {
      case 0:
        return '本地音乐库';
      case 1:
        return 'WebDAV 音乐库';
      case 2:
        return '群晖音乐库';
      case 3:
        return 'SMB 音乐库';
      default:
        return '音乐数据源';
    }
  }

  String? _validateInput() {
    final path = _pathCtrl.text.trim();
    final host = _hostCtrl.text.trim();
    final username = _userCtrl.text.trim();
    final password = _passCtrl.text.trim();

    if (path.isEmpty) {
      return '请先填写目录、URL 或共享路径。';
    }

    switch (_selectedType) {
      case 1:
        if (!path.startsWith('http://') && !path.startsWith('https://')) {
          return 'WebDAV 地址需要以 http:// 或 https:// 开头。';
        }
        return null;
      case 2:
        if (host.isEmpty || username.isEmpty || password.isEmpty) {
          return '群晖连接需要地址、用户名和密码。';
        }
        return null;
      case 3:
        if (host.isEmpty) {
          return 'SMB 连接需要填写主机地址。';
        }
        return null;
      default:
        return null;
    }
  }

  void _submit() {
    final name = _resolvedName;
    final path = _pathCtrl.text.trim();
    final error = _validateInput();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    final notifier = widget.ref.read(sourcesProvider.notifier);

    switch (_selectedType) {
      case 0:
        notifier.addLocalSource(name, path);
        break;
      case 1:
        notifier.addWebDavSource(
          name: name,
          url: path,
          username: _userCtrl.text.trim().isNotEmpty
              ? _userCtrl.text.trim()
              : null,
          password: _passCtrl.text.trim().isNotEmpty
              ? _passCtrl.text.trim()
              : null,
        );
        break;
      case 2:
        notifier.addSynologySource(
          name: name,
          host: _hostCtrl.text.trim(),
          port: int.tryParse(_portCtrl.text.trim()) ?? 5000,
          username: _userCtrl.text.trim(),
          password: _passCtrl.text.trim(),
          folderPath: path,
        );
        break;
      case 3:
        notifier.addSmbSource(
          name: name,
          host: _hostCtrl.text.trim(),
          port: int.tryParse(_portCtrl.text.trim()) ?? 445,
          username: _userCtrl.text.trim().isNotEmpty
              ? _userCtrl.text.trim()
              : null,
          password: _passCtrl.text.trim().isNotEmpty
              ? _passCtrl.text.trim()
              : null,
          sharePath: path,
        );
        break;
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已添加 $name，正在开始扫描'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
