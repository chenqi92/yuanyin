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
  Future<void> addSynologySource({
    required String name,
    required String host,
    int port = 5000,
    required String username,
    required String password,
    required String folderPath,
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
      status: SourceStatus.connecting,
    );
    await _repository.add(source);
    state = state.copyWith(sources: [...state.sources, source]);
    await scanSource(source.id);
  }

  /// 添加 SMB 数据源
  Future<void> addSmbSource({
    required String name,
    required String host,
    int port = 445,
    String? username,
    String? password,
    required String sharePath,
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
      status: SourceStatus.connecting,
    );
    await _repository.add(source);
    state = state.copyWith(sources: [...state.sources, source]);
    await scanSource(source.id);
  }

  // ---- 扫描 ----

  /// 扫描指定数据源
  Future<void> scanSource(String sourceId) async {
    final sourceIndex = state.sources.indexWhere((s) => s.id == sourceId);
    if (sourceIndex == -1) return;

    final source = state.sources[sourceIndex];
    state = state.copyWith(isScanning: true, scannedCount: 0, scanningFile: '');
    _updateSourceInList(sourceIndex, source.copyWith(status: SourceStatus.connecting));

    try {
      List<MusicItem> songs;

      switch (source.type) {
        case SourceType.local:
          songs = await _localScanner.scan(source.path, onProgress: _onProgress);
          break;
        case SourceType.webdav:
          songs = await _webdavScanner.scan(
            source.path,
            username: source.username,
            password: source.password,
            onProgress: _onProgress,
          );
          break;
        case SourceType.synology:
          final sid = await _smbScanner.synologyLogin(
            host: source.host!,
            port: source.port ?? 5000,
            username: source.username!,
            password: source.password!,
          );
          if (sid == null) throw Exception('群晖登录失败');
          songs = await _smbScanner.scanSynology(
            host: source.host!,
            port: source.port ?? 5000,
            sid: sid,
            folderPath: source.path,
            onProgress: _onProgress,
          );
          break;
        case SourceType.smb:
          // SMB 直连：尝试通过 HTTP 文件服务器代理扫描
          // Flutter 无原生 SMB/CIFS 支持，需 NAS 端运行 HTTP 代理或使用 WebDAV
          songs = await _webdavScanner.scan(
            'http://${source.host}:${source.port ?? 445}${source.path}',
            username: source.username,
            password: source.password,
            onProgress: _onProgress,
          );
          break;
        default:
          // 暂不支持的类型
          songs = [];
      }

      // 标记所属源
      final taggedSongs = songs.map((s) => s.copyWith(sourceId: source.id)).toList();

      // 写入数据库
      await _db.deleteSongsBySource(sourceId);
      await _db.upsertSongs(taggedSongs);

      // 更新源信息
      final updatedSource = source.copyWith(
        status: SourceStatus.connected,
        songCount: songs.length,
        lastScanTime: DateTime.now(),
      );
      await _repository.update(updatedSource);
      _updateSourceInList(sourceIndex, updatedSource);

      // 刷新音乐库
      _ref.read(libraryProvider.notifier).refresh();
    } catch (e) {
      _updateSourceInList(sourceIndex, source.copyWith(status: SourceStatus.error));
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
