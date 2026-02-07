# 音乐本地缓存架构设计方案

> 文档状态: 设计阶段  
> 创建日期: 2026-02-07  
> 目标版本: v1.0

---

## 1. 设计目标

### 核心需求
- **离线播放**: 已缓存歌曲无需网络即可播放
- **智能预加载**: 根据用户行为预缓存即将播放的歌曲
- **存储管理**: 自动管理缓存空间，避免占用过多磁盘
- **无缝切换**: 网络状态变化时自动切换数据源（在线/离线）
- **数据完整性**: 确保缓存文件完整可用

### 性能指标
| 指标 | 目标值 |
|------|--------|
| 缓存读取速度 | < 50ms |
| 缓存命中率 | > 70% |
| 最大缓存容量 | 可配置，默认 1GB |
| 单文件大小限制 | 20MB |
| 并发下载数 | 最多 3 个 |

---

## 2. 整体架构

```
┌─────────────────────────────────────────────────────────────────┐
│                      XCMusicCacheManager                        │
│                     (缓存管理器 - 单例)                          │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │ MemoryCache │  │ DiskCache   │  │   PreloadManager        │  │
│  │  (内存缓存)  │  │  (磁盘缓存)  │  │   (预加载管理)           │  │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘  │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │ DownloadQueue│  │ CachePolicy │  │   CacheCleanupTask      │  │
│  │  (下载队列)  │  │  (缓存策略)  │  │   (清理任务)             │  │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
            ┌─────────────────┼─────────────────┐
            ▼                 ▼                 ▼
    ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
    │  XCMusicPlayer│  │  XCResource  │  │   WCDB       │
    │    Model      │  │   Loader     │  │  (元数据)     │
    └──────────────┘  └──────────────┘  └──────────────┘
```

---

## 3. 模块详细设计

### 3.1 MemoryCache (内存缓存)

**职责**: 缓存当前及即将播放的歌曲数据，提供快速读取

**实现方案**:
```objc
@interface XCMemoryCache : NSObject

// 使用 NSCache 实现自动内存管理
@property (nonatomic, strong) NSCache<NSString *, NSData *> *cache;

// 当前播放歌曲的缓存区间（用于流式播放）
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSRange> *cachedRanges;

// 核心方法
- (NSData *)dataForSongId:(NSString *)songId;
- (void)setData:(NSData *)data forSongId:(NSString *)songId;
- (void)preloadData:(NSData *)data forSongId:(NSString *)songId range:(NSRange)range;
- (void)clearCache;

@end
```

**特点**:
- 使用 `NSCache` 自动响应内存警告
- 限制单个缓存项大小（10MB）
- 优先缓存当前播放歌曲的前 30 秒数据

---

### 3.2 DiskCache (磁盘缓存)

**职责**: 持久化存储已下载的完整歌曲文件

**存储结构设计**:
```
/Library/Caches/XCMusicCache/
├── index.db                 # 缓存索引数据库 (WCDB)
├── temp/                    # 下载中的临时文件
│   └── {songId}.tmp
├── audio/                   # 已完成的音频文件
│   └── {hash_prefix}/       # 按 hash 前 2 位分目录，避免单目录文件过多
│       └── {songId}.mp3
└── metadata/                # 歌曲元数据缓存
    └── {songId}.json
```

**缓存索引表结构**:
```sql
CREATE TABLE cache_index (
    song_id TEXT PRIMARY KEY,           -- 歌曲唯一标识
    file_path TEXT NOT NULL,            -- 文件路径
    file_size INTEGER,                  -- 文件大小（字节）
    total_size INTEGER,                 -- 歌曲总大小（字节）
    cache_status INTEGER,               -- 0:下载中 1:完整 2:部分
    download_progress REAL,             -- 下载进度 0.0-1.0
    created_at TIMESTAMP,               -- 创建时间
    accessed_at TIMESTAMP,              -- 最后访问时间
    access_count INTEGER DEFAULT 0,     -- 访问次数
    is_favorite BOOLEAN DEFAULT 0,      -- 是否收藏（收藏歌曲优先保留）
    bitrate INTEGER                     -- 音质码率
);

-- 索引
CREATE INDEX idx_accessed ON cache_index(accessed_at);
CREATE INDEX idx_favorite ON cache_index(is_favorite);
```

