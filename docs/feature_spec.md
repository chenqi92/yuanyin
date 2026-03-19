# 猿音 (YuanYin) — 功能规格与技术路线

> **项目名称**: yuanyin  
> **App 名称**: 猿音  
> **域名**: music.kkape.com  
> **代码仓库**: workspace-freq/yuanyin  
> **框架**: Flutter (跨平台：iOS / Android，未来可扩展至 macOS / Windows)  
> **版本**: v0.1.0 (初始规划)  
> **最后更新**: 2026-03-19

---

## 一、产品定位

**猿音**是一款面向个人 NAS 用户的高品质音乐播放器，强调：

1. **多源聚合** — 聚合 NAS（Synology/QNAP）、SMB/WebDAV/FTP/SFTP/NFS/UPnP、本机媒体库、媒体服务器（Jellyfin/Emby/Plex）等多种音乐来源
2. **专业级播放** — 双解码引擎、无缝切歌、交叉淡化、无损格式全支持
3. **智能元数据** — 八源刮削 + 音频指纹识别，自动完善歌曲信息
4. **沉浸体验** — iOS 灵动岛/Live Activity、iOS 26 原生玻璃质感、Android 灵动岛、全新 UI

---

## 二、功能清单

### 2.1 音乐源管理

| 功能 | 描述 | 来源 |
|------|------|------|
| NAS 设备连接 | Synology DSM 6/7、QNAP、绿联(逆向)、飞牛 fnOS | my-nas `nas_adapters/` |
| 通用协议 | SMB/CIFS、WebDAV、FTP、SFTP、NFS | my-nas `nas_adapters/smb/webdav/` 等 |
| UPnP/DLNA 发现 | 自动发现局域网媒体设备 | my-nas `nas_adapters/` |
| 本机媒体库 | iOS Apple Music 库 / Android MediaStore | my-nas `mobile_music_file_system.dart` |
| 媒体服务器 | Jellyfin / Emby / Plex API 对接 | my-nas `media_server_adapters/` |
| 统一文件系统接口 | `NasFileSystem` 抽象接口统一所有后端 | my-nas `nas_adapters/base/` |
| 源配置管理 | 添加/编辑/删除/排序，OAuth/API Key/用户名密码认证 | my-nas `features/sources/` |
| 自动连接 | 启动时自动连接已保存的源 | my-nas `SourceEntity.autoConnect` |

### 2.2 音乐库与浏览

| 功能 | 描述 |
|------|------|
| 全部歌曲 | 列表/网格视图，支持排序和搜索 |
| 按艺术家浏览 | 自动分组，显示艺术家封面和歌曲数 |
| 按专辑浏览 | 专辑封面、年份、曲目数 |
| 按流派浏览 | 按 Genre 分类 |
| 按年代浏览 | 按发行年份分组 |
| 按文件夹浏览 | 反映 NAS 目录结构 |
| 歌单管理 | 创建/编辑/删除歌单，歌单封面（渐变色） |
| 我的收藏 | 一键收藏/取消，独立收藏列表 |
| 最近播放 | 自动记录最近播放历史 |
| 推荐歌曲 | 基于库随机推荐 |
| 搜索 | 跨来源全文搜索（标题/艺术家/专辑） |
| 音乐库统计 | 歌曲总数、艺术家数、专辑数 |
| 自定义主页布局 | 各区块可配置显示/隐藏/排序 |

### 2.3 播放引擎

