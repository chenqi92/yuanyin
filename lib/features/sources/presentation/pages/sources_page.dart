import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/theme.dart';
import '../../../../shared/widgets/modern_music_ui.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../data/services/smb_scanner.dart';
import '../../data/services/network_discovery_service.dart';
import '../../domain/entities/source_entity.dart';
import '../providers/source_provider.dart';
import '../../../library/data/services/metadata_scraper.dart';
import '../../../library/presentation/providers/library_provider.dart';

class SourcesPage extends ConsumerStatefulWidget {
  const SourcesPage({super.key});

  @override
  ConsumerState<SourcesPage> createState() => _SourcesPageState();
}

class _SourcesPageState extends ConsumerState<SourcesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(networkDiscoveryProvider.notifier).startDiscovery();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sourcesProvider);
    final discoveryState = ref.watch(networkDiscoveryProvider);

    return YYScenicBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // Top Bar
              YYPageHeader(
                eyebrow: discoveryState.isDiscovering ? '正在发现设备...' : '数据源',
                title: '连接中心',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    YYHeaderActionButton(
                      icon: CupertinoIcons.antenna_radiowaves_left_right,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        ref.read(networkDiscoveryProvider.notifier).startDiscovery();
                      },
                      primary: discoveryState.isDiscovering,
                    ),
                    const SizedBox(width: 12),
                    YYHeaderActionButton(
                      icon: CupertinoIcons.add,
                      onTap: () => _pushAdd(context),
                    ),
                  ],
                ),
              ),

              if (state.isScanning) _ScanBar(state: state),

              const SizedBox(height: 12),

              Expanded(
                child: state.sources.isEmpty && discoveryState.devices.isEmpty
                  ? _EmptyView(onAdd: () => _pushAdd(context))
                  : ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                      children: [
                        if (discoveryState.devices.isNotEmpty || discoveryState.isDiscovering) ...[
                          YYSectionTitle(
                            title: '发现的设备',
                            subtitle: discoveryState.isDiscovering ? '扫描中...' : '点击卡片快速连接',
                          ),
                          ...discoveryState.devices.map((device) => _DiscoveredDeviceCard(
                            device: device,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.of(context).push(CupertinoPageRoute(
                                builder: (_) => AddSourcePage(
                                  preselectedType: device.type,
                                  discoveredDevice: device,
                                ),
                              ));
                            },
                          )),
                          const SizedBox(height: 24),
                        ],

                        if (state.sources.isNotEmpty) ...[
                          YYSectionTitle(
                            title: '已配置的连接',
                            subtitle: '${state.sources.length} 个活跃节点',
                          ),
                          ...state.sources.map((source) => _SourceCard(
                            source: source,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              _showOptions(context, ref, source);
                            },
                            onRescan: () => ref.read(sourcesProvider.notifier).scanSource(source.id),
                          )),
                        ],
                      ],
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _pushAdd(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SourceTypePicker(
        onTypeSelected: (type) {
          Navigator.pop(ctx);
          Navigator.of(context).push(CupertinoPageRoute(
            builder: (_) => AddSourcePage(preselectedType: type)));
        },
      ),
    );
  }

  void _showOptions(BuildContext context, WidgetRef ref, SourceEntity source) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SourceOptionsSheet(
        source: source,
        onOptionTap: (action) {
          Navigator.pop(ctx);
          switch (action) {
            case 'folder':
              Navigator.of(context).push(CupertinoPageRoute(builder: (_) => _FolderManagerPage(source: source)));
              break;
            case 'rescan':
              ref.read(sourcesProvider.notifier).scanSource(source.id);
              break;
            case 'scrape':
              _showScrapeForSource(context, ref, source);
              break;
            case 'edit':
              Navigator.of(context).push(CupertinoPageRoute(builder: (_) => AddSourcePage(existingSource: source, preselectedType: source.type)));
              break;
            case 'delete':
              _confirmDelete(context, ref, source);
              break;
          }
        },
      ),
    );
  }

  void _showScrapeForSource(BuildContext context, WidgetRef ref, SourceEntity source) async {
    final db = ref.read(musicDatabaseProvider);
    final allSongs = await db.getAllSongs();
    final sourceSongs = allSongs.where((s) => s.sourceId == source.id).toList();
    if (sourceSongs.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('此数据源暂无歌曲'), behavior: SnackBarBehavior.floating));
      }
      return;
    }
    if (context.mounted) {
      showDialog(context: context, useRootNavigator: true, barrierDismissible: false,
        builder: (_) => _SourceScrapeDialog(ref: ref, sourceId: source.id, sourceName: source.name));
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, SourceEntity source) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: context.yyBgElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('删除连接', style: context.yyTextTheme.titleLarge),
      content: Text('确定要移除 "${source.name}" 吗？关联的音乐库数据也将被清理。', style: context.yyTextTheme.bodyMedium),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消', style: TextStyle(color: context.yyTextTertiary))),
        TextButton(
          onPressed: () { ref.read(sourcesProvider.notifier).removeSource(source.id); Navigator.pop(ctx); },
          child: const Text('确认删除', style: TextStyle(color: YYColors.statusError, fontWeight: FontWeight.bold))),
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

