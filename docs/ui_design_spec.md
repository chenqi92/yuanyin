# 猿音 (YuanYin) — UI 与 UE 详细设计规范 (v0.1.0)

本规范基于 `feature_spec.md` 提供的技术路线与产品定位，为“猿音”设计了一套面向高品质个人 NAS 音乐播放器的界面与交互标准。设计语言核心聚焦于 **iOS 26 Liquid Glass (液态玻璃)** 风格、**暗色优先 (Dark First)** 及 **无缝动效 (Fluid Animation)**。

---

## 一、 全局设计原语 (Design Tokens)

为了确保开发过程中的高度复用与一致性，定义以下基础设计 Token。

### 1.1 颜色系统 (Color Palette)

系统以深色模式为基准，利用高反差和半透明玻璃效果构建层级。

| 颜色变量名 | 用途 | 色值 (Hex / RGBA) | 备注 |
| :--- | :--- | :--- | :--- |
| `Bg_Base` | 应用程序最底层纯黑背景 | `#000000` | 极致省电，提供最高对比度 |
| `Bg_Glass_Thick`| 厚玻璃背景 (如底部导航栏) | `rgba(28, 28, 30, 0.75)` | 需配合 `blur(40px)` 使用 |
| `Bg_Glass_Thin` | 薄玻璃背景 (如列表项卡片) | `rgba(44, 44, 46, 0.4)` | 需配合 `blur(20px)` 使用 |
| `Text_Primary` | 主标题、核心数据 | `#FFFFFF` | 纯白 |
| `Text_Secondary`| 副标题、描述内容 | `rgba(235, 235, 245, 0.6)` | iOS systemGray |
| `Text_Tertiary` | 占位符、次要图标 | `rgba(235, 235, 245, 0.3)` | 辅助说明文本 |
| `Accent_Primary`| 核心交互色 (默认) | `#0A84FF` | iOS Blue，但建议运行时**从专辑封面提取主题色 (Dynamic Color)** 来替代 |
| `Status_Success`| 连接成功、在线状态 | `#32D74B` | 绿点提示 |
| `Status_Error` | 连接失败、离线状态 | `#FF453A` | 红点提示 |

### 1.2 排版与字体 (Typography)

* **优选字体**: `SF Pro Display` (iOS) / `Inter` (Android/Windows)。
* **字重阶梯**:
  * **全屏播放曲目名**: 28sp / Bold / 行高 1.2 (自动跑马灯)
  * **模块大标题 (H1)**: 24sp / Bold / 行高 1.3
  * **列表主标题 (H2)**: 17sp / SemiBold / 行高 1.4
  * **列表副标题/正文 (Body)**: 15sp / Regular / 行高 1.4
  * **辅助说明 (Caption)**: 12sp / Medium / 行高 1.2

### 1.3 阴影与圆角 (Shadows & Radii)

* **圆角 (Border Radius)**:
  * 全屏播放器封面: `12px` (带极细 `0.5px rgba(255,255,255,0.1)` 描边防溢色)
  * 卡片/列表项: `16px`
  * 底部弹窗 (BottomSheet): `顶部左右 24px`
* **阴影 (Drop Shadow)**:
  * 专辑封面悬浮: `0px 16px 32px rgba(0,0,0, 0.5)`
  * (玻璃质感往往不需要强阴影，依靠背后元素的模糊程度区分层级)

---

## 二、 核心图标系统 (SF Symbols 映射表)

采用统一的 iOS SF Symbols 图标库。Flutter 侧建议使用 `cupertino_icons` 或专门的第三方 SF 符号插件。

