/// 专辑实体
class Album {
  final String id;
  final String name;
  final String artist;
  final String? coverUrl;
  final int? year;
  final int trackCount;

  const Album({
    required this.id,
    required this.name,
    required this.artist,
    this.coverUrl,
    this.year,
    this.trackCount = 0,
  });
}
