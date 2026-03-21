/// Primuse i18n 国际化支持
///
/// 双语：中文 (zh) / English (en)
/// 使用方式：S.of(context).xxx
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class S {
  final String locale;
  S(this.locale);

  static S of(BuildContext context) {
    return Localizations.of<S>(context, S) ?? S('zh');
  }

  static const List<Locale> supportedLocales = [
    Locale('zh'),
    Locale('en'),
  ];

  // ---- 通用 ----
  String get appName => _t('猿音', 'Primuse');
  String get ok => _t('确定', 'OK');
  String get cancel => _t('取消', 'Cancel');
  String get done => _t('完成', 'Done');
  String get loading => _t('加载中…', 'Loading…');
  String get error => _t('出错了', 'Error');
  String get comingSoon => _t('功能开发中，敬请期待', 'Coming soon');
  String get noData => _t('暂无数据', 'No data');

  // ---- 导航 ----
  String get tabHome => _t('首页', 'Home');
  String get tabLibrary => _t('音乐库', 'Library');
  String get tabSearch => _t('搜索', 'Search');
  String get tabSettings => _t('设置', 'Settings');

  // ---- 首页 ----
  String get recentlyPlayed => _t('最近播放', 'Recently Played');
  String get recommendAlbums => _t('专辑推荐', 'Albums');
  String get quickPlay => _t('快速播放', 'Quick Play');
  String get emptyLibraryTitle => _t('还没有歌曲', 'No songs yet');
  String get emptyLibrarySubtitle => _t('先去设置中添加数据源', 'Add a source in Settings');

  // ---- 音乐库 ----
  String get allSongs => _t('全部歌曲', 'All Songs');
  String get artists => _t('艺术家', 'Artists');
  String get albums => _t('专辑', 'Albums');
  String get genres => _t('流派', 'Genres');
  String get playlists => _t('歌单', 'Playlists');
  String nSongs(int n) => _t('$n 首', '$n songs');

  // ---- 搜索 ----
  String get searchHint => _t('搜索歌曲、艺术家、专辑', 'Search songs, artists, albums');
  String get searchHistory => _t('搜索历史', 'Search History');
  String get clearAll => _t('清空', 'Clear All');
  String get noResults => _t('没有找到结果', 'No results found');

  // ---- 播放器 ----
  String get nowPlaying => _t('正在播放', 'Now Playing');
  String get queue => _t('播放队列', 'Queue');
  String get lyrics => _t('歌词', 'Lyrics');
  String get noLyrics => _t('暂无歌词', 'No lyrics');
  String get searchingLyrics => _t('正在搜索歌词…', 'Searching lyrics…');
  String get unknownArtist => _t('未知艺术家', 'Unknown Artist');
  String get unknownAlbum => _t('未知专辑', 'Unknown Album');

  // ---- 设置 ----
  String get sources => _t('数据源', 'Sources');
  String get sourceManagement => _t('数据源管理', 'Source Management');
  String get musicManagement => _t('音乐管理', 'Music Management');
  String get rescanLibrary => _t('重新扫描音乐库', 'Rescan Library');
  String get metadataScrape => _t('元数据刮削', 'Metadata Scrape');
  String get fetchCovers => _t('封面获取', 'Fetch Covers');
  String get playback => _t('播放', 'Playback');
  String get playEngine => _t('播放引擎', 'Playback Engine');
  String get crossfade => _t('交叉淡化', 'Crossfade');
  String get sleepTimer => _t('定时关闭', 'Sleep Timer');
  String get appearance => _t('外观', 'Appearance');
  String get theme => _t('主题', 'Theme');
  String get themeSystem => _t('跟随系统', 'System');
  String get themeLight => _t('浅色', 'Light');
  String get themeDark => _t('深色', 'Dark');
  String get language => _t('语言', 'Language');
  String get storage => _t('存储', 'Storage');
  String get clearCache => _t('清除缓存', 'Clear Cache');
  String get about => _t('关于', 'About');
  String get equalizer => _t('均衡器', 'Equalizer');

  // ---- 操作 ----
  String get favorite => _t('收藏', 'Favorite');
  String get unfavorite => _t('取消收藏', 'Unfavorite');
  String get addToPlaylist => _t('添加到歌单', 'Add to Playlist');
  String get removeFromPlaylist => _t('从歌单移除', 'Remove from Playlist');
  String get songDetails => _t('歌曲详情', 'Song Details');
  String get scrapeMetadata => _t('元数据刮削', 'Scrape Metadata');

  // ---- 刮削 ----
  String get scrapingMusicBrainz => _t('正在搜索 MusicBrainz…', 'Searching MusicBrainz…');
  String get scrapeSuccess => _t('刮削成功！已更新元数据', 'Scrape success! Metadata updated');
  String get scrapeNoMatch => _t('未找到匹配的元数据', 'No matching metadata found');

  // ---- 定时 ----
  String nMinutes(int n) => _t('$n 分钟', '$n min');
  String remainingTime(int min, int sec) =>
      _t('剩余 $min 分 $sec 秒', '$min min $sec sec remaining');

  String _t(String zh, String en) => locale == 'en' ? en : zh;
}

/// Localization delegate
class SLocalizationDelegate extends LocalizationsDelegate<S> {
  const SLocalizationDelegate();

  @override
  bool isSupported(Locale locale) => ['zh', 'en'].contains(locale.languageCode);

  @override
  Future<S> load(Locale locale) async => S(locale.languageCode);

  @override
  bool shouldReload(covariant LocalizationsDelegate<S> old) => false;
}

/// Locale provider
final localeProvider = StateProvider<Locale?>((ref) => null);
