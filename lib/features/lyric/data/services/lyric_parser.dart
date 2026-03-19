/// LRC 歌词行
class LyricLine {
  final Duration time;
  final String text;

  const LyricLine({required this.time, required this.text});
}

/// LRC 歌词解析器
///
/// 支持标准 LRC 格式：[mm:ss.xx] 文本
class LrcParser {
  static final _linePattern = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');

  /// 解析 LRC 文本
  static List<LyricLine> parse(String lrc) {
    final lines = <LyricLine>[];

    for (final line in lrc.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // 可能有多个时间标签对应同一行文本
      final matches = _linePattern.allMatches(trimmed);
      for (final match in matches) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final msStr = match.group(3)!;
        // 兼容 .xx (百分之一秒) 和 .xxx (毫秒)
        final ms = msStr.length == 2
            ? int.parse(msStr) * 10
            : int.parse(msStr);

        final text = match.group(4)?.trim() ?? '';
        if (text.isEmpty) continue;

        lines.add(LyricLine(
          time: Duration(minutes: minutes, seconds: seconds, milliseconds: ms),
          text: text,
        ));
      }
    }

    lines.sort((a, b) => a.time.compareTo(b.time));
    return lines;
  }

  /// 根据当前播放位置找到对应的歌词行索引
  static int findCurrentIndex(List<LyricLine> lyrics, Duration position) {
    if (lyrics.isEmpty) return -1;

    for (int i = lyrics.length - 1; i >= 0; i--) {
      if (position >= lyrics[i].time) return i;
    }
    return 0;
  }
}