| 功能 | 描述 | 关键技术 |
|------|------|----------|
| 双解码引擎 | **just_audio**（原生 AVFoundation/ExoPlayer）+ **media_kit**（FFmpeg 解码） | `just_audio`, `media_kit` |
| 引擎动态切换 | 运行时切换解码引擎，不中断播放体验 | `MusicAudioHandler` 接口抽象 |
| 格式支持 | MP3/AAC/FLAC/WAV/OGG/OPUS/APE/TTA/WMA/DSD/DSF/DFF/MKA/AIFF/M4A | 双引擎互补 |
| NCM 解密 | 自动解密网易云音乐 .ncm 格式 | `NcmDecryptService` |
| 后台播放 | 完整后台音频播放支持 | `audio_service` |
| 播放模式 | 列表循环 / 单曲循环 / 随机播放 | `PlayMode` 枚举 |
| 播放队列 | 添加/移除/重排/下一首插入 | `PlayQueueNotifier` |
| 交叉淡化 | 歌曲切换时平滑过渡（可配置时长） | 辅助 AudioPlayer 预加载 |
| 音频缓存 | 持久化缓存已播放音频，避免重复下载 | `MusicAudioCacheService` |
| 媒体代理 | 本地 HTTP 代理服务器中转 NAS 音频流 | `MediaProxyServer` |
| 音频会话管理 | 来电暂停、耳机拔出暂停、Duck 降音 | `AudioSession` |
| FLAC 自动修复 | 检测损坏的 FLAC 文件并尝试修复 | `FlacRepairedNeedRetryException` |
| 进度持久化 | 定期保存播放状态，重启后恢复 | `MusicFavoritesService` |
| 音量控制 | 独立音量控制 + 设置持久化 | `MusicSettingsProvider` |

### 2.4 元数据刮削

| 刮削源 | 类型 | 特点 |
|--------|------|------|
| MusicBrainz | 国际 | 开放数据库，精确匹配 |
| AcoustID | 音频指纹 | Chromaprint 指纹比对，识别未知歌曲 |
| QQ 音乐 | 中文 | 华语歌曲覆盖率高 |
| 网易云音乐 | 中文 | 元数据丰富，歌词匹配 |
| 酷狗音乐 | 中文 | 歌词库全面 |
| 酷我音乐 | 中文 | 高清封面 |
| 咪咕音乐 | 中文 | 版权资源丰富 |
| 通用 Web 刮削 | 通用 | 可扩展的网页解析 |

**刮削功能特性：**
- 自动批量刮削（`MusicScraperManagerService`）
- 手动逐曲精细刮削（`ManualMusicScraperPage`）
- 刮削源优先级排序（`MusicScraperSourcesPage`）
- 可配置匹配策略（`MusicScrapeOptions`）
- 元数据写入队列（`MusicTagWriteQueueService`）
- 安全写入锁（防止并发写入损坏文件）
- 多种写入后端：audiotags（Rust Native）、FFmpeg（跨平台备选）

### 2.5 歌词系统

| 功能 | 描述 |
|------|------|
| LRC 解析 | 支持 LRC 格式时间轴歌词 |
| 多源歌词匹配 | 从刮削源获取歌词 |
| 实时歌词滚动 | 播放时自动滚动高亮当前行 |
| 歌词视图 | 全屏歌词展示 |
| 桌面歌词（macOS） | 独立悬浮窗口，亚克力/透明效果 |
| 桌面歌词（Windows） | 原生 Win32 窗口实现 |
| 歌词样式设置 | 字体大小、颜色、动画效果 |

### 2.6 平台集成

#### iOS
| 功能 | 描述 | 关键技术 |
|------|------|----------|
| 灵动岛 / Live Activity | 显示歌曲信息、进度、封面、控制按钮 | 自定义 MethodChannel + ActivityKit |
| 控制中心/锁屏 | Now Playing 信息 + 播放控制 | `audio_service` + MPNowPlayingInfoCenter |
| iOS 26 玻璃质感 | **全新** — 原生 Liquid Glass 设计语言 | 待实现（iOS 26 SDK） |
| 蓝牙/AirPods 控制 | 耳机线控（上一首/下一首/暂停） | AudioSession RemoteCommand |
| 媒体小组件 | 主屏小组件显示当前播放 | WidgetKit + `WidgetDataService` |