| 功能节点 | 图标名称 (SF Symbol) | 样式要求 |
| :--- | :--- | :--- |
| **底部导航** |
| - 首页 | `house` / `house.fill` | 未选中采用 outline，选中采用 fill |
| - 音乐库 | `square.grid.2x2` / `square.grid.2x2.fill` | 同上 |
| - 搜索 | `magnifyingglass` / `sparkle.magnifyingglass` | 同上，融入 AI/聚合搜索感 |
| - 设置 | `gearshape` / `gearshape.fill` | 同上 |
| **数据源** |
| - NAS 设备 | `server.rack` | 搭配 `Status_Success` 绿点 |
| - SMB/本地 | `externaldrive.connected.to.line.below` |
| - 刷新刮削 | `arrow.triangle.2.circlepath` | 旋转动画 |
| **播放控制** |
| - 播放 / 暂停 | `play.fill` / `pause.fill` | 全屏页尺寸为 `64x64` |
| - 上一首/下一首 | `backward.fill` / `forward.fill` | 尺寸为 `32x32` |
| - 循环模式 | `repeat` / `repeat.1` | 激活状态使用 `Accent_Primary` 取色 |
| - 随机播放 | `shuffle` | 激活状态使用 `Accent_Primary` 取色 |
| **辅助控制** |
| - 歌词 | `quote.bubble` / `quote.bubble.fill` |
| - 播放队列 | `list.bullet` |
| - 心跳/收藏 | `heart` / `heart.fill` | 收藏状态强制变红 (`#FF453A`)，附带弹跳动效 |

---

## 三、 核心页面结构与 UE 描述

### 3.1 全局容器：Liquid Glass 导航框架

* **视觉层级**: 
  1. (最底层) 滚动的内容列表。
  2. (中间层) 底部的 Mini 播放器。
  3. (最顶层) 底部导航栏 TabBar。
* **交互细节**: Mini 播放器与 TabBar 合体，背景统一采用 `Bg_Glass_Thick` 厚玻璃材质。当列表内容滑动经过底部区域时，内容会在模糊的磨砂玻璃后方呈现流动的色彩变幻，体现“水滴/液态”质感。

### 3.2 迷你播放器 (Mini Player) - 悬浮常驻

* **UI 布局**: 位于 TabBar 上方，留出 8px 左右间距，或者与 TabBar 融为一体。
* **元素排列 (自左向右)**:
  * **封面微缩图**: 40x40px，圆角 6px，顺时针缓慢旋转 (可选)。
  * **文字区**:
    * 歌曲名 (15sp, `Text_Primary`, 溢出截断)。
    * 艺术家 (12sp, `Text_Secondary`)。
  * **播放控件**: 播放/暂停键 (`play.fill`, 24sp)。
  * **右侧**: 队列按钮 (`list.bullet`, 20px) 或者直接点击整个 Bar 展开。
* **交互 (UE)**: 
  * **上划 / 轻点**: 触发 Hero 动画，专辑封面平滑放大并移至屏幕中央，迷你播放器背景展开为全屏播放页。
  * **长按**: 触觉反馈 (Haptic Light)，呼出快捷菜单（添加到歌单、屏蔽等）。

### 3.3 全屏播放页 (Now Playing)

* **视觉效果**: 极具沉浸感。获取当前专辑封面的主色调，对全屏背景进行深度高斯模糊 (`Filter.blur(sigmaX: 100, sigmaY: 100)`)，外加 40% 的黑色遮罩压暗，以确保上方白字清晰可见。
* **布局规范**:
  1. **顶部栏**: 下滑折叠指示条 (`capsule`), 源角标 (如显示小小的 Synology Logo 或文字 "Playing from NAS")。
  2. **核心视觉区 (Hero)**: 正方形专辑封面，宽度占屏幕 `80%`，圆角 12px。具有强烈的下拉阴影。
  3. **信息区**: 左对齐。歌曲名称加大 (28sp, Bold)，下方紧跟艺术家。右侧放置收藏按钮 (`heart`)。
  4. **进度条区**: 极细进度条 (`2px` 高度)，当前进度部分为 `Accent_Primary`。拖拽点仅在按下时放大。支持左右滑动进度条两端时间文本快速微调。
  5. **主控区**: 循环、上一首、**播放/暂停 (大尺寸圆形按钮)**、下一首、随机。
  6. **底部操作栏**: 歌词入口、AirPlay/投屏开关、音频引擎切换指引 (如果需要向高级用户展示)、队列页滑出入口。

* **交互 (UE)**:
  * **下滑封面区**: 随手指移动，封面逐渐缩小变回迷你播放器的尺寸，背景模糊度逐渐降低。手指离开时，由物理引擎 (Spring Animation) 计算回弹或完成收起。
  * **左右滑动封面**: 快速切换上一首/下一首，伴随着线性的不透明度渐变动效。
  * **播放/暂停**: 封面缩放动效（播放时封面比例 `1.0`，暂停时封面微微后退缩小至 `0.9`，仿佛失去动力）。
  * **动效要求**: `flutter_animate` 需应用在切歌时，封面从左侧/右侧滑入并具有 Fade 效果。

