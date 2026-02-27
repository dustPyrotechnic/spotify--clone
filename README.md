<div align="center">

# Spotify Clone iOS

**一款仿 Spotify 设计风格的 iOS 音乐播放器**

*Objective-C · MVC · 三层音频缓存 · AVFoundation · WCDB*

![Platform](https://img.shields.io/badge/Platform-iOS%2026-black?style=flat-square&logo=apple)
![Language](https://img.shields.io/badge/Language-Objective--C%20%2B%20Swift%206-orange?style=flat-square)
![Architecture](https://img.shields.io/badge/Architecture-MVC-blue?style=flat-square)
![License](https://img.shields.io/badge/License-Educational-green?style=flat-square)

</div>

---

## 目录

- [项目简介](#项目简介)
- [技术亮点](#技术亮点)
- [架构设计](#架构设计)
- [功能模块](#功能模块)
- [技术栈](#技术栈)
- [数据流设计](#数据流设计)
- [项目结构](#项目结构)
- [快速开始](#快速开始)
- [开发进度](#开发进度)

---

## 项目简介

本项目是一个仿照 Spotify 设计风格、基于网易云音乐 API 实现的 iOS 音乐播放器客户端。采用 **Objective-C + Swift 混编**，以 MVVM 架构驱动业务逻辑，并自主设计了一套三层音频缓存体系（内存分段 → 临时文件 → 持久化），实现边下边播与离线缓存。

> ⚠️ 本项目仅供学习交流，不涉及任何商业行为。音乐版权归各原始版权方所有。

---

## 技术亮点

### 1. 自研三层音频缓存架构

```
┌─────────────────────────────────────────────────────────────────────┐
│                       XCAudioCacheManager（统一门面）                 │
├──────────────┬──────────────────────┬──────────────────────────────┤
│   L1 内存层   │      L2 临时层        │         L3 持久层             │
│              │                      │                              │
│ NSCache 分段  │   /tmp 目录临时文件   │   ~/Library/Caches 永久文件   │
│ 512KB / 段   │   最大 500 MB        │   最大 1 GB                  │
│ 上限 100 MB  │   7 天自动过期        │   LRU 策略淘汰               │
│              │                      │                              │
│ 快速命中      │   切歌时合并 L1 写入  │   验证完整性后由 L2 晋升       │
└──────────────┴──────────────────────┴──────────────────────────────┘
```

- **分段粒度**：每段 512 KB，平衡网络请求次数与内存碎片
- **数据流转**：L1(NSCache 分段) → L2(临时文件合并) → L3(完整缓存晋升)
- **LRU 清理**：L3 层基于播放时间戳，超限后从最久未播放的歌曲开始驱逐
- **线程安全**：URL 映射表采用 `dispatch_barrier_async` + `dispatch_sync` 的并发读写策略
- **格式兼容**：自动感知原始 URL 扩展名，兼容 mp3/flac/aac 等多种格式

```objc
// 完整的切歌保存流程：L1 → L2 → L3（如果完整则晋升）
- (XCAudioFileCacheState)saveAndFinalizeSong:(NSString *)songId
                                expectedSize:(NSInteger)expectedSize;
```

---

### 2. AVAssetResourceLoaderDelegate 流式拦截

基于 `AVAssetResourceLoaderDelegate` 实现 AVPlayer 音频请求的全链路拦截：

```
原始 URL (https://)
      │  URL 转换
      ▼
自定义 Scheme URL (streaming://songId?url=originalURL)
      │  AVPlayer 触发资源加载
      ▼
XCResourceLoaderManager 拦截
      ├─▶ 命中 L3/L2 → 直接返回本地文件 URL
      └─▶ 未命中 → 发起网络请求 + 边下边存 L1
```

- 将原始 `https://` 改写为自定义 `streaming://` scheme，强制触发 ResourceLoader
- 从自定义 URL 中解析 `songId` 和 `originalURL`，完整保留原始信息
- 支持 HTTP Range 请求，满足 AVPlayer 分段请求的需要

---

### 3. 智能预加载队列

`XCPreloadManager` 实现了优先级驱动的预加载调度：

| 特性 | 实现方式 |
|------|---------|
| 优先级队列 | `XCPreloadPriorityHigh/Normal/Low` 三档优先级 |
| 并发控制 | `maxConcurrentTasks` 可配置，默认 1 个并发 |
| 分段限制 | `preloadSegmentLimit` 仅预加载前 N 段（约 1.5 MB），保证秒播 |
| 进度回调 | `XCPreloadProgressBlock` 实时回调已加载段数/总段数 |
| 智能调度 | `setCurrentPlayingSong:` 自动将下一首提升为高优先级 |

```objc
// 播放时自动触发下一首预加载
[preloadManager setCurrentPlayingSong:currentSongId];
[preloadManager setNextPlayingSong:nextSongId]; // 高优先级预加载
```

---

### 4. WCDB 三表规范化播放列表

本地播放列表使用腾讯 **WCDB** 实现，设计遵循数据库第三范式：

```
┌──────────────────┐    ┌──────────────────────────┐    ┌───────────────┐
│    playlists      │    │  playlist_song_relations  │    │     songs     │
├──────────────────┤    ├──────────────────────────┤    ├───────────────┤
│ albumId (PK)     │◄──┤ playlistId (FK)           ├──►│ songId (PK)   │
│ name             │    │ songId (FK)               │    │ name          │
│ coverUrl         │    │ addedTime                 │    │ artist        │
│ createTime       │    └──────────────────────────┘    │ duration      │
│ updateTime       │                                    │ ...           │
└──────────────────┘                                    └───────────────┘
```

- **多对多设计**：歌曲只存一份，通过 relation 表关联多个播放列表
- **孤立清理**：`cleanOrphanSongs` 方法自动清理无 relation 引用的歌曲记录
- **「喜爱的歌曲」保护**：固定 `albumId = "favorites"`，删除操作对其无效
- **双协议数据模型**：`XC_YYSongData` 同时遵循 `<YYModel>` 和 `<WCTTableCoding>`，一个类兼顾 JSON 解析和 WCDB 持久化

```objc
// 数据模型同时支持 JSON → Model 和 WCDB 持久化
@interface XC_YYSongData : NSObject <YYModel, WCTTableCoding>
WCDB_PROPERTY(songId)  // WCDB 字段绑定
WCDB_PROPERTY(name)
// ...
@end
```

---

### 5. 双 API + KeyChain 安全认证

```
┌────────────────────────────────────────────────────────┐
│                   XCNetworkManager                      │
├───────────────────────┬────────────────────────────────┤
│   Spotify 官方 API    │    网易云音乐 API（第三方）       │
│                       │                                 │
│ · Client Credentials  │ · 搜索（/cloudsearch）          │
│   Token 获取          │ · 播放 URL（/song/url/v1）       │
│ · 新专辑列表          │ · 搜索建议（/search/suggest）    │
│ · 专辑详情            │ · 热搜榜（/search/hot/detail）  │
│ · Token → KeyChain   │                                 │
└───────────────────────┴────────────────────────────────┘
```

- **Token 全生命周期管理**：获取 → KeyChain 存储 → 过期刷新 → 主动注销
- **失败重试**：静态变量记录重试计数，最多 10 次，指数退避策略
- **通用请求封装**：`authType` 参数控制认证级别（无需认证 / 账号 Token）
- **安全存储**：Spotify Token 通过 `UICKeyChainStore` 写入系统 Keychain，不落磁盘明文

---

### 6. 锁屏控制 & 后台播放

完整集成 iOS 系统级媒体控制：

```
MPNowPlayingInfoCenter    →  锁屏/控制中心显示封面、歌名、进度
MPRemoteCommandCenter     →  耳机线控 / CarPlay 播放/暂停/上下曲
AVAudioSession            →  后台播放模式，支持息屏连续收听
```

---

### 7. 搜索三态 UI 设计

`XCSearchViewController` 实现了业界标准的搜索三状态切换：

```
┌──────────────┐     输入文字      ┌──────────────┐    回车确认    ┌──────────────┐
│   初始状态    │ ──────────────► │   建议状态    │ ──────────► │   结果状态    │
│              │                  │              │               │              │
│  热搜榜 Top10│                  │ 实时搜索建议  │               │ 歌曲/专辑列表 │
│  搜索历史    │  ◄──────────── │ 防抖 0.5s    │  ◄─────────  │ 分页加载     │
└──────────────┘     清空输入      └──────────────┘    返回上级    └──────────────┘
```

---

## 架构设计

标准 iOS MVC：**Controller** 持有 View 和 Model，自身实现 TableView/CollectionView Delegate，业务逻辑与数据处理分别下沉到 Model 层和单例服务层。

```
┌──────────────────────────────────────────────────────────────────┐
│                        Controller Layer                          │
│  HomePageViewController   XCMusicPlayerViewController           │
│  XCSearchViewController   XCPersonalViewController              │
│  （实现 UITableViewDelegate / UICollectionViewDelegate 等）       │
└───────────┬──────────────────────────┬───────────────────────────┘
            │ 持有 & 驱动               │ 持有 & 驱动
┌───────────▼──────────┐  ┌────────────▼──────────────────────────┐
│      View Layer       │  │             Model Layer               │
│                       │  │                                       │
│  HomePageView         │  │  HomePageViewModel   （数据 + 请求）  │
│  XCMusicPlayerView    │  │  XCMusicPlayerModel  （播放引擎单例） │
│  XCSearchView         │  │  XCPersonalModel     （列表管理）     │
│  XCPersonalView       │  │  XC_YYSongData / XC_YYAlbumData      │
└───────────────────────┘  └───────────┬───────────────────────────┘
                                       │ 调用
                        ┌──────────────▼──────────────────────────┐
                        │           Service Layer（单例）           │
                        │  XCNetworkManager   （网络 + Token）     │
                        │  XCAudioCacheManager（L1 / L2 / L3）    │
                        │  XCPlaylistDatabaseManager（WCDB）       │
                        │  XCPreloadManager   （预加载调度）        │
                        └─────────────────────────────────────────┘
```

---

## 功能模块

| 模块 | 状态 | 技术要点 |
|------|------|---------|
| 主页专辑浏览 | ✅ 完成 | TableView + CollectionView 嵌套，下拉刷新，SDWebImage 异步加载 |
| 音乐播放器 | ✅ 完成 | AVPlayer，后台播放，锁屏控制，进度条，迷你播放条 |
| 网络层 | ✅ 完成 | AFNetworking，双 API，Token 管理，KeyChain 存储 |
| 三层音频缓存 | ✅ 完成 | NSCache 分段(L1) + 临时文件(L2) + 持久缓存(L3)，LRU 清理 |
| 智能预加载 | ✅ 完成 | 优先级队列，并发控制，进度回调 |
| 个人播放列表 | ✅ 完成 | WCDB 三表设计，「喜爱的歌曲」保护，封面动态更新 |
| 专辑详情页 | ✅ 完成 | 歌曲列表，点击直接进入播放器 |
| 搜索功能 | ✅ 完成 | 三态 UI，热搜榜，实时建议，防抖，分页 |
| Stream 拦截器 | 🚧 框架完成 | AVAssetResourceLoaderDelegate，URL scheme 转换 |
| 音乐库 / 新发现 / 广播 | ❌ 待开发 | 预留入口，UI 框架搭建中 |

---

## 技术栈

### 核心框架

| 框架 | 用途 |
|------|------|
| `UIKit` | 界面构建 |
| `AVFoundation` | 音频播放引擎 |
| `MediaPlayer` | 锁屏信息 & 远程控制 |
| `Foundation` | 数据处理 & 并发 |

### 第三方依赖（CocoaPods）

| 库 | 版本 | 用途 |
|----|------|------|
| `AFNetworking` | 4.0.1 | HTTP 网络请求封装 |
| `Masonry` | 1.1.0 | AutoLayout 链式 DSL |
| `SDWebImage` | 5.21.3 | 图片异步加载 & 缓存 |
| `YYModel` | 1.0.4 | JSON → Model 高性能解析 |
| `WCDB.objc` | 2.1.15 | 腾讯开源高性能 SQLite ORM |
| `UICKeyChainStore` | 2.2.1 | Keychain 安全存储 |
| `ChameleonFramework` | 2.1.0 | 动态颜色主题 |
| `LookinServer` | 1.2.8 | UI 层级实时调试 |

---

## 数据流设计

### 音频播放数据流

```
用户点击播放
     │
     ▼
XCMusicPlayerModel
     │
     ├─ 查询 XCAudioCacheManager
     │       ├─ L3 命中 → 返回本地文件 URL → AVPlayer 直接播放
     │       ├─ L2 命中 → 返回临时文件 URL → AVPlayer 播放 + 后台验证
     │       └─ 未命中 → 请求网络 URL → XCResourceLoaderManager 拦截
     │                        │
     │                        └─ 边下载 → 存入 L1 分段
     │                                  → 切歌时合并到 L2
     │                                  → 验证完整后晋升 L3
     │
     └─ AVPlayer 开始播放
           │
           ├─ MPNowPlayingInfoCenter 更新锁屏信息
           └─ XCMusicPlayerAccessoryView 更新迷你播放条
```

### 搜索数据流

```
用户输入关键词
     │
     ▼ (0.5s 防抖)
XCNetworkManager.searchSuggestFromWY:
     │
     ▼
建议列表 → XCSearchSuggestionCell 展示
     │
     ▼ (用户确认)
XCNetworkManager.searchFromWY:type:offset:limit:
     │
     ▼
YYModel 解析 JSON → XC_YYSongData 数组
     │
     ▼
XCSearchResultViewController 展示结果列表
```

---

## 项目结构

```
Spotify - clone/
├── 1. 主页部分/
│   ├── HomePageViewController        # 主页控制器（5个Section横向滚动）
│   ├── HomePageView                  # 主页视图（TableView + CollectionView嵌套）
│   ├── HomePageViewModel             # 主页业务逻辑
│   └── cells/                        # TableView & CollectionView Cell
│
├── 5. TabBar附加视图，搜索部分/
│   ├── 1. 音乐播放器/
│   │   ├── XCMusicPlayerAccessoryView    # 底部迷你播放条
│   │   └── 音乐播放详细页面/
│   │       ├── XCMusicPlayerModel        # 播放器业务逻辑（核心）
│   │       ├── XCMusicPlayerView         # 全屏播放器 UI
│   │       └── XCMusicPlayerViewController
│   └── 2. 搜索/
│       ├── XCSearchViewController        # 搜索控制器（三态切换）
│       ├── XCSearchView                  # 搜索界面布局
│       └── cells/                        # 建议/结果 Cell
│
├── 6. 网络请求部分/
│   └── XCNetworkManager              # 网络单例（Spotify + 网易云 双API）
│
├── 8. 个人播放列表界面/
│   ├── XCPersonalViewController      # 播放列表管理控制器
│   ├── XCPersonalView                # 播放列表 UI
│   └── cells/                        # 列表/歌曲 Cell
│
├── 9. 拦截缓存管理/
│   └── XCResourceLoaderManager       # AVAssetResourceLoaderDelegate 拦截器
│
├── 10. 内存缓存/
│   └── XCMusicMemoryCache            # NSCache 内存缓存（早期版本，已由11模块替代）
│
├── 11. 音频缓存/                      ⭐ 核心模块
│   ├── XCAudioCacheManager           # 三层缓存统一门面
│   ├── XCAudioCacheConst             # 常量定义（段大小/容量限制/枚举）
│   ├── XCAudioCachePathUtils         # 路径工具（感知文件格式）
│   ├── XCPreloadManager              # 预加载调度器
│   ├── L1/ XCMemoryCacheManager      # NSCache 分段内存管理
│   ├── L2/ XCTempCacheManager        # 临时文件管理
│   ├── L3/ XCPersistentCacheManager  # 持久化缓存管理
│   │   └── XCCacheIndexManager       # LRU 索引管理
│   └── Tests/                        # 8个阶段的缓存系统单元测试
│
├── 数据库/
│   ├── XCPlaylistDatabaseManager     # WCDB 三表播放列表管理器
│   └── XCPlaylistSongRelation        # 多对多关联模型
│
└── 数据结构/
    ├── XC-YYSongData                 # 歌曲模型（YYModel + WCTTableCoding 双协议）
    └── XC-YYAlbumData                # 专辑模型
```

---

## 快速开始

### 环境要求

- Xcode 26+
- iOS 26 真机或模拟器
- CocoaPods 1.15+

### 安装步骤

```bash
# 克隆项目
git clone <repo-url>
cd "Spotify - clone"

# 安装依赖
pod install

# 用 .xcworkspace 打开
open "Spotify - clone.xcworkspace"
```

### 配置 API

在 `XCNetworkManager.m` 中配置你的 Spotify Client ID / Secret，以及网易云 API 服务地址：

```objc
// Spotify OAuth2 Client Credentials
static NSString * const kSpotifyClientId     = @"your_client_id";
static NSString * const kSpotifyClientSecret = @"your_client_secret";

// 网易云第三方 API 地址
static NSString * const kWYBaseURL = @"https://your-netease-api.com";
```

---

## 开发进度

```
总体完成度 ████████████████░░░░ 80%

核心播放器   ████████████████████ 100%
三层音频缓存 ████████████████████ 100%  ← 技术核心
个人播放列表 ████████████████████ 100%
网络层      ████████████████████ 100%
搜索功能    ███████████████░░░░░  75%
拦截器      ████████░░░░░░░░░░░░  40%（框架完成，分段填充逻辑待接入）
音乐库/发现 ░░░░░░░░░░░░░░░░░░░░   0%（预留入口）
```

---

<div align="center">

*本项目是一次对 iOS 音频缓存工程化的系统性实践，架构设计、技术选型与代码注释均力求专业规范。*

</div>
