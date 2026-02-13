# 音频缓存机制设计方案

## 1. 概述

本文档描述了 Spotify 克隆版应用的三层音频缓存架构设计，旨在实现高效、可靠的音频数据缓存，支持离线播放和流畅的播放体验。

## 2. 设计目标

- **低延迟播放**: 优先从内存加载，减少磁盘 IO
- **节省流量**: 已缓存的歌曲无需重复下载
- **智能预加载**: 播放当前歌曲时预缓存下一首
- **数据完整性**: 确保缓存文件的完整性和有效性
- **资源管理**: 自动清理过期缓存，控制存储空间

## 3. 三层缓存架构

### 3.1 层级结构

```
┌─────────────────────────────────────────────────────────────┐
│                      三级缓存架构                            │
├──────────────┬──────────────┬───────────────────────────────┤
│   L1: NSCache │  L2: Tmp     │     L3: Cache                 │
│   (内存缓存)   │  (临时文件)   │    (永久缓存)                  │
├──────────────┼──────────────┼───────────────────────────────┤
│ • 分段数据    │ • 完整歌曲   │ • 确认完整的歌曲               │
│ • 快速访问    │ • 待确认    │ • 长期保存                     │
│ • LRU淘汰    │ • 临时存储  │ • 用户主动清理                  │
└──────────────┴──────────────┴───────────────────────────────┘
```

### 3.2 各层职责

| 层级 | 存储位置 | 存储内容 | 生命周期 | 容量限制 |
|------|----------|----------|----------|----------|
| L1 | NSCache (内存) | 分段音频数据 | 应用运行期间 | 100MB / 10首 |
| L2 | NSTemporaryDirectory/MusicTmp | 未确认完整的歌曲 | 直到确认完整或下次播放 | 500MB |
| L3 | NSCachesDirectory/MusicCache | 确认完整的歌曲 | 永久（直到用户清理） | 1GB |

## 4. 缓存工作流程

### 4.1 播放时缓存查找流程

```
播放请求
    │
    ▼
┌─────────────────┐
│ 1. 检查 NSCache │ ◄──── 命中？ ──► 直接播放
│    (内存缓存)    │
└─────────────────┘
         │ 未命中
         ▼
┌─────────────────┐
│ 2. 检查 Tmp     │ ◄──── 命中？ ──► 播放 + 验证完整性
│   (临时文件夹)   │
└─────────────────┘
         │ 未命中
         ▼
┌─────────────────┐
│ 3. 检查 Cache   │ ◄──── 命中？ ──► 播放
│   (永久缓存)     │
└─────────────────┘
         │ 未命中
         ▼
┌─────────────────┐
│ 4. 网络请求      │ ────► 边下边播 + 写入 L1 缓存
│   (下载音频)     │
└─────────────────┘
```

### 4.2 数据流转流程

```
网络下载
    │
    ▼
┌─────────────────┐
│ 写入 NSCache    │ ◄──── 分段存储，播放时优先读取
│   (L1 内存缓存)  │
└─────────────────┘
         │
         │ 用户切歌 / 歌曲播放完成
         ▼
┌─────────────────┐
│ 写入 Tmp 文件夹  │ ◄──── 持久化完整数据
│    (L2 临时)     │
└─────────────────┘
         │
         │ 验证完整性（对比 Content-Length / MD5）
         ▼
┌─────────────────┐
│ 移动到 Cache    │ ◄──── 确认为完整文件
│   (L3 永久缓存)  │
└─────────────────┘
```

## 5. 核心模块设计

### 5.1 模块结构

```
┌─────────────────────────────────────────────────────────┐
│                  XCAudioCacheManager                    │
│                   (缓存管理单例)                          │
├─────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  NSCache     │  │   Tmp        │  │   Cache      │  │
│  │  Manager     │  │  Manager     │  │  Manager     │  │
│  │  (L1 内存)    │  │  (L2 临时)   │  │  (L3 永久)   │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
├─────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │   Cache      │  │   Preload    │  │   File       │  │
│  │   Validator  │  │   Manager    │  │   Operation  │  │
│  │   (完整性验证)│  │   (预加载)   │  │   (文件操作) │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### 5.2 类设计

#### 5.2.1 XCAudioCacheManager (主管理器)

```objc
@interface XCAudioCacheManager : NSObject

