import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/music_database_service.dart';
import '../../../player/domain/entities/music_item.dart';

/// 音乐库状态
class LibraryState {
  final List<MusicItem> allSongs;
  final List<ArtistInfo> artists;
  final List<AlbumInfo> albums;
  final List<GenreInfo> genres;
  final List<MusicItem> recentPlays;
  final LibraryStats stats;
  final bool isLoading;

  const LibraryState({
    this.allSongs = const [],
    this.artists = const [],
    this.albums = const [],
    this.genres = const [],
    this.recentPlays = const [],
    this.stats = const LibraryStats(songCount: 0, artistCount: 0, albumCount: 0),
    this.isLoading = false,
  });

  LibraryState copyWith({
    List<MusicItem>? allSongs,
    List<ArtistInfo>? artists,
    List<AlbumInfo>? albums,
    List<GenreInfo>? genres,
    List<MusicItem>? recentPlays,
    LibraryStats? stats,
    bool? isLoading,
  }) {
    return LibraryState(
      allSongs: allSongs ?? this.allSongs,
      artists: artists ?? this.artists,
      albums: albums ?? this.albums,
      genres: genres ?? this.genres,
      recentPlays: recentPlays ?? this.recentPlays,
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// 音乐库 Notifier
class LibraryNotifier extends StateNotifier<LibraryState> {
  final MusicDatabaseService _db;

  LibraryNotifier(this._db) : super(const LibraryState()) {
    refresh();
  }

  /// 刷新全部数据
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    try {
      final results = await Future.wait([
        _db.getAllSongs(),
        _db.getArtists(),
        _db.getAlbums(),
        _db.getGenres(),
        _db.getRecentPlays(),
        _db.getStats(),
      ]);

      state = state.copyWith(
        allSongs: results[0] as List<MusicItem>,
        artists: results[1] as List<ArtistInfo>,
        albums: results[2] as List<AlbumInfo>,
        genres: results[3] as List<GenreInfo>,
        recentPlays: results[4] as List<MusicItem>,
        stats: results[5] as LibraryStats,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// 按艺术家获取歌曲
  Future<List<MusicItem>> getSongsByArtist(String artist) =>
      _db.getSongsByArtist(artist);

  /// 按专辑获取歌曲
  Future<List<MusicItem>> getSongsByAlbum(String album, String artist) =>
      _db.getSongsByAlbum(album, artist);

  /// 按流派获取歌曲
  Future<List<MusicItem>> getSongsByGenre(String genre) =>
      _db.getSongsByGenre(genre);

  /// 搜索
  Future<List<MusicItem>> search(String query) =>
      _db.search(query);

  /// 记录播放
  Future<void> recordPlay(MusicItem song) async {
    await _db.addRecentPlay(song);
    final recent = await _db.getRecentPlays();
    state = state.copyWith(recentPlays: recent);
  }
}

/// Providers
final musicDatabaseProvider = Provider((ref) => MusicDatabaseService());

final libraryProvider =
    StateNotifierProvider<LibraryNotifier, LibraryState>((ref) {
  return LibraryNotifier(ref.watch(musicDatabaseProvider));
});