**核心类设计**:
```objc
@interface XCDiskCache : NSObject

@property (nonatomic, assign) NSUInteger maxCacheSize;      // 最大缓存大小，默认 1GB
@property (nonatomic, assign) NSUInteger currentCacheSize;  // 当前缓存大小

// 查询
- (BOOL)isCached:(NSString *)songId;
- (BOOL)isFullyCached:(NSString *)songId;
- (NSString *)filePathForSongId:(NSString *)songId;
- (double)downloadProgressForSongId:(NSString *)songId;

// 写入
- (void)writeData:(NSData *)data forSongId:(NSString *)songId offset:(NSUInteger)offset;
- (void)finalizeDownloadForSongId:(NSString *)songId totalSize:(NSUInteger)totalSize;

// 读取
- (NSData *)readDataForSongId:(NSString *)songId offset:(NSUInteger)offset length:(NSUInteger)length;
- (NSInputStream *)inputStreamForSongId:(NSString *)songId;

// 删除
- (void)removeCacheForSongId:(NSString *)songId;
- (void)removeAllCache;

@end
```

---

### 3.3 PreloadManager (预加载管理器)

**职责**: 智能预测用户行为，预缓存即将播放的歌曲

**预加载策略**:
```objc
typedef NS_ENUM(NSInteger, XCPreloadStrategy) {
    XCPreloadStrategyConservative,   // 保守：仅缓存下一首
    XCPreloadStrategyNormal,         // 标准：缓存下两首
    XCPreloadStrategyAggressive      // 激进：缓存下五首
};

@interface XCPreloadManager : NSObject

@property (nonatomic, assign) XCPreloadStrategy strategy;
@property (nonatomic, assign) BOOL onlyOnWiFi;      // 仅在 WiFi 下预加载
@property (nonatomic, assign) NSUInteger maxConcurrentPreloads; // 最大并发预加载数

// 播放列表变化时调用
- (void)updatePlaylist:(NSArray<XC_YYSongData *> *)playlist currentIndex:(NSInteger)index;

// 手动触发预加载
- (void)preloadSongs:(NSArray<NSString *> *)songIds;

// 取消预加载
- (void)cancelPreloadForSongId:(NSString *)songId;
- (void)cancelAllPreloads;

@end
```

**预加载优先级队列**:
1. **P0 - 紧急**: 用户点击的下一首
2. **P1 - 高**: 播放列表中的下一首
3. **P2 - 中**: 播放列表中接下来的 2-3 首
4. **P3 - 低**: 推荐歌曲

---

### 3.4 DownloadQueue (下载队列)

**职责**: 管理所有下载任务，支持断点续传

**设计要点**:
```objc
@interface XCDownloadQueue : NSObject

@property (nonatomic, assign) NSUInteger maxConcurrentDownloads;

// 添加下载任务
- (XCDownloadTask *)addDownloadTask:(NSString *)songId 
                                url:(NSURL *)url
                           priority:(XCDownloadPriority)priority
                    completionHandler:(void (^)(BOOL success, NSError *error))completion;

// 控制任务
- (void)pauseTask:(NSString *)songId;
- (void)resumeTask:(NSString *)songId;
- (void)cancelTask:(NSString *)songId;

// 查询状态
- (XCDownloadStatus)statusForTask:(NSString *)songId;
- (double)progressForTask:(NSString *)songId;

@end

// 下载任务实体
@interface XCDownloadTask : NSObject
@property (nonatomic, copy) NSString *songId;
@property (nonatomic, strong) NSURL *url;
@property (nonatomic, assign) XCDownloadPriority priority;
@property (nonatomic, assign) XCDownloadStatus status;
@property (nonatomic, assign) NSUInteger downloadedBytes;
@property (nonatomic, assign) NSUInteger totalBytes;
@property (nonatomic, strong) NSURLSessionDownloadTask *sessionTask;
@end
```

**断点续传实现**:
- 使用 `HTTP Range` 请求头
- 临时文件命名：`{songId}.tmp`
- 定期保存下载进度到数据库

