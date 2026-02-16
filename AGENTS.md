# AGENTS.md - Spotify Clone iOS App

> This file contains essential information for AI coding agents working on this project.
> Last updated: 2026-02-07

---

## Project Overview

这是一个 Spotify 克隆版 iOS 音乐播放器应用，主要使用 Objective-C 编写，支持 Swift 6.0。应用采用 MVVM 架构模式，实现了音乐浏览、播放、搜索等核心功能。

### Key Features
- 首页专辑展示（横向滚动列表）
- 音乐播放控制（播放/暂停/下一首）
- 个人播放列表管理
- 搜索功能（UISearchController）
- 音频资源缓存管理
- 支持后台音频播放

---

## Technology Stack

### Primary Language
- **Objective-C** (主要开发语言)
- **Swift 6.0** (支持 Swift 模块)

### Build System
- **Xcode Project**: `Spotify - clone.xcodeproj`
- **Workspace**: `Spotify - clone.xcworkspace` (使用 CocoaPods)
- **Dependency Manager**: CocoaPods 1.16.2

### Target Platform
- **iOS Deployment Target**: 26.1
- **Bundle Identifier**: `xiaochenl894-gmail.com.Spotify---clone`

---

## Dependencies (CocoaPods)

| Pod | Version | Purpose |
|-----|---------|---------|
| AFNetworking | 4.0.1 | 网络请求 |
| Masonry | 1.1.0 | AutoLayout 约束 |
| SDWebImage | 5.21.3 | 图片异步加载与缓存 |
| YYModel | 1.0.4 | JSON 数据模型转换 |
| WCDB.objc | 2.1.15 | 腾讯数据库框架 |
| UICKeyChainStore | 2.2.1 | KeyChain 安全存储 |
| ChameleonFramework | 2.1.0 | 颜色主题管理 |
| LookinServer | 1.2.8 | UI 调试工具（仅调试） |

---

## Project Structure

```
Spotify - clone/
├── AppDelegate.h/m              # 应用委托
├── SceneDelegate.h/m            # 场景委托 (iOS 13+)
├── main.m                       # 程序入口
├── ViewController.h/m           # 默认视图控制器
├── Info.plist                   # 应用配置
├── Assets.xcassets/             # 资源文件
│
├── 1. 主页部分/                  # 首页模块
│   ├── HomePageViewController.h/m
│   ├── HomePageView.h/m
│   ├── HomePageViewModel.h/m
│   └── cells/                   # 单元格子目录
│       ├── HomePageViewCollectionViewTableViewCell
│       ├── HomePageViewVideoTableViewCell
│       └── collectionViewCells/
│           └── HomePageViewCollectionViewCell
│
├── 2. 音乐库部分/                # (预留)
├── 3. 新发现/                    # (预留)
├── 4. 广播部分/                  # (预留)
│
├── 5. TabBar附加视图，搜索部分/   # TabBar 和搜索
│   ├── MainTabBarController.h/m
│   ├── 1. 音乐播放器/
│   │   ├── XCMusicPlayerAccessoryView.h/m    # 底部播放条
│   │   └── 音乐播放详细页面/
│   │       ├── XCMusicPlayerViewController.h/m
│   │       ├── XCMusicPlayerView.h/m
│   │       └── XCMusicPlayerModel.h/m
│   └── 2. 搜索/
│       ├── XCSearchViewController.h/m
│       ├── XCSearchView.h/m
│       └── XCSearchModel.h/m
│
├── 6. 网络请求部分/              # 网络层
│   └── XCNetworkManager.h/m     # 网络管理单例
│
├── 7. 博客界面（swift)/          # Swift 模块
│   └── Spotify - clone-Bridging-Header.h
│
├── 8. 个人播放列表界面/          # 个人播放列表
│   ├── XCPersonalViewController.h/m
│   ├── XCPersonalView.h/m
│   ├── XCPersonalModel.h/m
│   └── cells/
│       └── XCPersonalTableViewCell.h/m
│
├── 9. 拦截缓存管理/              # 资源缓存
│   └── XCResourceLoaderManager.h/m
│
├── 10. 内存缓存/                 # 旧内存缓存（将被音频缓存替代）
│   └── XCMusicMemoryCache.h/m
│
├── 11. 音频缓存/                 # 新音频缓存系统 (Phase 1-6 已完成)
│   ├── XCAudioCacheConst.h       # 常量定义
│   ├── XCAudioCachePathUtils.h/m # 路径管理
│   ├── XCAudioCacheManager.h/m   # Phase 6: 主管理器（三级缓存整合）
│   ├── L1/                       # L1 层：NSCache 分段缓存
│   │   ├── XCAudioSegmentInfo.h/m
│   │   └── XCMemoryCacheManager.h/m
│   ├── L2/                       # L2 层：临时完整歌曲缓存
│   │   └── XCTempCacheManager.h/m
│   ├── L3/                       # L3 层：永久完整歌曲缓存
│   │   ├── XCAudioSongCacheInfo.h/m
│   │   ├── XCCacheIndexManager.h/m
│   │   └── XCPersistentCacheManager.h/m
│   └── Tests/                    # 测试套件
│       ├── XCAudioCachePhase1Test.h/m
│       ├── XCAudioCachePhase2Test.h/m
│       ├── XCAudioCachePhase3Test.h/m
│       ├── XCAudioCachePhase4Test.h/m
│       ├── XCAudioCachePhase5Test.h/m
│       ├── XCAudioCachePhase6Test.h/m
│       └── XCAudioCacheTestRunner.h/m
│
├── 数据结构/                     # 数据模型
│   ├── XC-YYAlbumData.h/m       # 专辑数据模型
│   └── XC-YYSongData.h/m        # 歌曲数据模型
│
└── 详细页面/                     # 专辑详情页
    ├── XCALbumDetailViewController.h/m
    ├── XCALbumDetailView.h/m
    ├── XCALbumDetailModel.h/m
    └── cell/
        ├── XCAlbumDetailCell.h/m
        └── XCAlbumHeadCell.h/m
```