#### Android
| 功能 | 描述 | 关键技术 |
|------|------|----------|
| 灵动岛 | 自定义悬浮通知栏，模拟灵动岛效果 | `AndroidDynamicIslandService` |
| 通知栏控制 | MediaStyle 通知 + 播放控制 | `audio_service` |
| 蓝牙耳机控制 | 耳机线控支持 | AudioSession |

### 2.7 音频指纹

| 功能 | 描述 |
|------|------|
| Chromaprint FFI | 通过 dart:ffi 调用 Chromaprint 原生库 |
| 桌面端指纹 | macOS/Windows/Linux 通过 FFmpeg 提取 PCM 后计算 |
| 移动端指纹 | 通过 MediaCodec / AVFoundation 解码后计算 |
| AcoustID 识别 | 将指纹提交到 AcoustID/MusicBrainz 识别歌曲 |

### 2.8 播放辅助

| 功能 | 描述 |
|------|------|
| 迷你播放器 | 底部常驻迷你播放条 |
| 全屏播放页 | 大封面 + 歌词 + 完整控制 |
| 播放队列面板 | 滑出式队列，支持拖拽重排 |
| 播放设置面板 | 引擎选择、交叉淡化、音效、灵动岛开关等 |

---

## 三、技术架构

### 3.1 整体架构

```
┌─────────────────────────────────────────────────────────┐
│                    Presentation Layer                     │
│  Pages │ Widgets │ Providers (Riverpod) │ Theme System    │
├─────────────────────────────────────────────────────────┤
│                      Domain Layer                        │
│  Entities │ Interfaces │ Use Cases                        │
├─────────────────────────────────────────────────────────┤
│                       Data Layer                         │
│  Services │ Scrapers │ Repositories │ Cache               │
├─────────────────────────────────────────────────────────┤
│                    Platform Layer                         │
│  NAS Adapters │ Media Adapters │ Native Plugins           │
├────────────┬────────────┬───────────────────────────────┤
│    iOS     │  Android   │  macOS / Windows (未来)         │
└────────────┴────────────┴───────────────────────────────┘
```

### 3.2 技术栈

| 层级 | 技术选型 | 说明 |
|------|----------|------|
| **UI 框架** | Flutter 3.x (SDK ^3.10.1) | 跨平台 UI |
| **状态管理** | Riverpod 2.x | 响应式状态 + Provider |
| **路由** | go_router | 声明式路由 |
| **网络** | Dio + Retrofit | HTTP 客户端 + 代码生成 |
| **本地存储** | Hive CE + SQLite (sqflite) | 轻量 KV + 关系型数据库 |
| **安全存储** | flutter_secure_storage | 密码/Token 加密存储 |
| **音频播放** | just_audio + media_kit | 双引擎互补 |
| **后台音频** | audio_service | 后台播放 + 系统媒体控制 |
| **多媒体** | FFmpeg (ffmpeg_kit_flutter) | 转码/元数据/PCM 提取 |
| **元数据读写** | audio_metadata_reader + audiotags | 读取 + 原生写入 |
| **音频指纹** | Chromaprint (dart:ffi) | 音频指纹计算 |
| **Live Activity** | 自定义 MethodChannel + ActivityKit | iOS 灵动岛 |
| **DLNA/投屏** | dlna_dart + shelf HTTP | UPnP 投屏 |
| **SMB 协议** | smb_connect (fork 修复 OOM) | Windows 共享 |
| **WebDAV** | webdav_client | WebDAV 协议 |
| **mDNS 发现** | bonsoir | 局域网设备发现 |
| **数据序列化** | freezed + json_serializable | 不可变模型 + JSON |
| **代码生成** | build_runner | 各类注解的代码生成 |

### 3.3 核心依赖包清单