+ (instancetype)sharedInstance;

#pragma mark - 查询接口
/// 查找缓存，按 L1 -> L2 -> L3 顺序查找
- (NSURL *)cachedURLForSongId:(NSString *)songId;

/// 检查是否存在有效缓存
- (BOOL)hasValidCacheForSongId:(NSString *)songId;

#pragma mark - 写入接口
/// 写入分段数据到 L1 (NSCache)
- (void)storeSegmentData:(NSData *)data 
              forSongId:(NSString *)songId 
               segmentId:(NSUInteger)segmentId;

/// 通知当前歌曲播放完成/切换，触发 L1 -> L2 持久化
- (void)finalizeCurrentSong:(NSString *)songId;

/// 验证 L2 文件完整性后移动到 L3
- (void)confirmAndMoveToCache:(NSString *)songId 
               expectedSize:(NSUInteger)expectedSize;

#pragma mark - 预加载
/// 预加载下一首歌曲
- (void)preloadNextSong:(XC_YYSongData *)song;

@end
```

#### 5.2.2 XCMemoryCacheManager (L1 层)

```objc
@interface XCMemoryCacheManager : NSObject

@property (nonatomic, strong) NSCache<NSString *, NSData *> *segmentCache;

/// 存储分段数据
- (void)storeSegment:(NSData *)data 
          forSongId:(NSString *)songId 
          segmentId:(NSUInteger)segmentId;

/// 获取所有分段并合并
- (NSData *)mergedDataForSongId:(NSString *)songId;

/// 清空指定歌曲的分段缓存
- (void)clearSegmentsForSongId:(NSString *)songId;

@end
```

#### 5.2.3 XCTempCacheManager (L2 层)

```objc
@interface XCTempCacheManager : NSObject

/// 获取临时文件路径
- (NSString *)tempFilePathForSongId:(NSString *)songId;

/// 写入临时文件
- (BOOL)writeData:(NSData *)data toTempFile:(NSString *)songId;

/// 验证临时文件是否完整
- (BOOL)isTempFileComplete:(NSString *)songId expectedSize:(NSUInteger)size;

/// 移动临时文件到 L3
- (BOOL)moveToCache:(NSString *)songId;

@end
```

#### 5.2.4 XCPersistentCacheManager (L3 层)

```objc
@interface XCPersistentCacheManager : NSObject

/// 获取缓存文件 URL
- (NSURL *)cacheFileURLForSongId:(NSString *)songId;

/// 直接写入缓存
- (BOOL)writeData:(NSData *)data forSongId:(NSString *)songId;

/// 清理过期缓存（LRU 策略）
- (void)cleanExpiredCacheWithMaxSize:(NSUInteger)maxSize;

@end
```

## 6. 关键流程详细设计

### 6.1 分段缓存策略

```objc
// 分段存储键值设计
// Key: songId_segmentId (例如: "123456_0", "123456_1")

- (NSString *)keyForSongId:(NSString *)songId segmentId:(NSUInteger)segmentId {
    return [NSString stringWithFormat:@"%@_%lu", songId, segmentId];
}