---

## Architecture Pattern

### MVVM 架构
- **View**: 负责 UI 展示 (`HomePageView`, `XCPersonalView` 等)
- **ViewModel**: 负责业务逻辑和数据处理 (`HomePageViewModel`, `XCPersonalModel` 等)
- **Model**: 数据模型 (`XC_YYAlbumData`, `XC_YYSongData`)
- **Controller**: 协调 View 和 ViewModel，处理用户交互

### 单例模式使用
以下关键组件使用饿汉式单例模式：
- `XCNetworkManager` - 网络请求管理
- `XCMusicPlayerModel` - 音乐播放器管理
- `XCResourceLoaderManager` - 资源加载管理

---

## Build and Run

### Prerequisites
- Xcode 16+ (支持 iOS 26.1)
- CocoaPods 1.16.2+
- iOS 26.0+ 模拟器或真机

### Setup Commands
```bash
# 安装依赖
pod install

# 打开工作空间（不要直接打开 xcodeproj）
open "Spotify - clone.xcworkspace"
```

### Build Settings
- **Deployment Target**: 26.0 (通过 post_install 脚本强制覆盖)
- **Swift Version**: 6.0
- **Bridging Header**: `Spotify - clone/7. 博客界面（swift)/Spotify - clone-Bridging-Header.h`

---

## API Configuration

### 使用的 API
1. **Spotify Web API** (官方)
   - 认证: `https://accounts.spotify.com/api/token`
   - 新专辑: `https://api.spotify.com/v1/browse/new-releases`
   - Client ID: `183f5d912f4448519ba2d88416b3ddb1`

2. **Netease Cloud Music API** (第三方)
   - 基础 URL: `https://1390963969-2g6ivueiij.ap-guangzhou.tencentscf.com`
   - 歌单列表: `/top/playlist`
   - 专辑列表: `/album/list`
   - 专辑详情: `/album?id={id}`
   - 歌曲 URL: `/song/url/v1`

### Network Security (Info.plist)
- 允许任意 HTTP 加载 (`NSAllowsArbitraryLoads: true`)
- 特殊域名配置:
  - `p1.music.126.net` - 允许不安全 HTTP
  - `p2.music.126.net` - 允许不安全 HTTP
  - `api.spotify.com` - 需要前向保密

---

## Code Style Guidelines

### 命名规范
- **类名**: XC 前缀 + 功能描述 (如 `XCNetworkManager`)
- **文件组织**: 按功能模块分文件夹，使用中文描述
- **属性**: 使用 `@property` 显式声明，指定 `nonatomic` 或 `atomic`
- **方法**: 使用完整描述性名称，如 `getDataOfPlaylistsFromWY:offset:limit:withCompletion:`