```yaml
# === 音频核心 ===
just_audio: ^0.9.42              # 主解码引擎 (AVFoundation/ExoPlayer)
media_kit: ^1.1.11               # 副解码引擎 (FFmpeg)
audio_service: (本地 fork)         # 后台播放 (修复 iOS playbackState bug)
audio_session: ^0.1.25           # 音频会话管理
audio_metadata_reader: ^1.4.2    # 元数据读取
audiotags: (本地 fork)             # 元数据写入 (修复 macOS SDK 兼容性)

# === 音频指纹 ===
# Chromaprint 通过 dart:ffi 绑定，无 pub 依赖

# === FFmpeg ===
ffmpeg_kit_flutter_new: (本地 fork)  # FFmpeg v8.0.0 (原项目已退役)

# === NAS / 协议 ===
smb_connect: (本地 fork)          # SMB/CIFS (修复移动端 OOM)
webdav_client: ^1.2.2            # WebDAV
dio: ^5.8.0+1                    # HTTP 客户端

# === Live Activity / 灵动岛 ===
live_activities: ^2.3.0          # iOS Live Activity
app_links: ^6.3.3                # Deep Link (灵动岛控制)

# === UI ===
flutter_animate: ^4.5.2          # 动画
flutter_acrylic: ^1.1.4          # 亚克力/透明窗口效果
cached_network_image: ^3.4.1     # 网络图片缓存

# === 存储 ===
hive_ce: ^2.10.1                 # KV 存储
sqflite: ^2.4.2                  # SQLite
flutter_secure_storage: ^9.2.4   # 安全存储

# === 工具 ===
encrypt: ^5.0.3                  # 加密
charset_converter: ^2.3.0        # 字符编码
enough_convert: ^1.6.0           # 扩展编码支持
```

### 3.4 本地 Fork 包说明