class _DiscoveredDeviceCard extends StatelessWidget {
  final DiscoveredDevice device;
  final VoidCallback onTap;
  const _DiscoveredDeviceCard({required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final typeColor = _SourcesPageState._typeColor(device.type);
    final icon = _SourcesPageState._typeIcon(device.type);

    return YYPanel(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: onTap,
      child: Row(
        children: [
          YYIconBadge(icon: icon, color: typeColor, size: 44),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(device.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('${device.host}:${device.port}', style: TextStyle(color: context.yyTextTertiary, fontSize: 12)),
              ],
            ),
          ),
          YYPillButton(label: '连接', onTap: onTap, primary: true, compact: true),
        ],
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  final SourceEntity source;
  final VoidCallback onTap;
  final VoidCallback onRescan;
  const _SourceCard({required this.source, required this.onTap, required this.onRescan});

  @override
  Widget build(BuildContext context) {
    final typeColor = _SourcesPageState._typeColor(source.type);
    final icon = _SourcesPageState._typeIcon(source.type);
    final statusColor = switch (source.status) {
      SourceStatus.connected => YYColors.statusSuccess,
      SourceStatus.connecting => YYColors.accentPrimary,
      SourceStatus.error => YYColors.statusError,
      SourceStatus.disconnected => context.yyTextTertiary,
    };

    return YYPanel(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: onTap,
      child: Row(
        children: [
          YYIconBadge(icon: icon, color: typeColor, size: 48),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(source.name.isNotEmpty ? source.name : source.typeDisplayName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(source.typeDisplayName, style: TextStyle(color: context.yyTextSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                    if (source.songCount > 0) ...[
                      Text(' · ', style: TextStyle(color: context.yyTextTertiary)),
                      Text('${source.songCount} 曲', style: TextStyle(color: context.yyTextTertiary, fontSize: 12)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const Icon(CupertinoIcons.chevron_right, size: 14, color: Colors.white24),
        ],
      ),
    );
  }
}

class _SourceTypePicker extends StatelessWidget {
  final ValueChanged<SourceType> onTypeSelected;
  const _SourceTypePicker({required this.onTypeSelected});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 36, height: 5, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 24),
          Text('选择源类型', style: context.yyTextTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 24),
          ..._types.map((t) => ListTile(
            enabled: t.ok,
            onTap: () => onTypeSelected(t.type),
            leading: YYIconBadge(icon: t.icon, color: t.ok ? t.color : Colors.grey, size: 40),
            title: Text(t.label, style: TextStyle(fontWeight: FontWeight.w700, color: t.ok ? Colors.white : Colors.white24)),
            subtitle: Text(t.subtitle, style: const TextStyle(fontSize: 12)),
            trailing: t.ok ? const Icon(CupertinoIcons.chevron_right, size: 14) : const Text('开发中', style: TextStyle(fontSize: 10, color: Colors.white12)),
          )),
        ],
      ),
    );
  }
}

class _SourceOptionsSheet extends StatelessWidget {
  final SourceEntity source;
  final ValueChanged<String> onOptionTap;
  const _SourceOptionsSheet({required this.source, required this.onOptionTap});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 36, height: 5, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 24),
          Row(
            children: [
              YYIconBadge(icon: _SourcesPageState._typeIcon(source.type), color: _SourcesPageState._typeColor(source.type), size: 54),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(source.name, style: context.yyTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    Text(source.typeDisplayName, style: TextStyle(color: context.yyTextSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _OptionItem(icon: CupertinoIcons.folder, label: '管理目录', onTap: () => onOptionTap('folder')),
          _OptionItem(icon: CupertinoIcons.refresh, label: '重新扫描', onTap: () => onOptionTap('rescan')),
          _OptionItem(icon: CupertinoIcons.tag, label: '元数据刮削', onTap: () => onOptionTap('scrape')),
          _OptionItem(icon: CupertinoIcons.pencil, label: '编辑连接', onTap: () => onOptionTap('edit')),
          _OptionItem(icon: CupertinoIcons.trash, label: '删除连接', color: YYColors.statusError, onTap: () => onOptionTap('delete')),
        ],
      ),
    );
  }
}

class _OptionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;
  const _OptionItem({required this.icon, required this.label, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color ?? Colors.white70, size: 22),
      title: Text(label, style: TextStyle(color: color ?? Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
    );
  }
}

class _ScanBar extends StatelessWidget {
  final SourcesState state;
  const _ScanBar({required this.state});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: GlassContainer(
        padding: const EdgeInsets.all(12),
        borderRadius: BorderRadius.circular(12),
        tintColor: YYColors.accentPrimary.withValues(alpha: 0.1),
        child: Row(
          children: [
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: YYColors.accentPrimary)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('正在同步媒体库...', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('${state.scannedCount} 个曲目已发现', style: TextStyle(color: context.yyTextSecondary, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyView({required this.onAdd});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const YYIconBadge(icon: CupertinoIcons.cloud_upload, color: Colors.white10, size: 80),
          const SizedBox(height: 24),
          Text('尚未建立连接', style: context.yyTextTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('连接你的 NAS 或本地目录\n开启无损音乐之旅', textAlign: TextAlign.center, style: TextStyle(color: context.yyTextSecondary)),
          const SizedBox(height: 32),
          YYPillButton(label: '立即添加', onTap: onAdd, primary: true),
        ],
      ),
    );
  }
}

extension on BuildContext {
  TextTheme get yyTextTheme => Theme.of(this).textTheme;
}


  void _showScrapeForSource(BuildContext context, WidgetRef ref, SourceEntity source) async {
    final db = ref.read(musicDatabaseProvider);
    final allSongs = await db.getAllSongs();
    final sourceSongs = allSongs.where((s) => s.sourceId == source.id).toList();
    if (sourceSongs.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('此数据源暂无歌曲'), behavior: SnackBarBehavior.floating));
      }
      return;
    }
    if (context.mounted) {
      showDialog(context: context, useRootNavigator: true, barrierDismissible: false,
        builder: (_) => _SourceScrapeDialog(ref: ref, sourceId: source.id, sourceName: source.name));
    }
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

  // 供外部组件调用的转发方法
  static IconData _typeIconForSourceType(SourceType t) => _typeIcon(t);
  static Color _typeColorForSourceType(SourceType t) => _typeColor(t);
}

// ─── 区域标题 ───
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _SectionHeader({required this.title, this.subtitle});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(color: YYColors.accentPrimary, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
      if (subtitle != null)
        Text(subtitle!, style: TextStyle(color: context.yyTextTertiary, fontSize: 11)),
    ]);
  }
}