### 代码注释规范
```objc
//
//  文件名
//  项目名
//
//  Created by 红尘一笑 on 日期
//

#pragma mark - 分区标题

/// 属性的文档注释
@property (nonatomic, strong) NSString* propertyName;
```

### 布局方式
- 使用 **Masonry** 进行代码布局（避免使用 Storyboard）
- 系统背景色统一使用 `[UIColor systemBackgroundColor]`
- TabBar 主题色: `[UIColor systemGreenColor]`

---

## Key Components

### 1. XCNetworkManager
网络管理单例，处理：
- Spotify Token 获取与存储（KeyChain）
- 专辑/歌单数据请求
- 歌曲 URL 获取
- 自动重试机制（最多 10 次）

### 2. XCMusicPlayerModel
音乐播放器管理：
- `AVPlayer` 实例管理
- 播放列表管理
- 当前播放歌曲追踪

### 3. XCAudioCacheManager (Phase 6 新增)
音频缓存主管理器，三级缓存架构：
- **L1 (NSCache)**: 内存分段缓存，512KB/段，100MB上限
- **L2 (Tmp)**: 临时完整歌曲，位于 tmp/MusicTemp/
- **L3 (Cache)**: 永久完整缓存，位于 Library/Caches/MusicCache/，1GB上限
- 数据流转：L1 → L2 → L3（切歌时合并，验证后移动）
- 支持 LRU 清理策略
- 使用方式：`[XCAudioCacheManager sharedInstance]`

### 4. MainTabBarController
主 TabBar 控制器，包含 5 个 Tab：
1. Home - 首页
2. Music Warehouse - 音乐库
3. New Founding - 新发现
4. Broad Cast - 广播
5. Search - 搜索

---

## Testing

### 当前状态
- **音频缓存测试**: Phase 1-6 已完成，包含独立测试套件
  - `XCAudioCacheTestRunner` 提供可视化测试菜单
  - 每个 Phase 有独立的测试类（Phase1Test ~ Phase6Test）
- **UI 调试**: 使用 LookinServer 进行 UI 层级调试
- **手动测试**: 通过真机或模拟器进行功能验证

### 音频缓存测试运行方式
```objc
// 运行单个 Phase 测试
[XCAudioCachePhase6Test runAllTests];

// 运行全部测试
[XCAudioCacheTestRunner runAllPhaseTests];

// 显示测试菜单
[XCAudioCacheTestRunner showTestMenuFromViewController:self];
```

### Debug Features
- 控制台日志输出 (NSLog)
- LookinServer UI 检查
- 测试图片: `Spotify - clone/1. 主页部分/1.jpeg`

---

## Security Considerations

### Credentials
⚠️ **警告**: Spotify Client Secret 硬编码在源代码中
```objc
// XCNetworkManager.m
NSString *clientSecret = @"8e3f5...";  // 建议移到安全存储
```

### Data Storage
- Token 存储: 使用 `UICKeyChainStore` 加密存储
- 数据库: WCDB (基于 SQLCipher) 提供加密支持
- 图片缓存: SDWebImage 自动管理

---

## Known Issues and TODOs

### TODO 列表
1. 搜索框变形机制未完成 (`MainTabBarController.m:76`)
2. 图片下载多线程预取 (`HomePageViewController.m:253`)
3. 音乐库、新发现、广播部分尚未实现 (空视图控制器)
4. **音频缓存 Phase 7**: 预加载管理器 (`XCPreloadManager`)
5. **音频缓存 Phase 8**: 与 `XCMusicPlayerModel` 集成

### 注意事项
- 网易云 API 可能不稳定（项目注释："妈生网易云，真他妈难用"）
- 某些歌曲 URL 可能为空（版权/付费限制）

---

## Resources

### Documentation
- [Spotify Web API Docs](https://developer.spotify.com/documentation/web-api)
- [AFNetworking GitHub](https://github.com/AFNetworking/AFNetworking)
- [WCDB 文档](https://github.com/Tencent/wcdb/wiki)

### Asset Resources
- 图标: `XCSptify.icon/icon.json`
- 应用图标: `Assets.xcassets/AppIcon.appiconset`
- 强调色: `Assets.xcassets/AccentColor.colorset`

---

## Contact and Contribution

- **Author**: 红尘一笑
- **Created**: 2025/11/19

For AI agents: When making changes, follow the existing code style, add appropriate comments in Chinese as the project convention, and ensure compatibility with iOS 26.0+.
