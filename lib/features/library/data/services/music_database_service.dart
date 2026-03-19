import 'package:hive_ce/hive.dart';
import 'package:logger/logger.dart';
import '../../../player/domain/entities/music_item.dart';

final _log = Logger(printer: SimplePrinter());

/// 音乐库数据库服务
///
/// 使用 Hive 存储所有歌曲元数据，支持分类查询。
class MusicDatabaseService {
  static const _boxName = 'music_library';
  static const _recentBoxName = 'recent_plays';
  Box? _box;
  Box? _recentBox;

  Future<Box> get _openBox async {
    _box ??= await Hive.openBox(_boxName);
    return _box!;
  }

  Future<Box> get _openRecentBox async {
    _recentBox ??= await Hive.openBox(_recentBoxName);
    return _recentBox!;
  }

  /// 批量写入歌曲（扫描结果）
  Future<void> upsertSongs(List<MusicItem> songs) async {
    final box = await _openBox;
    final map = <String, Map<String, dynamic>>{};
    for (final song in songs) {
      map[song.id] = song.toMap();
    }
    await box.putAll(map);
    _log.i('写入/更新 ${songs.length} 首歌曲到数据库');
  }

  /// 获取所有歌曲
  Future<List<MusicItem>> getAllSongs() async {
    final box = await _openBox;
    final songs = <MusicItem>[];
    for (final key in box.keys) {
      try {
        final map = box.get(key);
        if (map is Map) {
          songs.add(MusicItem.fromMap(map));
        }
      } catch (e) {
        _log.w('读取歌曲失败: $key - $e');
      }
    }
    return songs;
  }

  /// 按源 ID 获取歌曲
  Future<List<MusicItem>> getSongsBySource(String sourceId) async {
    final all = await getAllSongs();
    return all.where((s) => s.sourceId == sourceId).toList();
  }

  /// 删除指定源的所有歌曲
  Future<void> deleteSongsBySource(String sourceId) async {
    final box = await _openBox;
    final keysToDelete = <String>[];
    for (final key in box.keys) {
      try {
        final map = box.get(key);
        if (map is Map && map['sourceId'] == sourceId) {
          keysToDelete.add(key as String);
        }
      } catch (_) {}
    }
    await box.deleteAll(keysToDelete);
    _log.i('删除源 $sourceId 的 ${keysToDelete.length} 首歌曲');
  }

  /// 获取所有艺术家（去重）
  Future<List<ArtistInfo>> getArtists() async {
    final all = await getAllSongs();
    final artistMap = <String, List<MusicItem>>{};
    for (final song in all) {
      artistMap.putIfAbsent(song.artist, () => []).add(song);
    }
    return artistMap.entries
        .map((e) => ArtistInfo(name: e.key, songCount: e.value.length))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// 获取所有专辑（去重）
  Future<List<AlbumInfo>> getAlbums() async {
    final all = await getAllSongs();
    final albumMap = <String, _AlbumAcc>{};
    for (final song in all) {
      final key = '${song.album}__${song.artist}';
      albumMap.putIfAbsent(key, () => _AlbumAcc(song.album, song.artist));
      albumMap[key]!.songCount++;
      if (song.year != null) albumMap[key]!.year = song.year;
    }
    return albumMap.values
        .map((a) => AlbumInfo(name: a.name, artist: a.artist, songCount: a.songCount, year: a.year))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// 获取所有流派（去重）
  Future<List<GenreInfo>> getGenres() async {
    final all = await getAllSongs();
    final genreMap = <String, int>{};
    for (final song in all) {
      final g = song.genre ?? '未知流派';
      genreMap[g] = (genreMap[g] ?? 0) + 1;
    }
    return genreMap.entries
        .map((e) => GenreInfo(name: e.key, songCount: e.value))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// 按指定分类获取歌曲
  Future<List<MusicItem>> getSongsByArtist(String artist) async {
    final all = await getAllSongs();
    return all.where((s) => s.artist == artist).toList();
  }

  Future<List<MusicItem>> getSongsByAlbum(String album, String artist) async {
    final all = await getAllSongs();
    return all.where((s) => s.album == album && s.artist == artist).toList()
      ..sort((a, b) => (a.trackNumber ?? 999).compareTo(b.trackNumber ?? 999));
  }

  Future<List<MusicItem>> getSongsByGenre(String genre) async {
    final all = await getAllSongs();
    return all.where((s) => (s.genre ?? '未知流派') == genre).toList();
  }

  /// 搜索
  Future<List<MusicItem>> search(String query) async {
    if (query.isEmpty) return [];
    final q = query.toLowerCase();
    final all = await getAllSongs();
    return all.where((s) =>
        s.title.toLowerCase().contains(q) ||
        s.artist.toLowerCase().contains(q) ||
        s.album.toLowerCase().contains(q)).toList();
  }

  /// 记录最近播放
  Future<void> addRecentPlay(MusicItem song) async {
    final box = await _openRecentBox;
    // 最多保留 100 条最近播放
    final key = DateTime.now().millisecondsSinceEpoch.toString();
    await box.put(key, song.toMap());
    if (box.length > 100) {
      final oldestKey = box.keys.first;
      await box.delete(oldestKey);
    }
  }

  /// 获取最近播放
  Future<List<MusicItem>> getRecentPlays({int limit = 20}) async {
    final box = await _openRecentBox;
    final songs = <MusicItem>[];
    final keys = box.keys.toList().reversed.take(limit);
    for (final key in keys) {
      try {
        final map = box.get(key);
        if (map is Map) {
          songs.add(MusicItem.fromMap(map));
        }
      } catch (_) {}
    }
    // 去重（同一首歌只保留最近一次）
    final seen = <String>{};
    return songs.where((s) => seen.add(s.id)).toList();
  }

  /// 统计信息
  Future<LibraryStats> getStats() async {
    final all = await getAllSongs();
    final artists = <String>{};
    final albums = <String>{};
    for (final s in all) {
      artists.add(s.artist);
      albums.add('${s.album}__${s.artist}');
    }
    return LibraryStats(
      songCount: all.length,
      artistCount: artists.length,
      albumCount: albums.length,
    );
  }
}

class _AlbumAcc {
  final String name;
  final String artist;
  int songCount = 0;
  int? year;
  _AlbumAcc(this.name, this.artist);
}

/// 艺术家信息
class ArtistInfo {
  final String name;
  final int songCount;
  const ArtistInfo({required this.name, required this.songCount});
}

/// 专辑信息
class AlbumInfo {
  final String name;
  final String artist;
  final int songCount;
  final int? year;
  const AlbumInfo({required this.name, required this.artist, required this.songCount, this.year});
}

/// 流派信息
class GenreInfo {
  final String name;
  final int songCount;
  const GenreInfo({required this.name, required this.songCount});
}

/// 音乐库统计
class LibraryStats {
  final int songCount;
  final int artistCount;
  final int albumCount;
  const LibraryStats({required this.songCount, required this.artistCount, required this.albumCount});
}
