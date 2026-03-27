# 猿音 2026 改版参考拆解

更新时间：2026-03-27

## 参考对象

### Apple Music
- 官方页强调沉浸式播放、Dolby Atmos、Lossless 与超大曲库。
- 设计上最值得学的是“播放器优先级很高”，封面、歌词、播放状态、音质信息都被当成核心体验，而不是设置里的附属功能。
- 对猿音的启发：
  - 全屏播放器必须更有舞台感。
  - 音质、采样率、来源等高级信息应该被看见。
  - 歌词入口要更自然，不能藏太深。

来源：
- https://www.apple.com/apple-music/

### Spotify
- 官方 Newsroom 一直在强化个性化，例如 Taste Profile、Listening Stats、Discover Weekly、daylist 这类能力。
- Spotify 的核心不是“信息多”，而是“首页永远有东西可点、可播、可发现”。
- 对猿音的启发：
  - 首页不能只是功能入口集合，要有“继续听”“最近播放”“一键随机”“当前状态”等即时模块。
  - 快捷入口需要更像内容卡，而不是普通功能按钮。
  - 播放队列和下一首推荐要更容易触达。

来源：
- https://newsroom.spotify.com/2026-03-13/taste-profile-beta-announcement/
- https://newsroom.spotify.com/2025-11-06/spotify-new-feature-listening-stats/

### YouTube Music
- 官方博客强调 mood/activity chips、自定义电台、Samples 短片流，以及播放器里的评论、定时歌词、radio steering。
- 它最值得学的是“发现路径非常短”，用户总能从一个轻量动作进入播放。
- 对猿音的启发：
  - 首页要有更轻的探索入口，比如随机播放、最近播放、类型入口、推荐区。
  - 搜索和推荐应该更强调“立刻播放”，而不是先进入二级页。
  - 播放器底部工具栏要更像操作台，而不是两个孤立图标。

来源：
- https://blog.youtube/news-and-events/get-started-youtube-music/
- https://blog.youtube/news-and-events/youtube-music-brings-personalization-your-everyday-moods-and-moments/

### TIDAL
- 官方支持文档持续强调音质层级、下载质量、Dolby Atmos、设备与播放设置。
- 它的差异化不在花哨，而在“高保真能力被明确表达”。
- 对猿音的启发：
  - NAS 与本地无损库是猿音的核心卖点，必须在界面里被视觉化。
  - 设置页、播放器和来源页都应该让用户感知到“当前是高品质、本地、自建库”。
  - 来源管理页要像控制台，而不是普通表单列表。

来源：
- https://support.tidal.com/hc/de/articles/360003650917-Klangqualit%C3%A4tsstufe-%C3%A4ndern
- https://support.tidal.com/hc/no/articles/17412130162961-HiRes-FLAC-lyd

## 结论：猿音不该抄谁

猿音不是流媒体订阅产品，也不是泛娱乐平台。它更像：
- Apple Music 的沉浸播放
- Spotify 的首页动线
- YouTube Music 的轻探索
- TIDAL 的高音质表达

但要保持自己的差异化：NAS、本地库、刮削、歌词、来源管理、双引擎播放。

## 设计原则

1. 首页做“正在发生什么”
- 打开就能继续播放、快速进入最近听过的内容、直接随机开播。

2. 音乐库做“结构化控制中心”
- 用更强的信息层级呈现歌曲、专辑、艺术家、歌单和统计，而不是单一列表。

3. 播放器做“沉浸式舞台”
- 封面、背景、歌词、音质、来源、队列都围绕当前歌曲组织。

4. 音质与来源做“可感知资产”
- 让用户明显感觉到自己播放的是 NAS / 本地 / 无损内容，这是猿音区别于通用播放器的品牌感。

5. 视觉语言统一
- 不再混用“普通深色列表”“iOS 设置页”“卡片页”三种风格。
- 统一为暖色高光 + 深海底色 + 玻璃分层 + 大标题 + 强封面视觉。
