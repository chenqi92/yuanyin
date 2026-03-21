import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../../player/domain/entities/music_item.dart';
import 'playlist_service.dart';

/// 歌单导入/导出服务
///
/// 支持 M3U 和 JSON 格式。
class PlaylistIOService {
  /// 导出歌单为 M3U 文件
  ///
  /// 返回导出的文件路径
  Future<String> exportToM3U(PlaylistEntity playlist, List<MusicItem> songs) async {
    final dir = await getApplicationDocumentsDirectory();
    final exportDir = Directory(p.join(dir.path, 'exports'));
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    final safeName = playlist.name.replaceAll(RegExp(r'[^\w\u4e00-\u9fff]'), '_');
    final filePath = p.join(exportDir.path, '$safeName.m3u');
    final buffer = StringBuffer();

    buffer.writeln('#EXTM3U');
    buffer.writeln('# Playlist: ${playlist.name}');
    buffer.writeln('# Exported by Primuse');
    buffer.writeln();

    for (final song in songs) {
      final durationSecs = song.duration?.inSeconds ?? -1;
      buffer.writeln('#EXTINF:$durationSecs,${song.artist} - ${song.title}');
      if (song.filePath != null) {
        buffer.writeln(song.filePath!);
      } else {
        buffer.writeln('# ${song.id}');
      }
    }

    await File(filePath).writeAsString(buffer.toString());
    return filePath;
  }

  /// 解析 M3U 文件内容，返回文件路径列表
  ///
  /// 可用于匹配曲库中的歌曲
  List<String> parseM3U(String content) {
    final lines = content.split('\n');
    final paths = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      paths.add(trimmed);
    }

    return paths;
  }

  /// 导出歌单为 JSON 格式
  Future<String> exportToJson(PlaylistEntity playlist, List<MusicItem> songs) async {
    final dir = await getApplicationDocumentsDirectory();
    final exportDir = Directory(p.join(dir.path, 'exports'));
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    final safeName = playlist.name.replaceAll(RegExp(r'[^\w\u4e00-\u9fff]'), '_');
    final filePath = p.join(exportDir.path, '$safeName.json');

    final data = {
      'name': playlist.name,
      'createdAt': playlist.createdAt.toIso8601String(),
      'songs': songs.map((s) => {
        'title': s.title,
        'artist': s.artist,
        'album': s.album,
        'filePath': s.filePath,
        'duration': s.duration?.inMilliseconds,
      }).toList(),
    };

    // 手动序列化（避免引入 dart:convert 的 JsonEncoder 开销）
    await File(filePath).writeAsString(_toJson(data));
    return filePath;
  }

  String _toJson(Object? value, [int indent = 0]) {
    if (value == null) return 'null';
    if (value is String) return '"${value.replaceAll('"', '\\"')}"';
    if (value is num || value is bool) return value.toString();
    if (value is List) {
      if (value.isEmpty) return '[]';
      final items = value.map((e) => '${'  ' * (indent + 1)}${_toJson(e, indent + 1)}').join(',\n');
      return '[\n$items\n${'  ' * indent}]';
    }
    if (value is Map) {
      if (value.isEmpty) return '{}';
      final entries = value.entries
          .map((e) => '${'  ' * (indent + 1)}${_toJson(e.key)}: ${_toJson(e.value, indent + 1)}')
          .join(',\n');
      return '{\n$entries\n${'  ' * indent}}';
    }
    return value.toString();
  }
}
