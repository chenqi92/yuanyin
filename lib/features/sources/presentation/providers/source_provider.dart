import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/source_repository.dart';
import '../../data/services/local_file_scanner.dart';
import '../../data/services/webdav_scanner.dart';
import '../../data/services/smb_scanner.dart';
import '../../domain/entities/source_entity.dart';
import '../../../player/domain/entities/music_item.dart';
import '../../../library/data/services/music_database_service.dart';
import '../../../library/presentation/providers/library_provider.dart';
import 'dart:io';

/// 数据源状态
class SourcesState {
  final List<SourceEntity> sources;
  final bool isScanning;
  final String? scanningFile;
  final int scannedCount;

  const SourcesState({
    this.sources = const [],
    this.isScanning = false,
    this.scanningFile,
    this.scannedCount = 0,
  });

  SourcesState copyWith({
    List<SourceEntity>? sources,
    bool? isScanning,
    String? scanningFile,
    int? scannedCount,
  }) {
    return SourcesState(
      sources: sources ?? this.sources,
      isScanning: isScanning ?? this.isScanning,
      scanningFile: scanningFile ?? this.scanningFile,
      scannedCount: scannedCount ?? this.scannedCount,
    );
  }
}

/// 数据源管理 Notifier
class SourcesNotifier extends StateNotifier<SourcesState> {
  final SourceRepository _repository;
  final LocalFileScanner _localScanner;
  final WebDavScanner _webdavScanner;
  final SmbScanner _smbScanner;
  final MusicDatabaseService _db;
  final Ref _ref;

  SourcesNotifier(
    this._repository,
    this._localScanner,
    this._webdavScanner,
    this._smbScanner,
    this._db,
    this._ref,
  ) : super(const SourcesState()) {
    _loadSources();
  }

  Future<void> _loadSources() async {
    final sources = await _repository.getAll();
    state = state.copyWith(sources: sources);
  }

  // ---- 添加数据源 ----

  /// 添加本地数据源
  Future<void> addLocalSource(String name, String directoryPath) async {
    final source = SourceEntity(
      id: DateTime.now().millisecondsSinceEpoch.toRadixString(36),
      name: name,
      type: SourceType.local,
      path: directoryPath,
      status: SourceStatus.connecting,
    );
    await _repository.add(source);
    state = state.copyWith(sources: [...state.sources, source]);
    await scanSource(source.id);
  }

  /// 添加 WebDAV 数据源
  Future<void> addWebDavSource({
    required String name,
    required String url,
    String? username,
    String? password,
  }) async {
    final source = SourceEntity(
      id: DateTime.now().millisecondsSinceEpoch.toRadixString(36),
      name: name,
      type: SourceType.webdav,
      path: url,
      username: username,
      password: password,
      status: SourceStatus.connecting,
    );
    await _repository.add(source);
    state = state.copyWith(sources: [...state.sources, source]);
    await scanSource(source.id);
  }

  /// 添加群晖数据源
  Future<String> addSynologySource({
    required String name,
    required String host,
    int port = 5001,
    required String username,
    required String password,
    required String folderPath,
    bool useSsl = true,
    String? deviceToken,
    String? otpCode,
    List<String> scanPaths = const [],
  }) async {
    final source = SourceEntity(
      id: DateTime.now().millisecondsSinceEpoch.toRadixString(36),
      name: name,
      type: SourceType.synology,
      path: folderPath,
      host: host,
      port: port,
      username: username,
      password: password,
      useSsl: useSsl,
      deviceToken: deviceToken,
      status: SourceStatus.disconnected,
      scanPaths: scanPaths,
    );
    await _repository.add(source);
    state = state.copyWith(sources: [...state.sources, source]);
    return source.id;
  }

  /// 添加 SMB 数据源
  Future<void> addSmbSource({
    required String name,
    required String host,
    int port = 445,
    String? username,
    String? password,
    required String sharePath,
    bool useSsl = false,
  }) async {
    final source = SourceEntity(
      id: DateTime.now().millisecondsSinceEpoch.toRadixString(36),
      name: name,
      type: SourceType.smb,
      path: sharePath,
      host: host,
      port: port,
      username: username,
      password: password,
      useSsl: useSsl,
      status: SourceStatus.connecting,
    );
    await _repository.add(source);
    state = state.copyWith(sources: [...state.sources, source]);
    await scanSource(source.id);
  }

  // ---- 连接测试 ----