// ─── 发现的设备卡片 ───
class _DiscoveredDeviceCard extends StatelessWidget {
  final DiscoveredDevice device;
  final VoidCallback onTap;
  const _DiscoveredDeviceCard({required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final typeColor = _SourcesPageState._typeColorForSourceType(device.type);
    final icon = _SourcesPageState._typeIconForSourceType(device.type);

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: typeColor.withValues(alpha: 0.25),
              ),
            ),
            child: Row(children: [
              Container(width: 44, height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [typeColor, typeColor.withValues(alpha: 0.7)]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: typeColor.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))]),
                child: Icon(icon, color: Colors.white, size: 20)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(device.name, style: TextStyle(color: context.yyTextPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text('${device.host}:${device.port}', style: TextStyle(color: context.yyTextTertiary, fontSize: 12)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8)),
                child: Text('添加', style: TextStyle(color: typeColor, fontSize: 12, fontWeight: FontWeight.w600))),
            ]),
          ),
        ),
      ),
    );
  }
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



  @override
  Widget build(BuildContext context) {
    final typeColor = _SourcesPageState._typeColor(source.type);
    final icon = _SourcesPageState._typeIcon(source.type);
    // 增强 null 安全的 detail 显示
    String detail;
    if (source.host != null && source.host!.trim().isNotEmpty) {
      detail = source.host!.trim();
      if (source.port != null && source.port! > 0) detail += ':${source.port}';
    } else if (source.path.isNotEmpty) {
      detail = source.path;
    } else {
      detail = source.typeDisplayName;
    }

    return GestureDetector(
      onTap: onTap,
      onLongPress: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.8)),
              boxShadow: [if (!context.isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))]),
            child: Row(children: [
              // 渐变图标
              Container(width: 48, height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [typeColor, typeColor.withValues(alpha: 0.7)]),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [BoxShadow(color: typeColor.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))]),
                child: Icon(icon, color: Colors.white, size: 22)),
              const SizedBox(width: 14),
              // 信息
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(source.name.isNotEmpty ? source.name : source.typeDisplayName,
                  style: TextStyle(color: context.yyTextPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text('${source.typeDisplayName} · $detail', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.yyTextTertiary, fontSize: 12)),
                if (source.songCount > 0) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: typeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                    child: Text('${source.songCount} 首', style: TextStyle(color: typeColor, fontSize: 11, fontWeight: FontWeight.w600))),
                ],
                if (source.errorMessage != null && source.errorMessage!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(source.errorMessage!, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: YYColors.statusError, fontSize: 11)),
                ],
              ])),
              const SizedBox(width: 8),
              // 状态指示器
              Container(width: 10, height: 10,
                decoration: BoxDecoration(color: _statusColor, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: _statusColor.withValues(alpha: 0.4), blurRadius: 4)])),
            ]),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  添加/编辑源页面 — 参照 my-nas AddSourceSheet（全屏页面版）
// ═══════════════════════════════════════════════════════════

class _TypeCfg {
  final String label;
  final String subtitle;
  final SourceType type;
  final IconData icon;
  final Color color;
  final bool ok;
  const _TypeCfg(this.label, this.subtitle, this.type, this.icon, this.color, {this.ok = true});
}

const _types = [
  _TypeCfg('群晖 NAS', 'Synology DSM 连接', SourceType.synology, CupertinoIcons.cube_box, Color(0xFF2196F3)),
  _TypeCfg('WebDAV', '通用 WebDAV 协议', SourceType.webdav, CupertinoIcons.globe, Color(0xFF43A047)),
  _TypeCfg('SMB/CIFS', '局域网文件共享', SourceType.smb, CupertinoIcons.desktopcomputer, Color(0xFFFF9800)),
  _TypeCfg('本地文件', '设备本地媒体库', SourceType.local, CupertinoIcons.folder, YYColors.accentPrimary),
  _TypeCfg('Jellyfin', '开源媒体服务器', SourceType.jellyfin, CupertinoIcons.play_rectangle, Color(0xFF9C27B0), ok: false),
  _TypeCfg('Emby', '媒体管理服务器', SourceType.emby, CupertinoIcons.dot_radiowaves_left_right, Color(0xFF00BCD4), ok: false),
  _TypeCfg('Plex', '个人媒体中心', SourceType.plex, CupertinoIcons.play, Color(0xFFE91E63), ok: false),
];

class AddSourcePage extends ConsumerStatefulWidget {
  final SourceEntity? existingSource;
  final SourceType preselectedType;
  final DiscoveredDevice? discoveredDevice;
  const AddSourcePage({super.key, this.existingSource, this.preselectedType = SourceType.synology, this.discoveredDevice});
  @override
  ConsumerState<AddSourcePage> createState() => _AddSourcePageState();
}