// 分段大小：256KB / 段
static const NSUInteger kSegmentSize = 256 * 1024;
```

### 6.2 切歌时数据流转

```objc
- (void)handleSongSwitchFrom:(NSString *)currentSongId 
                          to:(NSString *)nextSongId {
    // 1. 将当前歌曲从 L1 写入 L2
    if (currentSongId) {
        NSData *fullData = [self.memoryCache mergedDataForSongId:currentSongId];
        if (fullData) {
            [self.tempCache writeData:fullData toTempFile:currentSongId];
            [self.memoryCache clearSegmentsForSongId:currentSongId];
        }
    }
    
    // 2. 预加载下一首到 L1
    if (nextSongId) {
        [self preloadSong:nextSongId];
    }
}
```

### 6.3 完整性验证策略

```objc
- (BOOL)validateFile:(NSString *)filePath 
      withExpectedSize:(NSUInteger)expectedSize 
             orMD5:(NSString *)expectedMD5 {
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDictionary *attrs = [fm attributesOfItemAtPath:filePath error:nil];
    NSUInteger actualSize = [attrs fileSize];
    
    // 策略1: 文件大小匹配
    if (expectedSize > 0 && actualSize == expectedSize) {
        return YES;
    }
    
    // 策略2: MD5 校验（如果服务端提供）
    if (expectedMD5) {
        NSString *actualMD5 = [self calculateMD5:filePath];
        return [actualMD5 isEqualToString:expectedMD5];
    }
    
    // 策略3: 最小有效大小检查（防止空文件）
    return actualSize > 1024; // 至少 1KB
}
```

## 7. 预加载机制

### 7.1 预加载触发时机

| 时机 | 行为 |
|------|------|
| 开始播放歌曲 A | 检测歌曲 B（下一首）缓存状态 |
| 歌曲 A 播放到 50% | 开始预加载歌曲 B 到 L1 |
| 切换到歌曲 B | 歌曲 A 数据写入 L2，开始加载歌曲 C |
| 播放完成 | 触发当前歌曲 L1 -> L2 写入 |

### 7.2 预加载优先级

```objc
typedef NS_ENUM(NSInteger, XCCachePriority) {
    XCCachePriorityHigh = 0,      // 当前播放歌曲
    XCCachePriorityNormal = 1,    // 下一首（预加载）
    XCCachePriorityLow = 2        // 其他
};

// NSCache cost 调整策略
- (void)setPriority:(XCCachePriority)priority forSongId:(NSString *)songId {
    // 高优先级：增加 cost，降低被淘汰概率
    // 低优先级：减少 cost，优先被淘汰
}
```

## 8. 目录结构设计

### 8.1 文件路径规划

```
App Container/
├── tmp/
│   └── MusicTmp/              # L2 临时缓存
│       ├── song_123456.mp3    # 临时文件（未完成）
│       ├── song_789012.mp3
│       └── ...
│
└── Library/
    └── Caches/
        └── MusicCache/        # L3 永久缓存
            ├── song_123456.mp3   # 完整文件
            ├── song_789012.mp3
            ├── index.plist       # 缓存索引（包含元数据）
            └── ...
```

### 8.2 缓存索引格式

```objc
// index.plist 结构
{
    "cachedSongs": [
        {
            "songId": "123456",
            "fileName": "song_123456.mp3",
            "fileSize": 5242880,
            "createTime": 1700000000,
            "lastAccessTime": 1700000100,
            "accessCount": 5,
            "isComplete": true
        }
    ]
}
```

## 9. 容量管理策略

### 9.1 各层容量控制

| 层级 | 容量限制 | 淘汰策略 |
|------|----------|----------|
| L1 NSCache | 100MB 或 10首 | LRU（系统自动）|
| L2 Tmp | 500MB | FIFO（超过时删除最旧文件）|
| L3 Cache | 1GB | LRU（基于最后访问时间）|

### 9.2 自动清理逻辑

```objc
- (void)performAutoCleanup {
    // L2 清理：保留最近 7 天的文件
    [self.tempCache cleanFilesOlderThan:7 * 24 * 3600];
    
    // L3 清理：LRU 策略，保留总大小在 1GB 以内
    [self.persistentCache cleanExpiredCacheWithMaxSize:1024 * 1024 * 1024];
}
```

## 10. 接口与现有系统集成

### 10.1 与 XCMusicPlayerModel 集成

```objc
// 播放前检查缓存
- (void)playMusicWithId:(NSString *)songId {
    // 1. 查询缓存
    NSURL *cachedURL = [[XCAudioCacheManager sharedInstance] cachedURLForSongId:songId];
    
    if (cachedURL) {
        // 使用本地缓存播放
        [self playWithURL:cachedURL songId:songId];
    } else {
        // 网络播放 + 边下边存
        [self playFromNetworkWithId:songId];
    }
    
    // 2. 触发预加载下一首
    XC_YYSongData *nextSong = [self getNextSong];
    if (nextSong) {
        [[XCAudioCacheManager sharedInstance] preloadNextSong:nextSong];
    }
    
    // 3. 保存上一首到临时目录
    [[XCAudioCacheManager sharedInstance] finalizeCurrentSong:self.previousSongId];
}
```

### 10.2 与 XCResourceLoaderManager 集成

```objc
// 拦截 AVPlayer 请求，实现边下边存
- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader 
shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest {
    
    NSURL *url = loadingRequest.request.URL;
    NSString *songId = [self songIdFromURL:url];
    
    // 检查 L3 缓存
    NSURL *cachedURL = [self.cacheManager cachedURLForSongId:songId];
    if (cachedURL) {
        // 使用本地文件响应请求
        [self respondWithLocalFile:cachedURL forRequest:loadingRequest];
        return YES;
    }
    
    // 网络请求，同时写入 L1 缓存
    [self fetchAndCacheDataForRequest:loadingRequest songId:songId];
    return YES;
}
```

## 11. 错误处理与容错

### 11.1 常见错误场景

| 场景 | 处理策略 |
|------|----------|
| 缓存文件损坏 | 删除并重新下载 |
| 写入失败（磁盘满）| 清理 L3 旧缓存，降级到 L2 |
| 验证失败 | 移至临时目录，下次播放时重新验证 |
| 内存不足 | 系统自动清理 L1，不影响播放 |

### 11.2 降级策略

```objc
- (void)handleCacheWriteError:(NSError *)error songId:(NSString *)songId {
    if (error.code == NSFileWriteOutOfSpaceError) {
        // 磁盘空间不足：清理 L3 旧缓存
        [self.persistentCache cleanExpiredCacheWithMaxSize:512 * 1024 * 1024];
    } else {
        // 其他错误：记录日志，继续使用内存缓存
        NSLog(@"[Cache] 写入失败: %@, error: %@", songId, error);
    }
}
```

## 12. 性能优化

### 12.1 性能指标目标

| 指标 | 目标值 |
|------|--------|
| L1 缓存读取 | < 1ms |
| L2 缓存读取 | < 10ms |
| L3 缓存读取 | < 50ms |
| 首次缓冲时间 | < 300ms |
| 切歌响应时间 | < 100ms |

### 12.2 优化策略

1. **异步 IO**: 所有文件写入操作在后台队列执行
2. **分段预读**: 播放器请求数据时，提前加载后续分段
3. **内存映射**: L3 大文件使用 `NSDataReadingMappedIfSafe` 选项
4. **并发控制**: 限制同时下载/写入的线程数

## 13. 监控与调试

### 13.1 日志输出

```objc
#define CACHE_LOG(fmt, ...) NSLog(@"[AudioCache] " fmt, ##__VA_ARGS__)

