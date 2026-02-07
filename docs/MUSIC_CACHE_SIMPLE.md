# 音乐内存缓存设计方案（简化版）

> 文档状态: 设计完成  
> 创建日期: 2026-02-07  
> 目标版本: v1.0

---

## 1. 设计目标

**核心需求只有一个**：缓存当前和即将播放的歌曲到内存，实现秒切无卡顿。

**不做的事情**：
- ❌ 磁盘持久化缓存
- ❌ 智能预加载算法
- ❌ 复杂的缓存清理策略
- ❌ 断点续传

---

## 2. 架构图

```
┌─────────────────────────────────┐
│     XCMusicMemoryCache          │  ← 单例，唯一入口
│      (内存缓存管理器)             │
├─────────────────────────────────┤
│                                 │
│   ┌─────────────────────────┐   │
│   │      NSCache            │   │  ← 系统自动管理内存
│   │   Key: songId           │   │
│   │   Value: NSData (音频)   │   │
│   └─────────────────────────┘   │
│                                 │
│   ┌─────────────────────────┐   │
│   │   当前播放缓冲区          │   │  ← 保证当前播放不释放
│   │   currentSongId         │   │
│   └─────────────────────────┘   │
│                                 │
└─────────────────────────────────┘
```

---

## 3. 接口设计

```objc
// XCMusicMemoryCache.h

#import <Foundation/Foundation.h>
#import "XC-YYSongData.h"

@interface XCMusicMemoryCache : NSObject

+ (instancetype)sharedInstance;

#pragma mark - 查询
/// 歌曲是否在内存缓存中
- (BOOL)isCached:(NSString *)songId;

/// 获取缓存的音频数据
- (NSData *)dataForSongId:(NSString *)songId;

#pragma mark - 写入
/// 缓存歌曲数据
- (void)cacheData:(NSData *)data forSongId:(NSString *)songId;

/// 从 URL 下载并缓存（后台异步）
- (void)downloadAndCache:(XC_YYSongData *)song;

#pragma mark - 当前播放管理
/// 设置当前播放歌曲（防被清理）
- (void)setCurrentPlayingSong:(NSString *)songId;

/// 获取当前播放歌曲的本地 URL（用于 AVPlayer）
- (NSURL *)localURLForCurrentSong;

#pragma mark - 清理
/// 移除指定歌曲缓存
- (void)removeCache:(NSString *)songId;

/// 清空所有缓存
- (void)clearAllCache;

#pragma mark - 统计
/// 当前缓存占用内存大小（字节）
- (NSUInteger)currentCacheSize;

/// 缓存歌曲数量
- (NSUInteger)cachedSongCount;

@end
```

---

## 4. 实现要点

### 4.1 使用 NSCache（自动内存管理）

```objc
@interface XCMusicMemoryCache ()

@property (nonatomic, strong) NSCache<NSString *, NSData *> *audioCache;
@property (nonatomic, copy) NSString *currentSongId;
@property (nonatomic, strong) NSLock *lock;

@end

@implementation XCMusicMemoryCache

+ (instancetype)sharedInstance {
    static XCMusicMemoryCache *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _audioCache = [[NSCache alloc] init];
        _audioCache.countLimit = 10;        // 最多缓存 10 首歌
        _audioCache.totalCostLimit = 100 * 1024 * 1024;  // 最大 100MB
        _lock = [[NSLock alloc] init];
    }
    return self;
}

@end
```

### 4.2 关键方法实现

