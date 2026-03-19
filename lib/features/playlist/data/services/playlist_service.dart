import 'package:hive_ce/hive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

final _log = Logger(printer: SimplePrinter());

/// 歌单实体
class PlaylistEntity {
  final String id;
  final String name;
  final int colorIndex; // 渐变色索引
  final List<String> songIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PlaylistEntity({
    required this.id,
    required this.name,
    this.colorIndex = 0,
    this.songIds = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  PlaylistEntity copyWith({
    String? name,
    int? colorIndex,
    List<String>? songIds,
    DateTime? updatedAt,
  }) {
    return PlaylistEntity(
      id: id,
      name: name ?? this.name,
      colorIndex: colorIndex ?? this.colorIndex,
      songIds: songIds ?? this.songIds,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'colorIndex': colorIndex,
    'songIds': songIds,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };

  factory PlaylistEntity.fromMap(Map<dynamic, dynamic> map) {
    return PlaylistEntity(
      id: map['id'] as String,
      name: map['name'] as String,
      colorIndex: map['colorIndex'] as int? ?? 0,
      songIds: (map['songIds'] as List?)?.cast<String>() ?? [],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
    );
  }
}

/// 歌单服务 — Hive 持久化
class PlaylistService {
  static const _boxName = 'playlists';
  Box? _box;

  Future<Box> get _openBox async {
    _box ??= await Hive.openBox(_boxName);
    return _box!;
  }

  Future<List<PlaylistEntity>> getAll() async {
    final box = await _openBox;
    final list = <PlaylistEntity>[];
    for (final key in box.keys) {
      try {
        final map = box.get(key);
        if (map is Map) list.add(PlaylistEntity.fromMap(map));
      } catch (e) {
        _log.w('读取歌单失败: $key - $e');
      }
    }
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  Future<void> save(PlaylistEntity playlist) async {
    final box = await _openBox;
    await box.put(playlist.id, playlist.toMap());
  }

  Future<void> delete(String id) async {
    final box = await _openBox;
    await box.delete(id);
  }

  Future<PlaylistEntity?> getById(String id) async {
    final box = await _openBox;
    final map = box.get(id);
    if (map is Map) return PlaylistEntity.fromMap(map);
    return null;
  }
}

/// 歌单状态
class PlaylistsState {
  final List<PlaylistEntity> playlists;
  final bool isLoading;

  const PlaylistsState({this.playlists = const [], this.isLoading = false});

  PlaylistsState copyWith({List<PlaylistEntity>? playlists, bool? isLoading}) {
    return PlaylistsState(
      playlists: playlists ?? this.playlists,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// 歌单 Notifier
class PlaylistsNotifier extends StateNotifier<PlaylistsState> {
  final PlaylistService _service;

  PlaylistsNotifier(this._service) : super(const PlaylistsState()) {
    _load();
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true);
    final playlists = await _service.getAll();
    state = state.copyWith(playlists: playlists, isLoading: false);
  }

  Future<void> createPlaylist(String name, {int colorIndex = 0}) async {
    final now = DateTime.now();
    final playlist = PlaylistEntity(
      id: now.millisecondsSinceEpoch.toRadixString(36),
      name: name,
      colorIndex: colorIndex,
      createdAt: now,
      updatedAt: now,
    );
    await _service.save(playlist);
    await _load();
  }

  Future<void> addSongToPlaylist(String playlistId, String songId) async {
    final playlist = await _service.getById(playlistId);
    if (playlist == null) return;
    if (playlist.songIds.contains(songId)) return;
    final updated = playlist.copyWith(songIds: [...playlist.songIds, songId]);
    await _service.save(updated);
    await _load();
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    final playlist = await _service.getById(playlistId);
    if (playlist == null) return;
    final updated = playlist.copyWith(
      songIds: playlist.songIds.where((id) => id != songId).toList(),
    );
    await _service.save(updated);
    await _load();
  }

  Future<void> deletePlaylist(String id) async {
    await _service.delete(id);
    await _load();
  }

  Future<void> renamePlaylist(String id, String newName) async {
    final playlist = await _service.getById(id);
    if (playlist == null) return;
    await _service.save(playlist.copyWith(name: newName));
    await _load();
  }
}

/// Providers
final playlistServiceProvider = Provider((ref) => PlaylistService());

final playlistsProvider =
    StateNotifierProvider<PlaylistsNotifier, PlaylistsState>((ref) {
  return PlaylistsNotifier(ref.watch(playlistServiceProvider));
});