| 包名 | Fork 原因 | 位置 |
|------|-----------|------|
| `audio_service` | 修复 iOS playbackState 不设置的 Bug (#1139) | `packages/audio_service_fixed` |
| `audiotags` | libaudiotags.a 与 macOS 26.1 SDK 不兼容，iOS 链接问题 | `packages/audiotags_fixed` |
| `ffmpeg_kit_flutter` | 原项目 2025年1月退役，使用 FFmpeg v8.0.0 | `packages/ffmpeg_kit_flutter_fixed` |
| `smb_connect` | 修复移动端大文件传输 OOM | `packages/smb_connect` |

---

## 四、从 my-nas 拆分的模块映射

| my-nas 路径 | 猿音目标路径 | 说明 |
|-------------|-------------|------|
| `features/music/` | `lib/features/player/` | 播放引擎核心 |
| `features/music/data/services/scrapers/` | `lib/features/scraper/` | 刮削器独立模块 |
| `features/music/data/services/fingerprint/` | `lib/features/fingerprint/` | 指纹识别模块 |
| `features/music/data/services/lyric_service.dart` | `lib/features/lyric/` | 歌词模块 |
| `features/music/data/services/desktop_lyric_*` | `lib/features/lyric/desktop/` | 桌面歌词 |
| `features/music/data/services/live_activity_service.dart` | `lib/features/platform/ios/` | iOS 平台集成 |
| `features/music/data/services/android_dynamic_island_*` | `lib/features/platform/android/` | Android 平台集成 |
| `features/sources/` | `lib/features/sources/` | 数据源管理 |
| `nas_adapters/` | `lib/adapters/` | NAS / 协议适配层 |
| `core/services/media_proxy_server.dart` | `lib/core/services/` | 媒体代理 |
| `shared/` | `lib/shared/` | 共享工具 |

---

## 五、UI 设计方向

### 5.1 设计理念

- **iOS 26 Liquid Glass** — 全面拥抱 Apple 新设计语言，半透明玻璃质感、深度模糊、光影折射
- **大气沉浸** — 全屏封面背景染色 + 毛玻璃叠加，视觉层次丰富
- **动效驱动** — 微交互、页面转场、播放状态变化均有精心设计的动画
- **暗色优先** — 默认暗色主题，亮色作为可选项
- **自适应布局** — 手机/平板/桌面三形态自适应

### 5.2 核心页面

| 页面 | 描述 |
|------|------|
| **主页** | Hero 当前播放卡片 + 快捷入口 + 推荐 + 最近播放 + 歌单 |
| **浏览页** | 艺术家/专辑/流派/文件夹/年代分类网格 |
| **搜索页** | 实时搜索 + 搜索历史 + 搜索建议 |
| **播放器页** | 全屏大封面 + 歌词 + 控制区 + 波形可视化 |
| **歌词页** | 全屏歌词滚动视图 |
| **队列页** | 播放队列管理（滑出面板） |
| **歌曲列表页** | 各分类的歌曲列表 |
| **歌单详情页** | 歌单封面 + 歌曲列表 |
| **刮削管理页** | 自动/手动刮削 + 源优先级设置 |
| **源管理页** | NAS/协议源的添加/编辑/管理 |
| **设置页** | 播放引擎/缓存/灵动岛/歌词/外观等设置 |
| **迷你播放器** | 底部常驻播放条（全局） |

### 5.3 iOS 26 特效清单

| 特效 | 应用场景 |
|------|----------|
| Liquid Glass Tabs | 底部导航栏 |
| Glass Material | 迷你播放器、卡片背景 |
| Fluid Transitions | 页面转场 |
| Variable Blur | 播放器页背景 |
| Haptic Feedback | 交互反馈 |
| Dynamic Island | 播放状态 + 快捷控制 |

---

## 六、项目目录结构（规划）

```
yuanyin/
├── lib/
│   ├── main.dart                     # App 入口
│   ├── app/
│   │   ├── router/                   # 路由配置
│   │   ├── theme/                    # 主题系统（Liquid Glass）
│   │   └── di/                       # 依赖注入
│   ├── core/
│   │   ├── config/                   # App 配置
│   │   ├── errors/                   # 错误处理
│   │   ├── services/                 # 核心服务（媒体代理等）
│   │   ├── utils/                    # 工具类
│   │   └── extensions/               # 扩展方法
│   ├── features/
│   │   ├── player/                   # 播放引擎
│   │   │   ├── data/services/        # 播放服务
│   │   │   ├── domain/entities/      # 播放实体
│   │   │   └── presentation/         # 播放器 UI
│   │   ├── library/                  # 音乐库浏览
│   │   │   ├── data/                 # 库数据服务
│   │   │   ├── domain/               # 库实体
│   │   │   └── presentation/         # 库 UI
│   │   ├── scraper/                  # 元数据刮削
│   │   │   ├── data/services/        # 刮削器实现
│   │   │   ├── domain/               # 刮削实体
│   │   │   └── presentation/         # 刮削管理 UI
│   │   ├── lyric/                    # 歌词
│   │   │   ├── data/services/        # 歌词服务
│   │   │   ├── domain/               # 歌词实体
│   │   │   └── presentation/         # 歌词 UI
│   │   ├── fingerprint/              # 音频指纹
│   │   │   └── data/services/        # 指纹计算服务
│   │   ├── sources/                  # 数据源管理
│   │   │   ├── data/                 # 源数据服务
│   │   │   ├── domain/               # 源实体
│   │   │   └── presentation/         # 源管理 UI
│   │   ├── playlist/                 # 歌单
│   │   ├── favorites/                # 收藏
│   │   ├── search/                   # 搜索
│   │   ├── settings/                 # 设置
│   │   └── platform/                 # 平台集成
│   │       ├── ios/                  # iOS 灵动岛/Live Activity
│   │       └── android/              # Android 灵动岛
│   ├── adapters/                     # NAS / 协议适配层
│   │   ├── base/                     # 抽象接口
│   │   ├── synology/                 # Synology API
│   │   ├── qnap/                     # QNAP API
│   │   ├── smb/                      # SMB/CIFS
│   │   ├── webdav/                   # WebDAV
│   │   ├── ftp/                      # FTP/SFTP
│   │   ├── upnp/                     # UPnP/DLNA
│   │   ├── local/                    # 本地文件系统
│   │   └── mobile/                   # 移动设备媒体库
│   └── shared/
│       ├── models/                   # 共享模型
│       ├── widgets/                  # 共享组件
│       └── services/                 # 共享服务
├── packages/                         # 本地 Fork 依赖
│   ├── audio_service_fixed/
│   ├── audiotags_fixed/
│   ├── ffmpeg_kit_flutter_fixed/
│   └── smb_connect/
├── ios/
│   └── Runner/
│       └── MusicLiveActivityWidget/  # iOS Live Activity 扩展
├── android/
│   └── app/
│       └── src/main/                 # Android 灵动岛原生代码
├── assets/
│   ├── images/
│   ├── icons/
│   └── animations/
└── docs/
    ├── feature_spec.md               # ← 本文档
    └── ui_design/                    # UI 设计稿（待填充）
```

---

## 七、开发阶段规划

### Phase 1 — 基础框架 🏗️
- [ ] 项目初始化（Flutter create + 基础配置）
- [ ] 主题系统搭建（暗色主题 + Liquid Glass 基础样式）
- [ ] 路由架构
- [ ] 状态管理骨架（Riverpod）
- [ ] 核心实体迁移（MusicItem / Playlist / Artist / Album）

### Phase 2 — 播放引擎 🎵
- [ ] 双引擎迁移（just_audio + media_kit）
- [ ] AudioHandler 抽象接口
- [ ] 播放队列管理
- [ ] 后台播放（audio_service）
- [ ] 音频会话管理
- [ ] 播放状态持久化
- [ ] 交叉淡化
- [ ] NCM 解密

### Phase 3 — 数据源 📡
- [ ] NasFileSystem 接口迁移
- [ ] Synology / QNAP 适配器
- [ ] SMB / WebDAV 适配器
- [ ] 本机媒体库适配器
- [ ] 源管理 UI
- [ ] 媒体代理服务器

### Phase 4 — 音乐库 📚
- [ ] 音乐库数据库服务
- [ ] 分类浏览（艺术家/专辑/流派/文件夹/年代）
- [ ] 收藏 / 最近播放
- [ ] 歌单管理
- [ ] 搜索

### Phase 5 — 刮削系统 🔍
- [ ] 刮削器接口 + 工厂
- [ ] 8 源刮削器迁移
- [ ] Chromaprint 指纹
- [ ] 元数据写入服务
- [ ] 自动/手动刮削 UI

### Phase 6 — 歌词 📝
- [ ] LRC 解析器
- [ ] 多源歌词获取
- [ ] 实时滚动歌词视图
- [ ] 桌面歌词（macOS / Windows）

### Phase 7 — 平台集成 📱
- [ ] iOS Live Activity / 灵动岛
- [ ] iOS 26 Liquid Glass 适配
- [ ] Android 灵动岛
- [ ] iOS/macOS 媒体小组件
- [ ] 蓝牙/耳机控制

### Phase 8 — UI 精打细磨 ✨
- [ ] 全部页面 UI 实现
- [ ] 动画 / 转场 / 微交互
- [ ] 平板适配
- [ ] 性能优化

---

## 八、与 my-nas 的关系

猿音是从 my-nas 音乐功能**完全独立拆分**的新项目：

- **代码复用方式**：直接迁移核心逻辑代码，而非引用。迁移后根据独立 App 需求重构。
- **共享的 Fork 包**：`packages/` 下的本地 fork 包将共享使用或各自维护副本。
- **UI 全新设计**：不复用 my-nas 的任何 UI 代码，完全重新设计。
- **my-nas 音乐功能**：拆分后 my-nas 可保留基础播放能力或引导用户安装猿音。
