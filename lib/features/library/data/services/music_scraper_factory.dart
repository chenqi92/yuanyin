import '../../domain/entities/scraper_source_entity.dart';
import '../../domain/interfaces/music_scraper.dart';
import 'scrapers/kugou_scraper.dart';
import 'scrapers/kuwo_scraper.dart';
import 'scrapers/migu_scraper.dart';
import 'scrapers/musicbrainz_scraper.dart';
import 'scrapers/netease_scraper.dart';
import 'scrapers/qq_music_scraper.dart';

/// 音乐刮削器工厂
class MusicScraperFactory {
  MusicScraperFactory._();

  /// 根据刮削源配置创建刮削器实例
  static MusicScraper create(ScraperSourceEntity source) => switch (source.type) {
        ScraperType.musicBrainz => MusicBrainzScraper(),
        ScraperType.acoustId => throw UnimplementedError('AcoustID 需要指纹服务'),
        ScraperType.neteaseMusic => NeteaseScraper(cookie: source.cookie),
        ScraperType.qqMusic => QQMusicScraper(cookie: source.cookie),
        ScraperType.kugouMusic => KugouScraper(),
        ScraperType.kuwoMusic => KuwoScraper(),
        ScraperType.miguMusic => MiguScraper(),
        ScraperType.musicTagWeb => throw UnimplementedError('MusicTagWeb 暂不支持'),
      };

  /// 检查刮削源类型是否已实现
  static bool isImplemented(ScraperType type) => [
        ScraperType.musicBrainz,
        ScraperType.neteaseMusic,
        ScraperType.qqMusic,
        ScraperType.kugouMusic,
        ScraperType.kuwoMusic,
        ScraperType.miguMusic,
      ].contains(type);

  /// 获取所有已实现的刮削源类型
  static List<ScraperType> get implementedTypes => [
        ScraperType.musicBrainz,
        ScraperType.neteaseMusic,
        ScraperType.qqMusic,
        ScraperType.kugouMusic,
        ScraperType.kuwoMusic,
        ScraperType.miguMusic,
      ];
}