---

### 3.5 CachePolicy (缓存策略)

**职责**: 决定何时缓存、缓存什么、保留多久

```objc
@interface XCCachePolicy : NSObject

// 容量限制
@property (nonatomic, assign) NSUInteger maxDiskCacheSize;      // 默认 1GB
@property (nonatomic, assign) NSUInteger maxMemoryCacheSize;    // 默认 50MB
@property (nonatomic, assign) NSUInteger maxSingleFileSize;     // 默认 20MB

// 缓存条件
@property (nonatomic, assign) BOOL cacheOnlyOnWiFi;             // 是否仅在 WiFi 下缓存
@property (nonatomic, assign) BOOL autoCleanWhenLowStorage;     // 低存储时自动清理
@property (nonatomic, assign) NSUInteger minFreeStorageSpace;   // 最小剩余空间，默认 500MB

// 生命周期
@property (nonatomic, assign) NSTimeInterval maxCacheAge;       // 最大缓存时间，默认 30 天
@property (nonatomic, assign) NSUInteger maxCacheFiles;         // 最大缓存文件数，默认 500

// 智能策略
@property (nonatomic, assign) BOOL preferCacheFavorites;        // 优先缓存收藏歌曲
@property (nonatomic, assign) BOOL preferCacheHighBitrate;      // 优先缓存高音质
@property (nonatomic, assign) NSUInteger maxCachePerArtist;     // 单个艺人最大缓存数

@end
```

---

### 3.6 CacheCleanupTask (缓存清理任务)

**职责**: 定期清理过期或低价值的缓存

**清理策略** (按优先级排序):

1. **过期文件**: 超过 `maxCacheAge` 且非收藏
2. **超大文件**: 超过 `maxSingleFileSize` 且很少播放
3. **LRU 淘汰**: 按最后访问时间排序，删除最久未访问的
4. **LFU 淘汰**: 按访问次数排序，删除访问最少的
5. **紧急清理**: 存储空间不足时，优先删除部分缓存/未完成任务

**权重计算公式**:
```
保留分数 = (是否收藏 * 1000) 
         + (访问次数 * 10) 
         + (文件完整度 * 100)
         - (距今天数 * 5)
         - (文件大小 / 1MB)
```

---

## 4. 与现有系统集成

### 4.1 与 XCMusicPlayerModel 集成

修改 `XCMusicPlayerModel` 的播放逻辑，优先使用缓存:

```objc
// XCMusicPlayerModel.m

- (void)playSong:(XC_YYSongData *)song {
    NSString *songId = song.songId;
    
    // 1. 检查内存缓存
    NSData *cachedData = [[XCMemoryCache sharedInstance] dataForSongId:songId];
    if (cachedData) {
        [self playWithData:cachedData];
        return;
    }
    
    // 2. 检查磁盘缓存
    if ([[XCDiskCache sharedInstance] isFullyCached:songId]) {
        NSString *filePath = [[XCDiskCache sharedInstance] filePathForSongId:songId];
        NSURL *localUrl = [NSURL fileURLWithPath:filePath];
        [self playWithURL:localUrl];
        return;
    }
    
    // 3. 检查部分缓存
    if ([[XCDiskCache sharedInstance] isPartiallyCached:songId]) {
        // 使用缓存 + 网络流式播放
        [self playWithPartialCache:songId remoteURL:song.audioURL];
        return;
    }
    
    // 4. 纯网络播放
    [self playWithURL:song.audioURL];
    
    // 5. 触发后台下载
    [[XCMusicCacheManager sharedInstance] downloadAndCacheSong:song priority:XCDownloadPriorityHigh];
}
```

### 4.2 与 XCResourceLoaderManager 集成

`XCResourceLoaderManager` 是现有的资源加载管理器，需要改造支持缓存代理:

```objc
// 新增缓存资源加载器
@interface XCCacheResourceLoader : NSObject <AVAssetResourceLoaderDelegate>

@property (nonatomic, weak) XCMusicCacheManager *cacheManager;

// 处理播放器的数据请求
- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader 
shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest;

@end
```

