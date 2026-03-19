import '../../../player/domain/entities/music_item.dart';

/// 歌单实体
class Playlist {
  final String id;
  final String name;
  final String? description;
  final List<String> gradientColors; // 歌单封面渐变色 hex
  final List<MusicItem> songs;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Playlist({
    required this.id,
    required this.name,
    this.description,
    this.gradientColors = const ['#667eea', '#764ba2'],
    this.songs = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  int get songCount => songs.length;

  Duration get totalDuration =>
      songs.fold(Duration.zero, (sum, s) => sum + s.duration);
}