// 关键日志点
// - 缓存命中/未命中
// - L1 -> L2 -> L3 流转
// - 预加载开始/完成
// - 清理操作
```

### 13.2 统计指标

```objc
@interface XCAudioCacheStatistics : NSObject
@property (nonatomic, assign) NSUInteger totalHitCount;      // 总命中次数
@property (nonatomic, assign) NSUInteger memoryHitCount;     // L1 命中次数
@property (nonatomic, assign) NSUInteger tempHitCount;       // L2 命中次数
@property (nonatomic, assign) NSUInteger cacheHitCount;      // L3 命中次数
@property (nonatomic, assign) NSUInteger missCount;          // 未命中次数
@property (nonatomic, assign) NSTimeInterval avgLoadTime;    // 平均加载时间
@end
```

## 14. 实现建议

### 14.1 开发阶段

1. **第一阶段**: 实现 L1 (NSCache) + L3 (Cache) 基础功能
2. **第二阶段**: 添加 L2 (Tmp) 中间层和完整性验证
3. **第三阶段**: 集成预加载机制
4. **第四阶段**: 添加统计监控和性能优化

### 14.2 测试要点

- 弱网环境下的缓存行为
- 大文件（> 10MB）处理
- 快速切歌场景
- 磁盘空间不足场景
- 应用被杀死后恢复

## 15. 总结

本设计通过三层缓存架构（NSCache -> Tmp -> Cache）实现音频数据的高效管理：

1. **NSCache** 提供极速内存访问，支持分段存储
2. **Tmp 文件夹** 作为中间层，确保未完整数据不污染永久缓存
3. **Cache 文件夹** 保存完整文件，支持离线播放
4. **预加载机制** 提前准备下一首，实现无缝切歌
5. **完整性验证** 确保缓存数据的可靠性

该方案在保证播放流畅性的同时，有效节省用户流量，提升整体用户体验。

---

**文档版本**: 1.0  
**创建日期**: 2026-02-12  
**适用范围**: Spotify Clone iOS App