**数据流向**:
```
AVPlayer 请求数据
    ↓
XCCacheResourceLoader 拦截请求
    ↓
检查磁盘缓存 → 有直接返回
    ↓
无缓存 → 从网络下载
    ↓
边下载边写入缓存 + 返回给播放器
```

---

## 5. 接口设计

### 5.1 XCMusicCacheManager (对外统一接口)

```objc
@interface XCMusicCacheManager : NSObject

+ (instancetype)sharedInstance;

#pragma mark - 配置
@property (nonatomic, strong, readonly) XCCachePolicy *cachePolicy;
- (void)updateCachePolicy:(XCCachePolicy *)policy;

#pragma mark - 查询
- (BOOL)isSongCached:(NSString *)songId;
- (double)cacheProgressForSong:(NSString *)songId;
- (NSUInteger)totalCachedSize;
- (NSArray<XCCacheInfo *> *)listAllCachedSongs;

#pragma mark - 主动缓存
- (void)downloadAndCacheSong:(XC_YYSongData *)song priority:(XCDownloadPriority)priority;
- (void)downloadAndCacheSongs:(NSArray<XC_YYSongData *> *)songs;
- (void)cancelDownload:(NSString *)songId;

#pragma mark - 预加载
- (void)setPreloadStrategy:(XCPreloadStrategy)strategy;
- (void)preloadNextSongsFromPlaylist:(NSArray *)playlist currentIndex:(NSInteger)index;

#pragma mark - 清理
- (void)removeCacheForSong:(NSString *)songId;
- (void)removeAllCache;
- (void)cleanCacheToSize:(NSUInteger)targetSize;

#pragma mark - 获取播放 URL
- (NSURL *)playbackURLForSong:(XC_YYSongData *)song;

@end
```

---

## 6. 数据模型

### 6.1 XCCacheInfo (缓存信息)

```objc
@interface XCCacheInfo : NSObject

@property (nonatomic, copy) NSString *songId;
@property (nonatomic, copy) NSString *songName;
@property (nonatomic, copy) NSString *artistName;
@property (nonatomic, assign) NSUInteger fileSize;
@property (nonatomic, assign) NSUInteger totalSize;
@property (nonatomic, assign) XCCacheStatus status;
@property (nonatomic, strong) NSDate *cachedDate;
@property (nonatomic, strong) NSDate *lastAccessDate;
@property (nonatomic, assign) NSUInteger accessCount;
@property (nonatomic, assign) BOOL isFavorite;

@property (nonatomic, assign, readonly) double progress;  // fileSize / totalSize
@property (nonatomic, assign, readonly) BOOL isComplete;  // status == XCCacheStatusComplete

@end
```

---

## 7. 时序图

### 7.1 播放歌曲时的缓存流程

```
用户点击播放
    │
    ▼
XCMusicPlayerModel
    │
    ├─ 1. 查询内存缓存 ─────────────────> XCMemoryCache
    │                                         │
    │<─ 2. 命中？返回数据 ────────────────────┤
    │                                         │
    ├─ 3. 查询磁盘缓存 ─────────────────> XCDiskCache
    │                                         │
    │<─ 4. 命中？返回本地文件路径 ─────────────┤
    │                                         │
    ▼
播放本地文件 / 或继续下一步
    │
    ├─ 5. 请求网络播放 ────────────────> XCResourceLoaderManager
    │                                         │
    │<─ 6. 代理给缓存加载器 ──────────────────┤
    │                                         │
    ▼
XCCacheResourceLoader
    │
    ├─ 7. 边下载边缓存 ────────────────> XCDiskCache (写入)
    │                                         │
    │<─ 8. 同时返回数据给播放器 ───────────────┤
    │
    ▼
AVPlayer 播放
```

### 7.2 预加载流程

```
播放列表变更 / 歌曲切换
    │
    ▼
XCPreloadManager
    │
    ├─ 1. 分析播放列表
    │
    ├─ 2. 确定预加载目标（下 N 首）
    │
    ├─ 3. 检查是否已缓存 ──────────────> XCDiskCache
    │
    ├─ 4. 添加到下载队列 ──────────────> XCDownloadQueue
    │
    │        ┌─────────────────────────────┐
    │        │ 下载任务执行中                │
    │        │  • 断点续传支持               │
    │        │  • 优先级动态调整             │
    │        │  • 进度实时更新               │
    │        └─────────────────────────────┘
    │
    ▼
下载完成 → 更新缓存索引
```