class _AddSourcePageState extends ConsumerState<AddSourcePage> {
  final _nameCtrl = TextEditingController();
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '5001');
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  // FocusNode 链式跳转，防止输入法消失
  late final FocusNode _nameFocus = FocusNode();
  late final FocusNode _hostFocus = FocusNode();
  late final FocusNode _portFocus = FocusNode();
  late final FocusNode _userFocus = FocusNode();
  late final FocusNode _passFocus = FocusNode();

  bool _ssl = true;
  bool _obscure = true;
  bool _submitting = false;
  String? _errorMsg;
  String? _deviceToken;

  bool get _editing => widget.existingSource != null;
  SourceType get _type => widget.preselectedType;
  _TypeCfg get _cfg => _types.firstWhere((t) => t.type == _type, orElse: () => _types.first);

  @override
  void initState() {
    super.initState();
    _portCtrl.text = _defaultPort(_type).toString();
    _ssl = _type == SourceType.synology || _type == SourceType.webdav;
    final src = widget.existingSource;
    if (src != null) {
      _nameCtrl.text = src.name;
      _hostCtrl.text = src.host ?? '';
      _portCtrl.text = (src.port ?? _defaultPort(_type)).toString();
      _userCtrl.text = src.username ?? '';
      _passCtrl.text = src.password ?? '';
      _ssl = src.useSsl;
      _deviceToken = src.deviceToken;
    }
    // 从发现设备预填
    final device = widget.discoveredDevice;
    if (device != null && src == null) {
      _hostCtrl.text = device.host;
      _portCtrl.text = device.port.toString();
      _nameCtrl.text = device.name;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _hostCtrl.dispose();
    _portCtrl.dispose(); _userCtrl.dispose(); _passCtrl.dispose();
    _nameFocus.dispose(); _hostFocus.dispose();
    _portFocus.dispose(); _userFocus.dispose(); _passFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _cfg;
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
            Expanded(child: Text(_editing ? '编辑源' : '添加${cfg.label}', style: TextStyle(
              color: context.yyTextPrimary, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5))),
          ]),
        ),

        // 表单
        Expanded(child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            // 类型标识头
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cfg.color.withValues(alpha: 0.12), cfg.color.withValues(alpha: 0.04)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cfg.color.withValues(alpha: 0.15))),
              child: Row(children: [
                Container(width: 44, height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [cfg.color, cfg.color.withValues(alpha: 0.7)]),
                    borderRadius: BorderRadius.circular(12)),
                  child: Icon(cfg.icon, color: Colors.white, size: 22)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(cfg.label, style: TextStyle(color: context.yyTextPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                  Text(cfg.subtitle, style: TextStyle(color: context.yyTextTertiary, fontSize: 12)),
                ])),
              ])),

            const SizedBox(height: 20),

            // 名称
            _FormField(label: '名称（可选）', hint: '例如: 我的 NAS', ctrl: _nameCtrl, icon: CupertinoIcons.tag,
              focusNode: _nameFocus, textInputAction: TextInputAction.next,
              onSubmitted: (_) => _hostFocus.requestFocus()),

            // 远程源字段
            if (_type != SourceType.local) ...[
              const SizedBox(height: 16),
              _FormField(label: '主机地址', hint: '192.168.1.100', ctrl: _hostCtrl, icon: CupertinoIcons.wifi,
                keyboardType: TextInputType.url, focusNode: _hostFocus, textInputAction: TextInputAction.next,
                onSubmitted: (_) => _type != SourceType.smb ? _portFocus.requestFocus() : _userFocus.requestFocus()),
              const SizedBox(height: 16),
              if (_type != SourceType.smb)
                Row(children: [
                  Expanded(child: _FormField(label: '端口', hint: '5001', ctrl: _portCtrl, icon: CupertinoIcons.number,
                    keyboardType: TextInputType.number, focusNode: _portFocus, textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _userFocus.requestFocus())),
                  const SizedBox(width: 16),
                  Column(children: [
                    Text('SSL', style: TextStyle(color: context.yyTextTertiary, fontSize: 12)),
                    const SizedBox(height: 4),
                    CupertinoSwitch(value: _ssl, onChanged: (v) => setState(() => _ssl = v),
                      activeTrackColor: YYColors.accentPrimary),
                  ]),
                ]),
              if (_type != SourceType.smb) const SizedBox(height: 16),

              _FormField(label: '用户名', hint: 'admin', ctrl: _userCtrl, icon: CupertinoIcons.person,
                focusNode: _userFocus, textInputAction: TextInputAction.next,
                onSubmitted: (_) => _passFocus.requestFocus()),
              const SizedBox(height: 16),
              _FormField(label: _editing ? '密码（留空保持不变）' : '密码', hint: '••••••', ctrl: _passCtrl,
                icon: CupertinoIcons.lock, obscure: _obscure,
                focusNode: _passFocus, textInputAction: TextInputAction.done,
                onSubmitted: (_) { FocusScope.of(context).unfocus(); },
                suffix: GestureDetector(onTap: () => setState(() => _obscure = !_obscure),
                  child: Icon(_obscure ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                    color: context.yyTextTertiary, size: 18))),
            ],

            // 本地路径提示
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

            // 添加后设置扫描目录提示
            if (!_editing) ...[
              const SizedBox(height: 12),
              Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: YYColors.accentPrimary.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Icon(CupertinoIcons.folder_badge_plus, color: YYColors.accentPrimary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text('添加后可选择要扫描的文件夹',
                    style: TextStyle(color: YYColors.accentPrimary, fontSize: 12, fontWeight: FontWeight.w500))),
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
                  : Text(_editing ? '保存' : '连接',
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
          name: _name,
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
        case SourceType.local: await n.addLocalSource(_name, '/'); break;
        case SourceType.webdav: await n.addWebDavSource(name: _name,
            url: '${_ssl ? "https" : "http"}://${_hostCtrl.text.trim()}:${_portCtrl.text.trim()}',
            username: _userCtrl.text.trim().isNotEmpty ? _userCtrl.text.trim() : null,
            password: _passCtrl.text.trim().isNotEmpty ? _passCtrl.text.trim() : null); break;
        case SourceType.synology:
          final n2 = ref.read(sourcesProvider.notifier);
          final host = _hostCtrl.text.trim();
          final port = int.tryParse(_portCtrl.text.trim()) ?? 5001;
          final username = _userCtrl.text.trim();
          final password = _passCtrl.text.trim();

          // 步骤1: 尝试登录（可能需要 OTP）
          var loginResult = await n2.synologyLogin(
            SourceEntity(
              id: 'temp', name: _name, type: SourceType.synology, path: '/',
              host: host, port: port, username: username, password: password,
              useSsl: _ssl, deviceToken: _deviceToken,
            ),
          );

          // 步骤2: 处理 OTP
          String? deviceId = loginResult.deviceId;
          String? otpCode;
          if (loginResult.status == SynologyLoginStatus.otpRequired) {
            if (!mounted) return;
            while (true) {
              final otpResult = await _showOtpSheet(context);
              if (otpResult == null) return; // 用户取消
              otpCode = otpResult.$1;
              loginResult = await n2.synologyLogin(
                SourceEntity(
                  id: 'temp', name: _name, type: SourceType.synology, path: '/',
                  host: host, port: port, username: username, password: password,
                  useSsl: _ssl, deviceToken: _deviceToken,
                ),
                otpCode: otpCode,
              );
              if (loginResult.status == SynologyLoginStatus.success) {
                deviceId = loginResult.deviceId;
                break;
              } else if (loginResult.status == SynologyLoginStatus.otpRequired) {
                if (!mounted) return;
                continue; // OTP 错误，重试
              } else {
                setState(() => _errorMsg = loginResult.errorMessage ?? 'OTP 验证失败');
                return;
              }
            }
          } else if (loginResult.status == SynologyLoginStatus.failed) {
            setState(() => _errorMsg = loginResult.errorMessage ?? '连接失败');
            return;
          }

          // 步骤3: 登录成功，列出共享文件夹
          if (loginResult.sid == null) {
            setState(() => _errorMsg = '获取会话失败');
            return;
          }

          List<String> folders;
          try {
            folders = await n2.listSynologyFolders(
              SourceEntity(
                id: 'temp', name: _name, type: SourceType.synology, path: '/',
                host: host, port: port, username: username, password: password,
                useSsl: _ssl,
              ),
              loginResult.sid!,
            );
          } catch (e) {
            setState(() => _errorMsg = '获取文件夹列表失败: $e');
            return;
          }

          if (!mounted) return;

          // 步骤4: 弹出文件夹选择面板
          final selectedPaths = await showModalBottomSheet<List<String>>(
            context: context,
            isScrollControlled: true,
            backgroundColor: context.yyBgElevated,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            builder: (ctx) => _FolderSelectSheet(folders: folders),
          );

          if (selectedPaths == null || selectedPaths.isEmpty || !mounted) return;

          // 步骤5: 保存源
          final sourceId = await n.addSynologySource(
            name: _name, host: host, port: port,
            username: username, password: password,
            folderPath: selectedPaths.first, useSsl: _ssl,
            deviceToken: deviceId, otpCode: otpCode,
            scanPaths: selectedPaths,
          );

          // 步骤6: 跳转文件夹管理页（可触发扫描）
          if (mounted) {
            final sources = ref.read(sourcesProvider).sources;
            final newSource = sources.firstWhere((s) => s.id == sourceId, orElse: () => sources.last);
            Navigator.pop(context);
            Navigator.of(context).push(CupertinoPageRoute(
              builder: (_) => _FolderManagerPage(source: newSource)));
          }
          return; // 群晖流程已处理完毕，不走下面通用逻辑

        case SourceType.smb:
          await n.addSmbSource(name: _name, host: _hostCtrl.text.trim(),
            port: int.tryParse(_portCtrl.text.trim()) ?? 445, sharePath: '/',
            username: _userCtrl.text.trim().isNotEmpty ? _userCtrl.text.trim() : null,
            password: _passCtrl.text.trim().isNotEmpty ? _passCtrl.text.trim() : null);
          break;
        default: break;
      }

      // 非群晖源：添加成功后跳转文件夹管理页
      if (mounted) {
        final sources = ref.read(sourcesProvider).sources;
        final newSource = sources.isNotEmpty ? sources.last : null;
        Navigator.pop(context);
        if (newSource != null) {
          Navigator.of(context).push(CupertinoPageRoute(
            builder: (_) => _FolderManagerPage(source: newSource)));
        }
      }
    } catch (e) {
      setState(() => _errorMsg = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String get _name {
    final n = _nameCtrl.text.trim();
    if (n.isNotEmpty) return n;
    return _cfg.label;
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
  // 返回 (otpCode, rememberDevice)
  Future<(String, bool)?> _showOtpSheet(BuildContext context) async {
    return showModalBottomSheet<(String, bool)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: true,
      builder: (ctx) => _OtpSheet(sourceName: _name),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  文件夹选择面板 — 群晖登录成功后展示文件夹列表
// ═══════════════════════════════════════════════════════════

class _FolderSelectSheet extends StatefulWidget {
  final List<String> folders;
  const _FolderSelectSheet({required this.folders});
  @override
  State<_FolderSelectSheet> createState() => _FolderSelectSheetState();
}

class _FolderSelectSheetState extends State<_FolderSelectSheet> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // 拖拽条
        Container(margin: const EdgeInsets.only(top: 12, bottom: 8), width: 40, height: 4,
          decoration: BoxDecoration(color: context.isDark ? Colors.grey[600] : Colors.grey[400],
            borderRadius: BorderRadius.circular(2))),

        // 标题
        Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('选择扫描文件夹', style: TextStyle(
                color: context.yyTextPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text('选择一个或多个文件夹作为音乐来源', style: TextStyle(
                color: context.yyTextTertiary, fontSize: 13)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: YYColors.accentPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
              child: Text('已选 ${_selected.length}', style: const TextStyle(
                color: YYColors.accentPrimary, fontSize: 12, fontWeight: FontWeight.w600))),
          ])),

        const SizedBox(height: 8),

        // 文件夹列表
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
          child: widget.folders.isEmpty
            ? Padding(padding: const EdgeInsets.all(40),
                child: Column(children: [
                  Icon(CupertinoIcons.folder, size: 48, color: context.yyTextTertiary),
                  const SizedBox(height: 12),
                  Text('未发现共享文件夹', style: TextStyle(color: context.yyTextTertiary, fontSize: 15)),
                ]))
            : ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: widget.folders.length,
                itemBuilder: (_, i) {
                  final folder = widget.folders[i];
                  final isSelected = _selected.contains(folder);
                  return GestureDetector(
                    onTap: () => setState(() {
                      isSelected ? _selected.remove(folder) : _selected.add(folder);
                    }),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                          ? YYColors.accentPrimary.withValues(alpha: 0.1)
                          : (context.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                            ? YYColors.accentPrimary.withValues(alpha: 0.4)
                            : (context.isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06)))),
                      child: Row(children: [
                        Icon(CupertinoIcons.folder_fill,
                          color: isSelected ? YYColors.accentPrimary : context.yyTextTertiary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(child: Text(folder, style: TextStyle(
                          color: isSelected ? YYColors.accentPrimary : context.yyTextPrimary,
                          fontSize: 15, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400))),
                        if (isSelected)
                          const Icon(CupertinoIcons.checkmark_circle_fill, color: YYColors.accentPrimary, size: 20)
                        else
                          Icon(CupertinoIcons.circle, color: context.yyTextTertiary.withValues(alpha: 0.4), size: 20),
                      ]),
                    ),
                  );
                },
              ),
        ),

        // 确认按钮
        Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: GestureDetector(
            onTap: _selected.isEmpty ? null : () => Navigator.pop(context, _selected.toList()),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _selected.isEmpty
                  ? YYColors.accentPrimary.withValues(alpha: 0.3)
                  : YYColors.accentPrimary,
                borderRadius: BorderRadius.circular(14),
                boxShadow: _selected.isNotEmpty
                  ? [BoxShadow(color: YYColors.accentPrimary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))]
                  : null),
              child: Center(child: Text(
                _selected.isEmpty ? '请至少选择一个文件夹' : '确认（${_selected.length} 个文件夹）',
                style: TextStyle(
                  color: _selected.isEmpty ? Colors.white.withValues(alpha: 0.5) : Colors.white,
                  fontSize: 16, fontWeight: FontWeight.w700))),
            ),
          ),
        ),
      ]),
    ));
  }
}

