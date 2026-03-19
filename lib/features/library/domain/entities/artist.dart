/// 艺术家实体
class Artist {
  final String id;
  final String name;
  final String? coverUrl;
  final int songCount;
  final int albumCount;

  const Artist({
    required this.id,
    required this.name,
    this.coverUrl,
    this.songCount = 0,
    this.albumCount = 0,
  });
}
