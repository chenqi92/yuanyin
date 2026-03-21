import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../app/l10n/strings.dart';
import '../../../../app/theme/theme.dart';
import '../../../../shared/widgets/modern_music_ui.dart';
import '../../data/services/settings_service.dart';
import '../../../library/presentation/providers/library_provider.dart';
import '../../../player/data/services/sleep_timer_service.dart';
import '../../../library/data/services/metadata_scraper.dart';
import '../../../sources/presentation/providers/source_provider.dart';

/// 设置页 — v3 重新组织
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final library = ref.watch(libraryProvider);
    final sources = ref.watch(sourcesProvider);
    final sleepTimer = ref.watch(sleepTimerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgElevated = isDark ? YYColors.bgElevated : YYLightColors.bgElevated;
    final textPrimary = isDark
        ? YYColors.textPrimary
        : YYLightColors.textPrimary;
    final textSecondary = isDark
        ? YYColors.textSecondary
        : YYLightColors.textSecondary;
    final textTertiary = isDark
        ? YYColors.textTertiary
        : YYLightColors.textTertiary;
    final separator = isDark ? YYColors.separator : YYLightColors.separator;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: YYScenicBackground(
        accent: YYColors.accentPrimary,
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 28),
            children: [
              YYPageHeader(
                eyebrow: '系统偏好',
                title: '设置',
                subtitle: '播放引擎、主题、缓存和数据源，都在这里统一管理。',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _SettingsSnapshotCard(
                  themeMode: settings.themeMode,
                  engine: settings.engine,
                  songCount: library.stats.songCount,
                  sourceCount: sources.sources.length,
                  sleepLabel: sleepTimer.isActive
                      ? '${sleepTimer.remaining.inMinutes}m'
                      : '关闭',
                ),
              ),
              const SizedBox(height: 18),
              const YYSectionTitle(
                title: '数据源与扫描',
                subtitle: '先管理入口，再处理重扫和连接状态',
              ),
              _SettingsCard(
                bgElevated: bgElevated,
                children: [
                  _SettingsRow(
                    icon: CupertinoIcons.folder,
                    iconColor: YYColors.accentPrimary,
                    title: '数据源管理',
                    subtitle: '添加、编辑 NAS / WebDAV / 本地文件夹',
                    onTap: () => context.push('/sources'),
                    showArrow: true,
                    textPrimary: textPrimary,
                    textTertiary: textTertiary,
                  ),
                ],
              ),

              const SizedBox(height: 20),
              const YYSectionTitle(title: '曲库维护', subtitle: '元数据、封面和播放统计都在这里'),
              _SettingsCard(
                bgElevated: bgElevated,
                children: [
                  _SettingsRow(
                    icon: CupertinoIcons.arrow_2_circlepath,
                    iconColor: const Color(0xFF10B981),
                    title: '重新扫描音乐库',
                    subtitle: '扫描所有数据源以更新歌曲列表',
                    onTap: () => _rescanLibrary(context, ref),
                    showArrow: true,
                    textPrimary: textPrimary,
                    textTertiary: textTertiary,
                  ),
                  Divider(
                    height: 1,
                    color: separator,
                    indent: 64,
                    endIndent: 18,
                  ),
                  _SettingsRow(
                    icon: CupertinoIcons.tag,
                    iconColor: const Color(0xFFF59E0B),
                    title: '元数据刮削',
                    subtitle: '从在线数据库匹配并补全歌曲信息',
                    onTap: () => _batchScrape(context, ref, false),
                    showArrow: true,
                    textPrimary: textPrimary,
                    textTertiary: textTertiary,
                  ),
                  Divider(
                    height: 1,
                    color: separator,
                    indent: 64,
                    endIndent: 18,
                  ),
                  _SettingsRow(
                    icon: CupertinoIcons.photo,
                    iconColor: const Color(0xFFEC4899),
                    title: '封面获取',
                    subtitle: '自动从网络下载专辑封面',
                    onTap: () => _batchScrape(context, ref, true),
                    showArrow: true,
                    textPrimary: textPrimary,
                    textTertiary: textTertiary,
                  ),
                  Divider(
                    height: 1,
                    color: separator,
                    indent: 64,
                    endIndent: 18,
                  ),
                  _SettingsRow(
                    icon: CupertinoIcons.chart_bar_alt_fill,
                    iconColor: const Color(0xFF8B5CF6),
                    title: '播放统计',
                    subtitle: '查看播放次数和时长排行',
                    onTap: () => context.push('/stats'),
                    showArrow: true,
                    textPrimary: textPrimary,
                    textTertiary: textTertiary,
                  ),
                ],
              ),

              const SizedBox(height: 20),
              const YYSectionTitle(title: '播放体验', subtitle: '控制引擎、淡入淡出和均衡器细节'),
              _SettingsCard(
                bgElevated: bgElevated,
                children: [
                  _SettingsRow(
                    icon: CupertinoIcons.waveform,
                    iconColor: const Color(0xFF06B6D4),
                    title: '播放引擎',
                    subtitle: settings.engine == 'just_audio'
                        ? 'just_audio (原生)'
                        : 'media_kit (FFmpeg)',
                    onTap: () => _showEngineSelector(
                      context,
                      ref,
                      settings.engine,
                      bgElevated,
                      textPrimary,
                      textTertiary,
                      separator,
                    ),
                    showArrow: true,
                    textPrimary: textPrimary,
                    textTertiary: textTertiary,
                  ),
                  Divider(
                    height: 1,
                    color: separator,
                    indent: 64,
                    endIndent: 18,
                  ),
                  // 交叉淡化
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF8B5CF6,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            CupertinoIcons.arrow_right_arrow_left,
                            color: Color(0xFF8B5CF6),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '交叉淡化',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Slider(
                            value: settings.crossfadeDuration,
                            min: 0,
                            max: 5,
                            divisions: 10,
                            onChanged: (v) => ref
                                .read(settingsProvider.notifier)
                                .setCrossfade(v),
                          ),
                        ),
                        SizedBox(
                          width: 36,
                          child: Text(
                            settings.crossfadeDuration > 0
                                ? '${settings.crossfadeDuration.toStringAsFixed(1)}s'
                                : '关',
                            style: TextStyle(color: textTertiary, fontSize: 12),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: separator,
                    indent: 64,
                    endIndent: 18,
                  ),
                  _SettingsRow(
                    icon: CupertinoIcons.waveform_path_ecg,
                    iconColor: const Color(0xFFEC4899),
                    title: '均衡器',
                    subtitle: '5 段 EQ 调节与预设',
                    onTap: () => context.push('/equalizer'),
                    showArrow: true,
                    textPrimary: textPrimary,
                    textTertiary: textTertiary,
                  ),
                ],
              ),

              const SizedBox(height: 20),
              YYSectionTitle(
                title: '定时关闭',
                subtitle: sleepTimer.isActive
                    ? '剩余 ${sleepTimer.remaining.inMinutes} 分 ${sleepTimer.remaining.inSeconds % 60} 秒'
                    : '选一个时间点，让播放自动收尾',
              ),
              _SettingsCard(
                bgElevated: bgElevated,
                children: [
                  Consumer(
                    builder: (ctx, ref2, _) {
                      final timer = ref2.watch(sleepTimerProvider);
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: timer.isActive
                            ? Row(
                                children: [
                                  const YYIconBadge(
                                    icon: CupertinoIcons.moon_fill,
                                    color: YYColors.accentPrimary,
                                    size: 36,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      '剩余 ${timer.remaining.inMinutes} 分 ${timer.remaining.inSeconds % 60} 秒',
                                      style: TextStyle(
                                        color: textPrimary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  YYPillButton(
                                    label: '取消',
                                    compact: true,
                                    onTap: () => ref2
                                        .read(sleepTimerProvider.notifier)
                                        .cancelTimer(),
                                  ),
                                ],
                              )
                            : Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [15, 30, 45, 60, 90].map((min) {
                                  return YYPillButton(
                                    label: '$min 分钟',
                                    compact: true,
                                    onTap: () => ref2
                                        .read(sleepTimerProvider.notifier)
                                        .startTimer(Duration(minutes: min)),
                                  );
                                }).toList(),
                              ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 20),
              const YYSectionTitle(title: '外观与语言', subtitle: '主题和语言会即时切换'),
              _SettingsCard(
                bgElevated: bgElevated,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: YYColors.accentPrimary.withValues(
                              alpha: 0.15,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            CupertinoIcons.paintbrush,
                            color: YYColors.accentPrimary,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '主题',
                          style: TextStyle(color: textPrimary, fontSize: 15),
                        ),
                        const Spacer(),
                        _ThemeSegment(
                          current: settings.themeMode,
                          onChanged: (mode) => ref
                              .read(settingsProvider.notifier)
                              .setThemeMode(mode),
                          bgSurface: isDark
                              ? YYColors.bgSurface
                              : YYLightColors.bgSurface,
                          bgElevated: bgElevated,
                          textPrimary: textPrimary,
                          textTertiary: textTertiary,
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: separator,
                    indent: 64,
                    endIndent: 18,
                  ),
                  // 语言
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF10B981,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            CupertinoIcons.globe,
                            color: Color(0xFF10B981),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '语言',
                          style: TextStyle(color: textPrimary, fontSize: 15),
                        ),
                        const Spacer(),
                        Consumer(
                          builder: (ctx, ref2, _) {
                            final locale = ref2.watch(localeProvider);
                            final currentLang = locale?.languageCode ?? 'zh';
                            return Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? YYColors.bgSurface
                                    : YYLightColors.bgSurface,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildLangChip(
                                    '中文',
                                    'zh',
                                    currentLang,
                                    ref2,
                                    textPrimary,
                                    textTertiary,
                                  ),
                                  _buildLangChip(
                                    'EN',
                                    'en',
                                    currentLang,
                                    ref2,
                                    textPrimary,
                                    textTertiary,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              const YYSectionTitle(title: '缓存与存储', subtitle: '清理临时文件和最近播放记录'),
              _SettingsCard(
                bgElevated: bgElevated,
                children: [
                  _SettingsRow(
                    icon: CupertinoIcons.delete,
                    iconColor: YYColors.statusError,
                    title: '清除缓存',
                    subtitle: '清除最近播放记录和临时文件',
                    onTap: () => _showClearCacheDialog(
                      context,
                      bgElevated,
                      textPrimary,
                      textSecondary,
                      textTertiary,
                    ),
                    showArrow: true,
                    textPrimary: textPrimary,
                    textTertiary: textTertiary,
                  ),
                ],
              ),

              const SizedBox(height: 20),
              const YYSectionTitle(title: '关于应用', subtitle: '当前版本和产品信息'),
              _SettingsCard(
                bgElevated: bgElevated,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: YYColors.accentGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            CupertinoIcons.music_note_2,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '猿音 Primuse',
                              style: TextStyle(
                                color: textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '版本 0.1.0',
                              style: TextStyle(
                                color: textTertiary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLangChip(
    String label,
    String lang,
    String current,
    WidgetRef ref,
    Color textPrimary,
    Color textTertiary,
  ) {
    final isActive = current == lang;
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: isActive ? YYColors.accentPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: InkWell(
          onTap: () => ref.read(localeProvider.notifier).state = Locale(lang),
          borderRadius: BorderRadius.circular(8),
          overlayColor: WidgetStatePropertyAll(
            isActive
                ? Colors.white.withValues(alpha: 0.12)
                : textPrimary.withValues(alpha: 0.05),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : textTertiary,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _rescanLibrary(BuildContext context, WidgetRef ref) {
    ref.read(libraryProvider.notifier).refresh();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('正在重新扫描音乐库...'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? YYColors.bgElevated
            : YYLightColors.bgElevated,
      ),
    );
  }

  void _batchScrape(BuildContext context, WidgetRef ref, bool coverOnly) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? YYColors.bgElevated : YYLightColors.bgElevated;
    final pri = isDark ? YYColors.textPrimary : YYLightColors.textPrimary;
    final tri = isDark ? YYColors.textTertiary : YYLightColors.textTertiary;

    showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) {
        return _BatchScrapeDialog(
          ref: ref,
          coverOnly: coverOnly,
          bg: bg,
          pri: pri,
          tri: tri,
        );
      },
    );
  }

  void _showEngineSelector(
    BuildContext context,
    WidgetRef ref,
    String current,
    Color bgElevated,
    Color textPrimary,
    Color textTertiary,
    Color separator,
  ) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: bgElevated,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(YYRadius.xl),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  children: [
                    Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: textTertiary.withValues(alpha: 0.32),
                        borderRadius: BorderRadius.circular(YYRadius.full),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '播放引擎',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: separator),
              _EngineOption(
                label: 'just_audio (原生)',
                desc: 'Apple 原生音频引擎，稳定省电',
                isSelected: current == 'just_audio',
                onTap: () {
                  ref.read(settingsProvider.notifier).setEngine('just_audio');
                  Navigator.pop(ctx);
                },
                textPrimary: textPrimary,
                textTertiary: textTertiary,
              ),
              _EngineOption(
                label: 'media_kit (FFmpeg)',
                desc: '基于 FFmpeg，支持更多格式',
                isSelected: current == 'media_kit',
                onTap: () {
                  ref.read(settingsProvider.notifier).setEngine('media_kit');
                  Navigator.pop(ctx);
                },
                textPrimary: textPrimary,
                textTertiary: textTertiary,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showClearCacheDialog(
    BuildContext context,
    Color bgElevated,
    Color textPrimary,
    Color textSecondary,
    Color textTertiary,
  ) {
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: bgElevated,
        title: Text('清除缓存', style: TextStyle(color: textPrimary)),
        content: Text(
          '将清除最近播放记录和临时缓存文件。\n\n此操作不可撤销。',
          style: TextStyle(color: textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: textTertiary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _performClearCache(context);
            },
            child: const Text(
              '清除',
              style: TextStyle(color: YYColors.statusError),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performClearCache(BuildContext context) async {
    try {
      final recentBox = await Hive.openBox('recent_plays');
      await recentBox.clear();
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        for (final entity in tempDir.listSync()) {
          try {
            await entity.delete(recursive: true);
          } catch (_) {}
        }
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('缓存已清除'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('清除失败: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

// ──── Theme Segment Control ────
class _ThemeSegment extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;
  final Color bgSurface;
  final Color bgElevated;
  final Color textPrimary;
  final Color textTertiary;

  const _ThemeSegment({
    required this.current,
    required this.onChanged,
    required this.bgSurface,
    required this.bgElevated,
    required this.textPrimary,
    required this.textTertiary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: bgSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildChip('跟随系统', 'system'),
          _buildChip('浅色', 'light'),
          _buildChip('深色', 'dark'),
        ],
      ),
    );
  }

  Widget _buildChip(String label, String mode) {
    final isActive = current == mode;
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: isActive ? YYColors.accentPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: InkWell(
          onTap: () => onChanged(mode),
          borderRadius: BorderRadius.circular(8),
          overlayColor: WidgetStatePropertyAll(
            isActive
                ? Colors.white.withValues(alpha: 0.12)
                : textPrimary.withValues(alpha: 0.05),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : textTertiary,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ──── Reusable Settings Components ────

class _SettingsSnapshotCard extends StatelessWidget {
  const _SettingsSnapshotCard({
    required this.themeMode,
    required this.engine,
    required this.songCount,
    required this.sourceCount,
    required this.sleepLabel,
  });

  final String themeMode;
  final String engine;
  final int songCount;
  final int sourceCount;
  final String sleepLabel;

  @override
  Widget build(BuildContext context) {
    final themeLabel = switch (themeMode) {
      'system' => '跟随',
      'dark' => '深色',
      _ => '浅色',
    };
    final engineLabel = engine == 'just_audio' ? '原生' : 'FFmpeg';

    return YYPanel(
      color: context.yyBlend(YYColors.accentPrimary, amount: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const YYIconBadge(
                icon: CupertinoIcons.music_note_2,
                color: YYColors.accentPrimary,
                size: 52,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '猿音 Primuse',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '把播放、主题、曲库维护和连接入口整理成一个更清晰的偏好中心。',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          YYMetricBand(
            items: [
              YYMetricBandItem(
                label: '曲库',
                value: '$songCount 首',
                tint: YYColors.accentPrimary,
              ),
              YYMetricBandItem(
                label: '数据源',
                value: '$sourceCount 个',
                tint: YYColors.accentSecondary,
              ),
              YYMetricBandItem(
                label: '主题',
                value: themeLabel,
                tint: YYColors.accentTertiary,
              ),
              YYMetricBandItem(
                label: '睡眠',
                value: sleepLabel,
                tint: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '当前引擎：$engineLabel',
            style: TextStyle(
              color: context.yyTextSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  final Color bgElevated;
  const _SettingsCard({required this.children, required this.bgElevated});

  @override
  Widget build(BuildContext context) {
    return YYPanel(
      margin: const EdgeInsets.symmetric(horizontal: YYSpacing.screenH),
      padding: EdgeInsets.zero,
      color: bgElevated.withValues(alpha: 0.94),
      child: Column(children: children),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool showArrow;
  final Color textPrimary;
  final Color textTertiary;

  const _SettingsRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.onTap,
    this.showArrow = false,
    required this.textPrimary,
    required this.textTertiary,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        overlayColor: WidgetStatePropertyAll(
          textPrimary.withValues(alpha: 0.04),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          subtitle!,
                          style: TextStyle(
                            color: textTertiary,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (showArrow)
                Icon(
                  CupertinoIcons.chevron_forward,
                  color: textTertiary,
                  size: 14,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EngineOption extends StatelessWidget {
  final String label;
  final String desc;
  final bool isSelected;
  final VoidCallback onTap;
  final Color textPrimary;
  final Color textTertiary;

  const _EngineOption({
    required this.label,
    required this.desc,
    required this.isSelected,
    required this.onTap,
    required this.textPrimary,
    required this.textTertiary,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        overlayColor: WidgetStatePropertyAll(
          textPrimary.withValues(alpha: 0.04),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      style: TextStyle(
                        color: textTertiary,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  CupertinoIcons.checkmark,
                  color: YYColors.accentPrimary,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 批量刮削对话框 — 遍历全库歌曲并调用 MusicBrainz 刮削
class _BatchScrapeDialog extends StatefulWidget {
  final WidgetRef ref;
  final bool coverOnly;
  final Color bg;
  final Color pri;
  final Color tri;

  const _BatchScrapeDialog({
    required this.ref,
    required this.coverOnly,
    required this.bg,
    required this.pri,
    required this.tri,
  });

  @override
  State<_BatchScrapeDialog> createState() => _BatchScrapeDialogState();
}

class _BatchScrapeDialogState extends State<_BatchScrapeDialog> {
  int _total = 0;
  int _current = 0;
  int _updated = 0;
  String _currentSong = '';
  bool _done = false;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final db = widget.ref.read(musicDatabaseProvider);
    final scraper = MetadataScraper();
    final allSongs = await db.getAllSongs();
    setState(() => _total = allSongs.length);

    for (int i = 0; i < allSongs.length; i++) {
      if (_cancelled) break;
      final song = allSongs[i];
      setState(() {
        _current = i + 1;
        _currentSong = song.title;
      });

      try {
        final enriched = await scraper.scrape(song);
        if (enriched != null) {
          await db.updateSong(enriched);
          setState(() => _updated++);
        }
      } catch (_) {
        // skip errors
      }

      // Rate limit to avoid MusicBrainz throttling
      await Future.delayed(const Duration(milliseconds: 1100));
    }

    setState(() => _done = true);
    // Refresh library
    widget.ref.read(libraryProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: widget.bg,
      title: Text(
        _done ? '刮削完成' : (widget.coverOnly ? '正在获取封面…' : '正在刮削元数据…'),
        style: TextStyle(color: widget.pri, fontSize: 17),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_done) ...[
            LinearProgressIndicator(
              value: _total > 0 ? _current / _total : null,
              color: YYColors.accentPrimary,
              backgroundColor: widget.tri.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 12),
            Text(
              '$_current / $_total',
              style: TextStyle(color: widget.pri, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              _currentSong,
              style: TextStyle(color: widget.tri, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ] else ...[
            Text(
              '已更新 $_updated / $_total 首歌曲',
              style: TextStyle(color: widget.pri, fontSize: 14),
            ),
          ],
        ],
      ),
      actions: [
        if (!_done)
          TextButton(
            onPressed: () {
              _cancelled = true;
              Navigator.pop(context);
            },
            child: Text('取消', style: TextStyle(color: widget.tri)),
          ),
        if (_done)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '完成',
              style: TextStyle(color: YYColors.accentPrimary),
            ),
          ),
      ],
    );
  }
}