// ═══════════════════════════════════════════════════════════
//  文件夹管理页 — 管理数据源的扫描目录
// ═══════════════════════════════════════════════════════════

class _FolderManagerPage extends ConsumerStatefulWidget {
  final SourceEntity source;
  const _FolderManagerPage({required this.source});
  @override
  ConsumerState<_FolderManagerPage> createState() => _FolderManagerPageState();
}

class _FolderManagerPageState extends ConsumerState<_FolderManagerPage> {
  List<String> _selectedPaths = [];
  List<String> _remoteFolders = [];
  bool _loading = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedPaths = List.from(widget.source.scanPaths);
    if (widget.source.type == SourceType.synology) {
      _loadRemoteFolders();
    }
  }

  Future<void> _loadRemoteFolders() async {
    setState(() { _loading = true; _error = null; });
    try {
      final n = ref.read(sourcesProvider.notifier);
      var loginResult = await n.synologyLogin(widget.source);

      // 需要 OTP 验证
      if (loginResult.status == SynologyLoginStatus.otpRequired) {
        if (!mounted) return;
        // OTP 循环 — 如果 OTP 错误则在 Sheet 中重试
        while (true) {
          final otpResult = await _showOtpSheet(context);
          if (otpResult == null) {
            setState(() { _loading = false; _error = '已取消二级验证'; });
            return;
          }
          final otpCode = otpResult.$1;
          loginResult = await n.synologyLogin(widget.source, otpCode: otpCode);
          if (loginResult.status == SynologyLoginStatus.success) {
            // OTP 验证成功 — 保存 deviceToken 到源
            if (loginResult.deviceId != null) {
              final updatedSource = widget.source.copyWith(deviceToken: loginResult.deviceId);
              await n.editSource(updatedSource);
            }
            break;
          } else if (loginResult.status == SynologyLoginStatus.otpRequired) {
            // OTP 错误 — 继续循环让用户重新输入
            if (!mounted) return;
            continue;
          } else {
            // 其他错误
            setState(() { _loading = false; _error = loginResult.errorMessage ?? 'OTP 验证失败'; });
            return;
          }
        }
      } else if (loginResult.status == SynologyLoginStatus.failed) {
        setState(() { _loading = false; _error = loginResult.errorMessage ?? '登录失败'; });
        return;
      }

      if (loginResult.sid != null) {
        final folders = await n.listSynologyFolders(widget.source, loginResult.sid!);
        setState(() => _remoteFolders = folders);
      } else {
        setState(() => _error = '获取会话失败');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    }
    setState(() => _loading = false);
  }

  /// OTP 底部面板
  Future<(String, bool)?> _showOtpSheet(BuildContext context) async {
    return showModalBottomSheet<(String, bool)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: true,
      builder: (ctx) => _OtpSheet(sourceName: widget.source.name),
    );
  }

  void _toggleFolder(String path) {
    setState(() {
      if (_selectedPaths.contains(path)) {
        _selectedPaths.remove(path);
      } else {
        _selectedPaths.add(path);
      }
    });
  }

  Future<void> _save({bool rescan = false}) async {
    setState(() => _saving = true);
    final n = ref.read(sourcesProvider.notifier);
    await n.updateScanPaths(widget.source.id, _selectedPaths);
    if (rescan) {
      n.scanSource(widget.source.id);
    }
    if (mounted) Navigator.pop(context);
  }

  void _showAddManualPath() {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: context.yyBgElevated,
      title: Text('添加路径', style: TextStyle(color: context.yyTextPrimary, fontSize: 17)),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        style: TextStyle(color: context.yyTextPrimary),
        decoration: InputDecoration(
          hintText: '/volume1/music',
          hintStyle: TextStyle(color: context.yyTextTertiary),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
          child: Text('取消', style: TextStyle(color: context.yyTextTertiary))),
        TextButton(onPressed: () {
          final path = ctrl.text.trim();
          if (path.isNotEmpty && !_selectedPaths.contains(path)) {
            setState(() => _selectedPaths.add(path));
          }
          Navigator.pop(ctx);
        }, child: const Text('添加', style: TextStyle(color: YYColors.accentPrimary))),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = _SourcesPageState._typeColor(widget.source.type);
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
            Expanded(child: Text('扫描目录', style: TextStyle(
              color: context.yyTextPrimary, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5))),
            GestureDetector(
              onTap: _showAddManualPath,
              child: Container(padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: YYColors.accentPrimary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: const Icon(CupertinoIcons.add, color: YYColors.accentPrimary, size: 20))),
          ]),
        ),

        Expanded(child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          children: [
            // 数据源信息
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                Container(width: 40, height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [typeColor, typeColor.withValues(alpha: 0.7)]),
                    borderRadius: BorderRadius.circular(10)),
                  child: Icon(_SourcesPageState._typeIcon(widget.source.type), color: Colors.white, size: 18)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.source.name, style: TextStyle(color: context.yyTextPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                  Text('选择需要扫描音乐的文件夹', style: TextStyle(color: context.yyTextTertiary, fontSize: 12)),
                ])),
              ])),

            const SizedBox(height: 16),

            // 已选择的路径
            if (_selectedPaths.isNotEmpty) ...[
              Text('已选目录', style: TextStyle(color: context.yyTextPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ..._selectedPaths.map((p) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: YYColors.accentPrimary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: YYColors.accentPrimary.withValues(alpha: 0.15))),
                child: Row(children: [
                  const Icon(CupertinoIcons.folder_fill, color: YYColors.accentPrimary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(p, style: TextStyle(color: context.yyTextPrimary, fontSize: 14))),
                  GestureDetector(
                    onTap: () => setState(() => _selectedPaths.remove(p)),
                    child: Icon(CupertinoIcons.xmark_circle_fill, color: context.yyTextTertiary, size: 18)),
                ]),
              )),
              const SizedBox(height: 16),
            ],

            // 远程文件夹列表（群晖）
            if (widget.source.type == SourceType.synology) ...[
              Text('共享文件夹', style: TextStyle(color: context.yyTextPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              if (_loading)
                const Center(child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(strokeWidth: 2, color: YYColors.accentPrimary)))
              else if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: YYColors.statusError.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const Icon(CupertinoIcons.xmark_circle, color: YYColors.statusError, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_error!, style: const TextStyle(color: YYColors.statusError, fontSize: 13))),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _loadRemoteFolders,
                      child: const Text('重试', style: TextStyle(color: YYColors.accentPrimary, fontSize: 13, fontWeight: FontWeight.w600))),
                  ]))
              else
                ..._remoteFolders.map((folder) {
                  final isSelected = _selectedPaths.contains('/$folder');
                  return GestureDetector(
                    onTap: () => _toggleFolder('/$folder'),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                          ? YYColors.accentPrimary.withValues(alpha: 0.1)
                          : (context.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isSelected
                          ? YYColors.accentPrimary.withValues(alpha: 0.3)
                          : (context.isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06)))),
                      child: Row(children: [
                        Icon(CupertinoIcons.folder, color: isSelected ? YYColors.accentPrimary : context.yyTextSecondary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text(folder, style: TextStyle(
                          color: isSelected ? YYColors.accentPrimary : context.yyTextPrimary,
                          fontSize: 14, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400))),
                        Icon(isSelected ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
                          color: isSelected ? YYColors.accentPrimary : context.yyTextTertiary, size: 20),
                      ])),
                  );
                }),
            ],

            // 空状态提示
            if (_selectedPaths.isEmpty && _remoteFolders.isEmpty && !_loading)
              Container(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  Icon(CupertinoIcons.folder_badge_plus, size: 44, color: context.yyTextTertiary),
                  const SizedBox(height: 10),
                  Text('未选择扫描目录', style: TextStyle(color: context.yyTextTertiary, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('不选择则扫描全部文件', style: TextStyle(color: context.yyTextTertiary, fontSize: 12)),
                ])),
          ],
        )),

        // 底部操作栏
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Row(children: [
            Expanded(child: GestureDetector(
              onTap: _saving ? null : () => _save(rescan: false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: context.isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14)),
                child: Center(child: Text('仅保存', style: TextStyle(
                  color: context.yyTextPrimary, fontSize: 15, fontWeight: FontWeight.w600)))),
            )),
            const SizedBox(width: 12),
            Expanded(child: GestureDetector(
              onTap: _saving ? null : () => _save(rescan: true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: YYColors.accentPrimary,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: YYColors.accentPrimary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))]),
                child: Center(child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('保存并扫描', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)))),
            )),
          ]),
        ),
      ])),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  OTP 验证面板 — 参照 my-nas _TwoFASheetWithVerify