### 3.4 音乐源管理页 (Source Management)

由于本项目支持极其复杂的 8 源挂载，源管理界面的清晰度极为关键。
* **UI 布局**: 列表形式，每个源为一个 Glass Card。
* **卡片内容**: 
  * 左侧：大号源图标 (如 `server.rack` 为 NAS，`cloud` 为 WebDAV)。
  * 中间上方：源名称 (如 "我的绿联 NAS")。
  * 中间下方：连接地址或状态 (如 `192.168.1.100` / `已挂载 - 1.2w首歌曲`)。
  * 右侧：状态指示灯点 (`Status_Success` / `Status_Error`) 及设置齿轮。
* **交互 (UE)**:
  * 首次添加数据源采用**底部抽屉 (Bottom Sheet)** 层层递进：选择协议 (NAS/SMB/WebDAV) -> 填写配置 (IP/账号/密码) -> 测试连接 -> 挂载成功动画。
  * **左滑卡片**: 露出红色底色及垃圾桶图标 (`trash.fill`)，执行删除或断开挂载操作（需二次确认弹窗）。
  * **长按拖拽**: 上下重排数据源的优先级（将影响多源匹配和全局搜索时的优先加载顺序）。

### 3.5 全屏歌词页 (Lyrics View)

* **视觉**: 全屏幕模糊背景，隐藏大部分控制元素，最大化突出文字。
* **排版**:
  * 过去歌词：`Text_Tertiary`，字体微缩。
  * **当前高亮歌词**：`Text_Primary`，字号扩大至 24sp，**加粗**。
  * 未来歌词：`Text_Secondary`。
* **交互 (UE)**:
  * **实时滚动**: 平滑滚动，而不是生硬的跳行。过渡动画 `duration: 300ms, curve: Curves.easeOutCubic`。
  * **手动拖拽**: 用户在屏幕上拖拽时，屏幕中央出现一根播放线及对应时间，用户松手后，音乐**精准 Seek** 到该时间进度。拖出动作 3 秒后无操作自动恢复自动滚动。

---

## 四、 iOS / Android 平台级交互规范 (Platform Integration)

考虑到 `feature_spec.md` 中提到对灵动岛等特性的强烈诉求，此部分对开发者实现至关重要。

### 4.1 iOS 灵动岛 (Dynamic Island)
利用 `live_activities` 插件实现：
* **Compact Presentation (收起态)**: 
  * 左侧区域：显示正在播放的专辑封面（极其微小，边缘切圆）。
  * 右侧区域：音频频谱动画（波形跳动图标）。
* **Expanded Presentation (展开态)**:
  * 顶部中心：高亮显示当前解码引擎 (如 "Hi-Res Lossless" 或 "just_audio")。
  * 中部：大号专辑封面、曲名、艺术家。
  * 底部：控制条（上一首、暂停/播放中心放大、下一首）。
  * 背景配置为暗色模糊并随音乐封面动态染色。

### 4.2 触觉反馈 (Haptics)
* **ImpactLight**: 添加到常规按钮点击 (如播放控制、列表切换)。
* **ImpactMedium**: 用于音乐源挂载成功、刮削完成、添加到收藏。
* **ImpactHeavy**: 用于发生错误 (如连接 NAS 失败、解码失败弹窗)。

---

## 五、 状态机与边界情况处理

为了确保产品稳定性，设计需明确容错状态的 UI 展现：

| 场景 | UI/UE 处理方案 |
| :--- | :--- |
| **无网络 / 离线** | NAS/网络源变为灰色半透明，封面显示离线缓存占位图，点击播放弹出“源不可用，是否尝试播放缓存？”提示。 |
| **歌曲无封面** | 使用动态生成的抽象几何渐变图 (Gradient Mesh) 作为封面，根据歌曲名的 Hash 值决定颜色，避免界面突兀发黑。 |
| **正在刮削** | 源卡片或曲目旁出现微弱跳动的圆形 Loading 动画圈，不阻塞用户继续浏览页面。 |
| **FLAC 损坏重试** | 播放控件短暂变为 Loading 菊花，并在屏幕上方通过轻量级 SnackBar 提示 “正在尝试切换解码引擎修复...” |