  /// 测试数据源连接（不扫描）
  ///
  /// 返回 (success, errorMessage)
  Future<(bool, String?)> testConnection(SourceEntity source, {String? otpCode}) async {
    switch (source.type) {
      case SourceType.local:
        final dir = Directory(source.path);
        if (await dir.exists()) {
          return (true, null);
        }
        return (false, '目录不存在或无权限访问');

      case SourceType.webdav:
        return _webdavScanner.testConnection(
          source.path,
          username: source.username,
          password: source.password,
        );

      case SourceType.synology:
        return _smbScanner.testSynologyConnection(
          host: source.host!,
          port: source.port ?? 5000,
          username: source.username!,
          password: source.password!,
          useSsl: source.useSsl,
          otpCode: otpCode,
          deviceId: source.deviceToken,
        );

      case SourceType.smb:
        // SMB 走 HTTP 代理，尝试连接 host:port
        return _webdavScanner.testConnection(
          'http://${source.host}:${source.port ?? 445}${source.path}',
          username: source.username,
          password: source.password,
        );

      default:
        return (false, '暂不支持该类型的连接测试');
    }
  }

  // ---- 编辑数据源 ----

  /// 更新数据源配置
  Future<void> editSource(SourceEntity updatedSource) async {
    await _repository.update(updatedSource);
    final sources = [...state.sources];
    final index = sources.indexWhere((s) => s.id == updatedSource.id);
    if (index != -1) {
      sources[index] = updatedSource;
      state = state.copyWith(sources: sources);
    }
  }

  // ---- 自动重连 ----

  /// 群晖登录（公开方法，供 UI 使用）
  Future<SynologyLoginResult> synologyLogin(SourceEntity source, {String? otpCode}) {
    return _smbScanner.synologyLogin(
      host: source.host!,
      port: source.port ?? 5000,
      username: source.username!,
      password: source.password!,
      useSsl: source.useSsl,
      otpCode: otpCode,
      deviceId: source.deviceToken,
    );
  }

  /// 列出群晖共享文件夹（登录成功后调用）
  Future<List<String>> listSynologyFolders(SourceEntity source, String sid) {
    return _smbScanner.listSynologySharedFolders(
      host: source.host!,
      port: source.port ?? 5000,
      sid: sid,
      useSsl: source.useSsl,
    );
  }

  /// 列出群晖指定路径下的子文件夹（下钻浏览）
  Future<List<({String name, String path})>> listSynologySubFolders({
    required String host,
    required int port,
    required String sid,
    required String folderPath,
    required bool useSsl,
  }) {
    return _smbScanner.listSynologySubFolders(
      host: host, port: port, sid: sid,
      folderPath: folderPath, useSsl: useSsl,
    );
  }

  /// 启动时自动扫描所有 autoConnect 数据源
  Future<void> autoReconnectAll() async {
    for (final source in state.sources) {
      if (source.autoConnect && source.status != SourceStatus.connected) {
        await scanSource(source.id);
      }
    }
  }

  // ---- 扫描 ----