//  DraggableScrollableSheet + BackdropFilter + 自动提交 + 抖动
// ═══════════════════════════════════════════════════════════

class _OtpSheet extends StatefulWidget {
  final String sourceName;
  const _OtpSheet({required this.sourceName});
  @override
  State<_OtpSheet> createState() => _OtpSheetState();
}

class _OtpSheetState extends State<_OtpSheet> with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _remember = true;
  bool _hasError = false;
  String? _errorMsg;

  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _scaleAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack);
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10, end: -10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut));
    _animCtrl.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    if (_hasError) setState(() { _hasError = false; _errorMsg = null; });
    setState(() {}); // refresh visual grid
    if (v.length == 6) _submit();
  }

  void _submit() {
    final code = _ctrl.text;
    if (code.length != 6) {
      _showError('请输入完整的 6 位验证码');
      return;
    }
    Navigator.pop(context, (code, _remember));
  }

  void _showError(String msg) {
    setState(() { _hasError = true; _errorMsg = msg; });
    HapticFeedback.heavyImpact();
    _ctrl.clear();
    _animCtrl..reset()..forward();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final code = _ctrl.text;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.52,
        minChildSize: 0.4,
        maxChildSize: 0.75,
        builder: (ctx, scrollCtrl) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: ctx.isDark
                  ? const Color(0xFF1C1C1E).withValues(alpha: 0.95)
                  : Colors.white.withValues(alpha: 0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: ctx.isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08))),
              child: Column(children: [
                // 拖动条
                Center(child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8), width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: ctx.isDark ? Colors.grey[600] : Colors.grey[400],
                    borderRadius: BorderRadius.circular(2)))),
                // 内容
                Expanded(child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  children: [
                    // 图标
                    Center(child: ScaleTransition(
                      scale: _scaleAnim,
                      child: Container(
                        width: 72, height: 72,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: YYColors.accentGradient,
                          boxShadow: [BoxShadow(color: YYColors.accentPrimary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))]),
                        child: const Icon(CupertinoIcons.lock_shield_fill, size: 36, color: Colors.white)))),
                    // 标题
                    Text('二次验证', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: ctx.yyTextPrimary)),
                    const SizedBox(height: 6),
                    Text('请输入「${widget.sourceName}」的验证码',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: ctx.yyTextTertiary)),
                    const SizedBox(height: 24),

                    // 隐藏的真实输入框 + 视觉分格
                    Stack(children: [
                      // 隐藏的 TextField
                      Opacity(opacity: 0, child: SizedBox(height: 64, child: TextField(
                        controller: _ctrl,
                        focusNode: _focusNode,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        autofocus: true,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                        onChanged: _onChanged,
                        decoration: const InputDecoration(counterText: ''),
                      ))),
                      // 视觉分格
                      GestureDetector(
                        onTap: () => _focusNode.requestFocus(),
                        child: AnimatedBuilder(
                          animation: _shakeAnim,
                          builder: (ctx, child) => Transform.translate(offset: Offset(_shakeAnim.value, 0), child: child),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(6, (i) {
                              final filled = i < code.length;
                              final active = i == code.length && _focusNode.hasFocus;
                              return Container(
                                width: 48, height: 60,
                                margin: EdgeInsets.only(left: i == 0 ? 0 : (i == 3 ? 14 : 6)),
                                decoration: BoxDecoration(
                                  color: filled
                                    ? YYColors.accentPrimary.withValues(alpha: ctx.isDark ? 0.12 : 0.08)
                                    : (ctx.isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.03)),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _hasError ? YYColors.statusError
                                      : active ? YYColors.accentPrimary
                                      : filled ? YYColors.accentPrimary.withValues(alpha: 0.3)
                                      : (ctx.isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08)),
                                    width: active ? 2 : 1)),
                                child: Center(child: filled
                                  ? Text(code[i], style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: ctx.yyTextPrimary))
                                  : active
                                    ? Container(width: 2, height: 24, decoration: BoxDecoration(
                                        color: YYColors.accentPrimary, borderRadius: BorderRadius.circular(1)))
                                    : null),
                              );
                            })),
                        ),
                      ),
                    ]),

                    // 错误
                    if (_hasError && _errorMsg != null) ...[
                      const SizedBox(height: 12),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(CupertinoIcons.xmark_circle, color: YYColors.statusError, size: 16),
                        const SizedBox(width: 4),
                        Text(_errorMsg!, style: const TextStyle(color: YYColors.statusError, fontSize: 13)),
                      ]),
                    ],
                    const SizedBox(height: 20),

                    // 记住设备
                    GestureDetector(
                      onTap: () => setState(() => _remember = !_remember),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(_remember ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
                          size: 18, color: _remember ? YYColors.accentPrimary : ctx.yyTextTertiary),
                        const SizedBox(width: 6),
                        Text('记住此设备', style: TextStyle(
                          color: _remember ? YYColors.accentPrimary : ctx.yyTextTertiary, fontSize: 13)),
                      ])),
                    const SizedBox(height: 20),

                    // 验证按钮
                    GestureDetector(
                      onTap: _submit,
                      child: Container(
                        width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(color: YYColors.accentPrimary, borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: YYColors.accentPrimary.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))]),
                        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(CupertinoIcons.checkmark_shield_fill, size: 18, color: Colors.white),
                          SizedBox(width: 6),
                          Text('验证', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                        ]))),
                    const SizedBox(height: 8),
                    // 取消
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: Text('取消', style: TextStyle(color: ctx.yyTextTertiary, fontSize: 14))))),
                  ],
                )),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  数据源级元数据刮削对话框