```objc
#pragma mark - 查询

- (BOOL)isCached:(NSString *)songId {
    if (!songId) return NO;
    return [self.audioCache objectForKey:songId] != nil;
}

- (NSData *)dataForSongId:(NSString *)songId {
    if (!songId) return nil;
    
    NSData *data = [self.audioCache objectForKey:songId];
    if (data) {
        NSLog(@"[MemoryCache] 内存缓存命中: %@", songId);
    }
    return data;
}

#pragma mark - 写入

- (void)cacheData:(NSData *)data forSongId:(NSString *)songId {
    if (!data || !songId || data.length == 0) return;
    
    // 限制单首歌曲大小（20MB）
    if (data.length > 20 * 1024 * 1024) {
        NSLog(@"[MemoryCache] 歌曲太大，跳过缓存: %@ (%zu MB)", 
              songId, data.length / 1024 / 1024);
        return;
    }
    
    NSUInteger cost = data.length;
    [self.audioCache setObject:data forKey:songId cost:cost];
    NSLog(@"[MemoryCache] 已缓存: %@, 大小: %.2f MB", 
          songId, cost / 1024.0 / 1024.0);
}

#pragma mark - 当前播放管理

- (void)setCurrentPlayingSong:(NSString *)songId {
    [self.lock lock];
    self.currentSongId = songId;
    [self.lock unlock];
    
    // 防止被 NSCache 清理，再标记一次（NSCache 会在内存紧张时自动释放）
    NSData *data = [self.audioCache objectForKey:songId];
    if (data) {
        // 重新设置，更新时间戳
        [self.audioCache setObject:data forKey:songId cost:data.length];
    }
}

@end
```

---

## 5. 与播放器集成

### 5.1 修改 XCMusicPlayerModel

```objc
// XCMusicPlayerModel.m

- (void)playSong:(XC_YYSongData *)song {
    // 1. 检查内存缓存
    NSData *cachedData = [[XCMusicMemoryCache sharedInstance] dataForSongId:song.songId];
    if (cachedData) {
        // 使用内存缓存播放
        NSURL *tempURL = [self saveToTempFile:cachedData songId:song.songId];
        [self playWithURL:tempURL];
        [[XCMusicMemoryCache sharedInstance] setCurrentPlayingSong:song.songId];
        return;
    }
    
    // 2. 网络播放
    [self playWithURL:song.audioURL];
    
    // 3. 后台下载到内存
    [[XCMusicMemoryCache sharedInstance] downloadAndCache:song];
}

// 切歌时预加载下一首
- (void)playNext {
    NSInteger nextIndex = (self.currentIndex + 1) % self.playlist.count;
    XC_YYSongData *nextSong = self.playlist[nextIndex];
    
    // 预加载下一首（后台）
    [[XCMusicMemoryCache sharedInstance] downloadAndCache:nextSong];
    
    // 播放当前
    [self playSongAtIndex:nextIndex];
}
```

---

## 6. 流程图

### 播放流程

```
用户点击播放
    │
    ▼
检查内存缓存？
    │
    ├── 命中 ──> 直接播放（瞬间）
    │
    └── 未命中 ─> 网络播放
                │
                └──> 后台下载到内存（供下次使用）
```

### 切歌流程

```
播放下一首
    │
    ├──> 播放当前点击的歌曲
    │
    └──> 后台预加载「下下首」到内存
```

---

## 7. 限制与特点

| 特性 | 说明 |
|------|------|
| **生命周期** | App 杀死即清空（纯内存） |
| **容量** | 最大 10 首歌 / 100MB |
| **自动清理** | 系统内存不足时自动释放（NSCache 特性） |
| **线程安全** | NSCache 线程安全，无需额外加锁 |
| **离线播放** | ❌ 不支持（App 重启后无缓存） |

---

## 8. 适用场景

✅ **适合**：
- 在线听歌，切歌时减少加载等待
- 播放列表循环播放，重复利用缓存
- 内存充足，追求极致播放流畅度

❌ **不适合**：
- 离线播放需求
- 长时间后台播放后恢复
- 设备内存紧张

---

## 9. 代码文件

只需要两个文件：

```
Spotify - clone/
└── 10. 内存缓存/
    ├── XCMusicMemoryCache.h
    └── XCMusicMemoryCache.m
```

---

## 10. 下一步

确认这个简化方案后，我可以立即开始编码实现。预计 **1-2 小时** 完成全部代码。