  /// 扫描指定数据源（支持多文件夹）
  Future<void> scanSource(String sourceId, {String? otpCode}) async {
    final sourceIndex = state.sources.indexWhere((s) => s.id == sourceId);
    if (sourceIndex == -1) return;

    final source = state.sources[sourceIndex];
    state = state.copyWith(isScanning: true, scannedCount: 0, scanningFile: '');
    _updateSourceInList(sourceIndex, source.copyWith(status: SourceStatus.connecting));

    try {
      List<MusicItem> allSongs = [];

      switch (source.type) {
        case SourceType.local:
          final paths = source.scanPaths.isNotEmpty ? source.scanPaths : [source.path];
          for (final p in paths) {
            final songs = await _localScanner.scan(p, onProgress: _onProgress);
            allSongs.addAll(songs);
          }
          break;
        case SourceType.webdav:
          final paths = source.scanPaths.isNotEmpty ? source.scanPaths : [source.path];
          for (final p in paths) {
            final songs = await _webdavScanner.scan(
              p, username: source.username, password: source.password, onProgress: _onProgress,
            );
            allSongs.addAll(songs);
          }
          break;
        case SourceType.synology:
          final loginResult = await _smbScanner.synologyLogin(
            host: source.host!, port: source.port ?? 5000,
            username: source.username!, password: source.password!,
            useSsl: source.useSsl, otpCode: otpCode, deviceId: source.deviceToken,
          );
          if (loginResult.status != SynologyLoginStatus.success || loginResult.sid == null) {
            throw Exception(loginResult.errorMessage ?? '群晖登录失败');
          }
          if (loginResult.deviceId != null && loginResult.deviceId != source.deviceToken) {
            final withToken = source.copyWith(deviceToken: loginResult.deviceId);
            await _repository.update(withToken);
            _updateSourceInList(sourceIndex, withToken);
          }
          // 多文件夹扫描
          final folderPaths = source.scanPaths.isNotEmpty
              ? source.scanPaths
              : [source.path.isNotEmpty ? source.path : '/'];
          for (final fp in folderPaths) {
            final songs = await _smbScanner.scanSynology(
              host: source.host!, port: source.port ?? 5000,
              sid: loginResult.sid!, folderPath: fp,
              useSsl: source.useSsl, onProgress: _onProgress,
            );
            allSongs.addAll(songs);
          }
          break;
        case SourceType.smb:
          final paths = source.scanPaths.isNotEmpty ? source.scanPaths : [source.path];
          for (final p in paths) {
            final url = 'http://${source.host}:${source.port ?? 445}$p';
            final songs = await _webdavScanner.scan(
              url, username: source.username, password: source.password, onProgress: _onProgress,
            );
            allSongs.addAll(songs);
          }
          break;
        default:
          allSongs = [];
      }

      // 标记所属源
      final taggedSongs = allSongs.map((s) => s.copyWith(sourceId: source.id)).toList();

      // 写入数据库
      await _db.deleteSongsBySource(sourceId);
      await _db.upsertSongs(taggedSongs);

      // 更新源信息
      final updatedSource = source.copyWith(
        status: SourceStatus.connected,
        songCount: allSongs.length,
        lastScanTime: DateTime.now(),
      );
      await _repository.update(updatedSource);
      _updateSourceInList(sourceIndex, updatedSource);

      // 刷新音乐库
      _ref.read(libraryProvider.notifier).refresh();
    } catch (e) {
      _updateSourceInList(sourceIndex, source.copyWith(
        status: SourceStatus.error, errorMessage: e.toString()));
    }

    state = state.copyWith(isScanning: false, scanningFile: null);
  }

  void _onProgress(int count, String file) {
    state = state.copyWith(scannedCount: count, scanningFile: file);
  }

  /// 删除数据源
  Future<void> removeSource(String sourceId) async {
    await _repository.delete(sourceId);
    await _db.deleteSongsBySource(sourceId);
    state = state.copyWith(
      sources: state.sources.where((s) => s.id != sourceId).toList(),
    );
    _ref.read(libraryProvider.notifier).refresh();
  }

  void _updateSourceInList(int index, SourceEntity updated) {
    final sources = [...state.sources];
    sources[index] = updated;
    state = state.copyWith(sources: sources);
  }

  // ---- 文件夹管理 ----

  /// 添加扫描路径
  Future<void> addScanPath(String sourceId, String path) async {
    final idx = state.sources.indexWhere((s) => s.id == sourceId);
    if (idx == -1) return;
    final source = state.sources[idx];
    if (source.scanPaths.contains(path)) return;
    final updated = source.copyWith(scanPaths: [...source.scanPaths, path]);
    await _repository.update(updated);
    _updateSourceInList(idx, updated);
  }

  /// 移除扫描路径
  Future<void> removeScanPath(String sourceId, String path) async {
    final idx = state.sources.indexWhere((s) => s.id == sourceId);
    if (idx == -1) return;
    final source = state.sources[idx];
    final updated = source.copyWith(
      scanPaths: source.scanPaths.where((p) => p != path).toList());
    await _repository.update(updated);
    _updateSourceInList(idx, updated);
  }

  /// 更新扫描路径列表（批量）
  Future<void> updateScanPaths(String sourceId, List<String> paths) async {
    final idx = state.sources.indexWhere((s) => s.id == sourceId);
    if (idx == -1) return;
    final source = state.sources[idx];
    final updated = source.copyWith(scanPaths: paths);
    await _repository.update(updated);
    _updateSourceInList(idx, updated);
  }
}

/// Providers
final sourceRepositoryProvider = Provider((ref) => SourceRepository());
final localFileScannerProvider = Provider((ref) => LocalFileScanner());
final webdavScannerProvider = Provider((ref) => WebDavScanner());
final smbScannerProvider = Provider((ref) => SmbScanner());

final sourcesProvider =
    StateNotifierProvider<SourcesNotifier, SourcesState>((ref) {
  return SourcesNotifier(
    ref.watch(sourceRepositoryProvider),
    ref.watch(localFileScannerProvider),
    ref.watch(webdavScannerProvider),
    ref.watch(smbScannerProvider),
    ref.watch(musicDatabaseProvider),
    ref,
  );
});