// ═══════════════════════════════════════════════════════════

class _SourceScrapeDialog extends StatefulWidget {
  final WidgetRef ref;
  final String sourceId, sourceName;
  const _SourceScrapeDialog({required this.ref, required this.sourceId, required this.sourceName});
  @override
  State<_SourceScrapeDialog> createState() => _SourceScrapeDialogState();
}

class _SourceScrapeDialogState extends State<_SourceScrapeDialog> {
  int _total = 0, _current = 0, _updated = 0, _skipped = 0;
  String _currentSong = '';
  bool _done = false, _cancelled = false;
  final bool _onlyMissing = true;

  @override
  void initState() { super.initState(); _run(); }

  Future<void> _run() async {
    final db = widget.ref.read(musicDatabaseProvider);
    final scraper = MetadataScraper();
    final allSongs = await db.getAllSongs();
    final sourceSongs = allSongs.where((s) => s.sourceId == widget.sourceId).toList();
    setState(() => _total = sourceSongs.length);

    for (int i = 0; i < sourceSongs.length; i++) {
      if (_cancelled) break;
      final song = sourceSongs[i];

      if (_onlyMissing && _missingScore(song) == 0) {
        setState(() { _current = i + 1; _skipped++; });
        continue;
      }

      setState(() { _current = i + 1; _currentSong = song.title; });
      try {
        final enriched = await scraper.scrape(song);
        if (enriched != null) { await db.updateSong(enriched); setState(() => _updated++); }
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
    return AlertDialog(
      backgroundColor: context.yyBgElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        Container(width: 28, height: 28,
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFEF4444)]),
            borderRadius: BorderRadius.circular(7)),
          child: const Icon(CupertinoIcons.tag_fill, color: Colors.white, size: 14)),
        const SizedBox(width: 8),
        Expanded(child: Text(_done ? '刮削完成' : '刮削「${widget.sourceName}」',
          style: TextStyle(color: context.yyTextPrimary, fontSize: 16, fontWeight: FontWeight.w700),
          maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!_done) ...[
          ClipRRect(borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: _total > 0 ? _current / _total : null,
              color: YYColors.accentPrimary, minHeight: 6,
              backgroundColor: context.yyTextTertiary.withValues(alpha: 0.12))),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Text('$_current / $_total', style: TextStyle(color: context.yyTextPrimary, fontSize: 14, fontWeight: FontWeight.w600))),
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
              child: Text('更新 $_updated', style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w600))),
            if (_skipped > 0) ...[
              const SizedBox(width: 4),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: context.yyTextTertiary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text('跳过 $_skipped', style: TextStyle(color: context.yyTextTertiary, fontSize: 11, fontWeight: FontWeight.w600))),
            ],
          ]),
          const SizedBox(height: 6),
          Text(_currentSong, style: TextStyle(color: context.yyTextTertiary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
        ] else
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(CupertinoIcons.checkmark_circle_fill, color: Color(0xFF10B981), size: 18),
              const SizedBox(width: 6),
              Text('更新 $_updated / $_total 首', style: TextStyle(color: context.yyTextPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
            ]),
            if (_skipped > 0) ...[
              const SizedBox(height: 6),
              Text('跳过 $_skipped 首（元数据完整）', style: TextStyle(color: context.yyTextTertiary, fontSize: 12)),
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

// ─── 表单输入框 ───
class _FormField extends StatelessWidget {
  final String label, hint;
  final TextEditingController ctrl;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscure;
  final Widget? suffix;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  const _FormField({required this.label, required this.hint, required this.ctrl, required this.icon,
    this.keyboardType, this.obscure = false, this.suffix, this.focusNode, this.textInputAction, this.onSubmitted});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 10),
        child: Text(label.toUpperCase(), style: const TextStyle(color: Colors.white24, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
      ),
      YYPanel(
        padding: EdgeInsets.zero,
        child: TextField(
          controller: ctrl,
          obscureText: obscure,
          keyboardType: keyboardType,
          focusNode: focusNode,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white12),
            prefixIcon: Icon(icon, color: YYColors.accentPrimary.withValues(alpha: 0.5), size: 20),
            suffixIcon: suffix,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ),
    ]);
  }
}
