/// 音乐项实体
///
/// 描述一首歌曲的完整元数据信息。
class MusicItem {
  final String id;
  final String title;
  final String artist;
  final String album;
  final Duration? duration;
  final String? coverUrl;
  final String? filePath;
  final int? fileSize;
  final String? format;
  final int? year;
  final int? trackNumber;
  final String? genre;
  final int? bitrate;
  final int? sampleRate;
  final String? sourceId; // 所属数据源 ID
  final String? lyrics;

  const MusicItem({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    this.duration,
    this.coverUrl,
    this.filePath,
    this.fileSize,
    this.format,
    this.year,
    this.trackNumber,
    this.genre,
    this.bitrate,
    this.sampleRate,
    this.sourceId,
    this.lyrics,
  });

  MusicItem copyWith({
    String? title,
    String? artist,
    String? album,
    Duration? duration,
    String? coverUrl,
    String? filePath,
    int? fileSize,
    String? format,
    int? year,
    int? trackNumber,
    String? genre,
    int? bitrate,
    int? sampleRate,
    String? sourceId,
    String? lyrics,
  }) {
    return MusicItem(
      id: id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      coverUrl: coverUrl ?? this.coverUrl,
      filePath: filePath ?? this.filePath,
      fileSize: fileSize ?? this.fileSize,
      format: format ?? this.format,
      year: year ?? this.year,
      trackNumber: trackNumber ?? this.trackNumber,
      genre: genre ?? this.genre,
      bitrate: bitrate ?? this.bitrate,
      sampleRate: sampleRate ?? this.sampleRate,
      sourceId: sourceId ?? this.sourceId,
      lyrics: lyrics ?? this.lyrics,
    );
  }

  /// 格式化的时长文本 mm:ss
  String get durationText {
    if (duration == null) return '--:--';
    final m = duration!.inMinutes;
    final s = duration!.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// 格式化的文件大小
  String get fileSizeText {
    if (fileSize == null) return '';
    if (fileSize! < 1024 * 1024) {
      return '${(fileSize! / 1024).toStringAsFixed(0)} KB';
    }
    return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// 格式化的比特率
  String get bitrateText {
    if (bitrate == null) return '';
    return '${(bitrate! / 1000).toStringAsFixed(0)} kbps';
  }

  /// 序列化
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'duration': duration?.inMilliseconds,
      'coverUrl': coverUrl,
      'filePath': filePath,
      'fileSize': fileSize,
      'format': format,
      'year': year,
      'trackNumber': trackNumber,
      'genre': genre,
      'bitrate': bitrate,
      'sampleRate': sampleRate,
      'sourceId': sourceId,
      'lyrics': lyrics,
    };
  }

  factory MusicItem.fromMap(Map<dynamic, dynamic> map) {
    return MusicItem(
      id: map['id'] as String,
      title: map['title'] as String,
      artist: map['artist'] as String,
      album: map['album'] as String,
      duration: map['duration'] != null
          ? Duration(milliseconds: map['duration'] as int)
          : null,
      coverUrl: map['coverUrl'] as String?,
      filePath: map['filePath'] as String?,
      fileSize: map['fileSize'] as int?,
      format: map['format'] as String?,
      year: map['year'] as int?,
      trackNumber: map['trackNumber'] as int?,
      genre: map['genre'] as String?,
      bitrate: map['bitrate'] as int?,
      sampleRate: map['sampleRate'] as int?,
      sourceId: map['sourceId'] as String?,
      lyrics: map['lyrics'] as String?,
    );
  }
}