---

## 8. 异常处理

| 异常场景 | 处理策略 |
|---------|---------|
| 下载中断 | 保存进度，支持断点续传 |
| 缓存文件损坏 | MD5 校验失败时重新下载 |
| 存储空间不足 | 触发紧急清理，暂停新下载 |
| 网络切换 (WiFi -> 4G) | 暂停非优先下载，继续播放 |
| 缓存索引损坏 | 重建索引，扫描缓存目录 |
| 后台播放 | 使用 Background Task 完成当前下载 |

---

## 9. 配置建议

### 9.1 默认配置

```objc
// XCCachePolicy 默认配置
{
    maxDiskCacheSize = 1024 * 1024 * 1024;      // 1GB
    maxMemoryCacheSize = 50 * 1024 * 1024;      // 50MB
    maxSingleFileSize = 20 * 1024 * 1024;       // 20MB
    
    cacheOnlyOnWiFi = NO;
    autoCleanWhenLowStorage = YES;
    minFreeStorageSpace = 500 * 1024 * 1024;    // 500MB
    
    maxCacheAge = 30 * 24 * 60 * 60;            // 30天
    maxCacheFiles = 500;
    
    preferCacheFavorites = YES;
    preferCacheHighBitrate = NO;
    maxCachePerArtist = 50;
}
```

### 9.2 用户可配置项

在设置页面提供以下选项:
- 最大缓存容量 (200MB / 500MB / 1GB / 2GB / 无限制)
- 仅在 WiFi 下缓存 (开关)
- 自动清理过期缓存 (开关)
- 音质偏好 (标准 / 高品质 / 无损)
- 一键清理缓存

---

## 10. 实现阶段规划

### Phase 1: 基础缓存 (MVP)
- [ ] 创建 `docs/MUSIC_CACHE_DESIGN.md` (本文档)
- [ ] 实现 XCDiskCache (磁盘缓存基础功能)
- [ ] 实现 XCMemoryCache (内存缓存)
- [ ] 集成到 XCMusicPlayerModel
- [ ] 支持基础断点续传

### Phase 2: 智能预加载
- [ ] 实现 XCPreloadManager
- [ ] 实现播放列表分析
- [ ] 优先级队列下载
- [ ] 网络状态监听与策略切换

### Phase 3: 高级功能
- [ ] 缓存清理策略实现
- [ ] 缓存统计与设置界面
- [ ] 后台下载支持
- [ ] 缓存完整性校验

### Phase 4: 优化
- [ ] 性能调优
- [ ] 内存优化
- [ ] 边界 case 处理
- [ ] 单元测试

---

## 11. 待讨论问题

1. **加密存储**: 是否需要对缓存的音频文件进行加密？（可能影响性能）
2. **多账号**: 是否支持多用户隔离缓存？
3. **缓存共享**: 相同歌曲不同音质是否分别缓存？
4. **云端同步**: 是否需要同步用户的缓存偏好到云端？
5. **统计埋点**: 是否需要统计缓存命中率等数据用于分析？

---

## 12. 附录

### 12.1 参考实现

- [SJMediaCacheServer](https://github.com/changsanjiang/SJMediaCacheServer) - iOS 视频缓存框架
- [KTVHTTPCache](https://github.com/ChangbaDevs/KTVHTTPCache) - 音视频缓存
- [CacheKit](https://github.com/0x11901/CacheKit) - 通用缓存方案

### 12.2 相关 Apple 文档

- [NSURLCache](https://developer.apple.com/documentation/foundation/nsurlcache)
- [AVAssetResourceLoader](https://developer.apple.com/documentation/avfoundation/avassetresourceloader)
- [Background Execution](https://developer.apple.com/documentation/uikit/app_and_environment/scenes/preparing_your_ui_to_run_in_the_background)

---

**文档维护**: 请在实现过程中及时更新此文档，确保设计与代码一致。
