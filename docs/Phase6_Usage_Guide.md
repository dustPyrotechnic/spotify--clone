# Phase 6 使用指南

## 概述

Phase 6 完成了音频缓存系统的核心整合层 (`XCAudioCacheManager`)，统一封装了 L1/L2/L3 三层缓存的交互逻辑。

## 文件清单

```
11. 音频缓存/
├── XCAudioCacheManager.h/m         # 主管理器（新增）
└── Tests/
    ├── XCAudioCachePhase6Test.h/m  # Phase 6 测试（新增）
    └── XCAudioCacheTestRunner.m    # 测试运行器（更新）
```

## 核心功能

### 1. 三级缓存查询

```objc
XCAudioCacheManager *manager = [XCAudioCacheManager sharedInstance];

// 查询缓存状态（None/InMemory/TempFile/Complete）
XCAudioFileCacheState state = [manager cacheStateForSongId:@"123456"];

// 获取可播放的本地文件 URL（自动按 L3→L2 顺序查询）
NSURL *url = [manager cachedURLForSongId:@"123456"];
if (url) {
    // 使用本地缓存播放
    AVPlayer *player = [[AVPlayer alloc] initWithURL:url];
} else {
    // 使用网络播放
}
```

### 2. 分段存储（L1）

```objc
// 存储下载的分段数据到内存
NSData *segmentData = ...; // 从网络获取的分段
[manager storeSegment:segmentData 
            forSongId:@"123456" 
         segmentIndex:0];  // 第一个分段
```

### 3. 切歌时的数据流转

```objc
// 切歌时调用：将当前歌曲的 L1 分段合并写入 L2
[manager finalizeCurrentSong:@"current_song_id"];

// 歌曲完整下载后：验证并移动到 L3
[manager confirmCompleteSong:@"song_id" expectedSize:5242880];

// 或者使用封装好的完整流程
XCAudioFileCacheState finalState = [manager saveAndFinalizeSong:@"song_id" 
                                                   expectedSize:5242880];
```

### 4. 设置当前播放歌曲（优先级）

```objc
// 设置当前播放歌曲，其 L1 分段在内存紧张时优先保留
[manager setCurrentPrioritySong:@"current_playing_song"];
```

### 5. 清理缓存

```objc
// 删除指定歌曲的所有层级缓存
[manager deleteAllCacheForSongId:@"song_id"];

// 清空所有缓存（L1 + L2 + L3）
[manager clearAllCache];

// 只清理特定层级
[manager clearMemoryCache];    // 只清 L1
[manager clearTempCache];      // 只清 L2
[manager clearCompleteCache];  // 只清 L3
```

### 6. 统计信息

```objc
// 获取缓存统计
NSDictionary *stats = [manager cacheStatistics];
NSLog(@"缓存统计: %@", stats);
// 输出示例:
// {
//   "L1_Memory": {"size": 10485760, "costLimit": 104857600},
//   "L2_Temp": {"size": 52428800, "fileCount": 10, "sizeLimit": 524288000},
//   "L3_Complete": {"size": 314572800, "songCount": 50, "sizeLimit": 1073741824},
//   "Total": 377487360
// }

// 各层级大小
NSInteger l1Size = [manager memoryCacheSize];
NSInteger l2Size = [manager tempCacheSize];
NSInteger l3Size = [manager completeCacheSize];
NSInteger total = [manager totalCacheSize];
```

## 测试

### 运行 Phase 6 测试

```objc
// 方法 1: 运行单个 Phase 6 测试
[XCAudioCachePhase6Test runAllTests];

// 方法 2: 通过测试运行器运行
[XCAudioCacheTestRunner runPhase6Test];

// 方法 3: 运行所有 Phase 测试
[XCAudioCacheTestRunner runAllPhaseTests];

// 方法 4: 显示测试菜单（UI）
[XCAudioCacheTestRunner showTestMenuFromViewController:self];
```

### 测试覆盖

Phase 6 测试包含以下 11 个测试用例：

1. `testSingleton` - 单例模式验证
2. `testCacheState` - 缓存状态查询
3. `testThreeLevelQuery` - 三级查询（L3→L2→nil）
4. `testL1SegmentStorage` - L1 分段存储
5. `testL1ToL2Flow` - L1 → L2 数据流转
6. `testL2ToL3Flow` - L2 → L3 数据流转
7. `testSongSwitchingFlow` - 完整切歌流程
8. `testDeletion` - 删除操作
9. `testPriority` - 优先级设置
10. `testStatistics` - 统计信息
11. `testCacheIndexQuery` - 缓存索引查询
12. `testPerformance` - 性能测试

## 集成到播放器

在 `XCMusicPlayerModel.m` 中集成：

```objc
#import "XCAudioCacheManager.h"

// 播放前检查缓存
- (void)playMusicWithId:(NSString *)songId {
    XCAudioCacheManager *cacheManager = [XCAudioCacheManager sharedInstance];
    
    NSURL *cachedURL = [cacheManager cachedURLForSongId:songId];
    if (cachedURL) {
        // 使用本地缓存播放
        self.player = [[AVPlayer alloc] initWithURL:cachedURL];
    } else {
        // 使用网络 URL 播放（边下边存到 L1）
        NSURL *networkURL = [self getNetworkURLForSong:songId];
        self.player = [[AVPlayer alloc] initWithURL:networkURL];
    }
    
    // 设置当前优先歌曲
    [cacheManager setCurrentPrioritySong:songId];
}

// 切歌时保存上一首
- (void)playNextSong {
    NSString *currentSongId = self.currentSongId;
    NSString *nextSongId = self.nextSongId;
    
    // 保存当前歌曲
    if (currentSongId) {
        NSInteger expectedSize = [self getExpectedSizeForSong:currentSongId];
        [self.cacheManager saveAndFinalizeSong:currentSongId expectedSize:expectedSize];
    }
    
    // 播放下一首
    [self playMusicWithId:nextSongId];
    
    // 预加载下下首（Phase 7 实现）
    // [self.preloadManager preloadSong:self.nextNextSongId];
}
```

## 数据流转流程

```
播放中:
  网络数据 → L1 (NSCache 分段)

切歌时:
  L1 分段 → 合并 → L2 临时文件
  
下载完成时:
  L2 临时文件 → 验证完整性 → L3 永久缓存
```

## 注意事项

1. **L3 只存完整歌曲** - 只有验证完整的歌曲才会进入 L3
2. **切歌时调用 finalizeCurrentSong** - 确保内存分段被保存到 L2
3. **设置优先级** - 当前播放歌曲应设置优先级，防止被内存清理
4. **定期清理** - 建议 App 启动时清理过期临时文件：
   ```objc
   [manager cleanExpiredTempFiles];
   ```
