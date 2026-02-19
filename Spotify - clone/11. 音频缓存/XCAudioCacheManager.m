//
//  XCAudioCacheManager.m
//  Spotify - clone
//
//  音频缓存主管理器实现
//
// 你可以注意到虽然我分了三个文件夹的文件
// 但是其实最终看的还是这个
// 感谢解耦
// 阿门

#import "XCAudioCacheManager.h"
#import "XCMemoryCacheManager.h"
#import "XCTempCacheManager.h"
#import "XCPersistentCacheManager.h"
#import "XCCacheIndexManager.h"
#import "XCAudioSongCacheInfo.h"
#import "XCAudioCachePathUtils.h"
#import "XCAudioSegmentInfo.h"

@interface XCAudioCacheManager ()

@property (nonatomic, strong) XCMemoryCacheManager *memoryManager;
@property (nonatomic, strong) XCTempCacheManager *tempManager;
@property (nonatomic, strong) XCPersistentCacheManager *persistentManager;
@property (nonatomic, strong) XCCacheIndexManager *indexManager;

@end

@implementation XCAudioCacheManager

#pragma mark - 单例
// 不写复制相关操作了

+ (instancetype)sharedInstance {
  static XCAudioCacheManager *instance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
      instance = [[self alloc] init];
  });
  return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _memoryManager = [XCMemoryCacheManager sharedInstance];
        _tempManager = [XCTempCacheManager sharedInstance];
        _persistentManager = [XCPersistentCacheManager sharedInstance];
        _indexManager = [XCCacheIndexManager sharedInstance];
    }
    return self;
}
#pragma mark - 三级查询（L3 → L2 → nil）

- (XCAudioFileCacheState)cacheStateForSongId:(NSString *)songId {
  if (!songId || songId.length == 0) {
      return XCAudioFileCacheStateNone;
  }

  // 优先级：L3 > L2 > L1
  if ([self.persistentManager hasCompleteCacheForSongId:songId]) {
      return XCAudioFileCacheStateComplete;
  }

  if ([self.tempManager hasTempFileForSongId:songId]) {
      return XCAudioFileCacheStateTempFile;
  }

  if ([self.memoryManager segmentCountForSongId:songId] > 0) {
      return XCAudioFileCacheStateInMemory;
  }

  return XCAudioFileCacheStateNone;
}

- (NSURL *)cachedURLForSongId:(NSString *)songId {
  if (!songId || songId.length == 0) {
      return nil;
  }

  // 先查 L3
  NSURL *url = [self.persistentManager cachedURLForSongId:songId];
  if (url) {
      // 更新播放时间用于 LRU
      [self.indexManager updatePlayTimeForSongId:songId];
      return url;
  }

  // 再查 L2
  url = [self.tempManager tempFileURLForSongId:songId];
  if (url) {
      return url;
  }

  return nil;
}

- (NSString *)cachedFilePathForSongId:(NSString *)songId {
    if (!songId || songId.length == 0) {
        return nil;
    }
    
    // 先查 L3
    NSString *path = [self.persistentManager cachedFilePathForSongId:songId];
    if (path) {
        [self.indexManager updatePlayTimeForSongId:songId];
        return path;
    }
    
    // 再查 L2
    path = [self.tempManager tempFilePathForSongId:songId];
    if (path) {
        return path;
    }
    
    return nil;
}

- (BOOL)hasCompleteCacheForSongId:(NSString *)songId {
    return [self.persistentManager hasCompleteCacheForSongId:songId];
}

- (BOOL)hasTempCacheForSongId:(NSString *)songId {
    return [self.tempManager hasTempFileForSongId:songId];
}

- (BOOL)hasMemoryCacheForSongId:(NSString *)songId {
    return [self.memoryManager segmentCountForSongId:songId] > 0;
}

#pragma mark - L1 层操作

- (void)storeSegment:(NSData *)data
           forSongId:(NSString *)songId
        segmentIndex:(NSInteger)segmentIndex {
    if (!data || data.length == 0 || !songId || songId.length == 0) {
        return;
    }
    [self.memoryManager storeSegmentData:data
                              forSongId:songId
                           segmentIndex:segmentIndex];
}

- (NSData *)getSegmentForSongId:(NSString *)songId
                   segmentIndex:(NSInteger)segmentIndex {
    if (!songId || songId.length == 0) {
        return nil;
    }
    return [self.memoryManager segmentDataForSongId:songId
                                      segmentIndex:segmentIndex];
}

- (BOOL)hasSegmentForSongId:(NSString *)songId
               segmentIndex:(NSInteger)segmentIndex {
    if (!songId || songId.length == 0) {
        return NO;
    }
    return [self.memoryManager hasSegmentForSongId:songId
                                     segmentIndex:segmentIndex];
}

- (NSArray *)getAllSegmentsForSongId:(NSString *)songId {
    if (!songId || songId.length == 0) {
        return @[];
    }
    return [self.memoryManager getAllSegmentsForSongId:songId];
}

- (NSInteger)segmentCountForSongId:(NSString *)songId {
    if (!songId || songId.length == 0) {
        return 0;
    }
    return [self.memoryManager segmentCountForSongId:songId];
}

- (void)clearMemoryCacheForSongId:(NSString *)songId {
    if (!songId || songId.length == 0) {
        return;
    }
    [self.memoryManager clearSegmentsForSongId:songId];
}

#pragma mark - 数据流转

- (BOOL)finalizeCurrentSong:(NSString *)songId {
    if (!songId || songId.length == 0) {
        NSLog(@"[AudioCacheManager] finalizeCurrentSong: songId is empty");
        return NO;
    }
    
    // 检查是否有 L1 分段
    NSInteger segmentCount = [self.memoryManager segmentCountForSongId:songId];
    if (segmentCount == 0) {
        NSLog(@"[AudioCacheManager] No L1 segments for song: %@", songId);
        return NO;
    }
    
    // 获取 L2 临时文件路径
    NSString *tempPath = [[XCAudioCachePathUtils sharedInstance] tempFilePathForSongId:songId];
    
    // 使用流式合并写入 L2（避免大文件内存问题）
    BOOL success = [self.memoryManager writeMergedSegmentsToFile:tempPath
                                                      forSongId:songId];
    if (!success) {
        NSLog(@"[AudioCacheManager] Failed to write merged segments to L2: %@", songId);
        return NO;
    }
    
    NSLog(@"[AudioCacheManager] Finalized song %@ to L2 (%ld segments)",
          songId, (long)segmentCount);
    
    // 注意：这里不清空 L1，因为可能还在播放
    // 真正的清空应该在 confirmCompleteSong 或用户主动切歌后
    
    return YES;
}

- (BOOL)confirmCompleteSong:(NSString *)songId
               expectedSize:(NSInteger)expectedSize {
    if (!songId || songId.length == 0) {
        NSLog(@"[AudioCacheManager] confirmCompleteSong: songId is empty");
        return NO;
    }
    
    // 检查 L2 临时文件是否存在
    if (![self.tempManager hasTempFileForSongId:songId]) {
        NSLog(@"[AudioCacheManager] No L2 temp file for song: %@", songId);
        return NO;
    }
    
    // 验证并移动到 L3
    BOOL success = [self.tempManager confirmCompleteAndMoveToCache:songId
                                                      expectedSize:expectedSize];
    if (success) {
        // 移动到 L3 成功后，清空 L1 分段
        [self.memoryManager clearSegmentsForSongId:songId];
        NSLog(@"[AudioCacheManager] Confirmed and moved song %@ to L3", songId);
    } else {
        NSLog(@"[AudioCacheManager] Song %@ incomplete, keeping in L2", songId);
    }
    
    return success;
}

- (XCAudioFileCacheState)saveAndFinalizeSong:(NSString *)songId
                                expectedSize:(NSInteger)expectedSize {
    if (!songId || songId.length == 0) {
        return XCAudioFileCacheStateNone;
    }
    
    // 步骤 1: L1 → L2
    BOOL finalized = [self finalizeCurrentSong:songId];
    if (!finalized) {
        // 没有 L1 分段，检查是否已有 L2/L3
        XCAudioFileCacheState currentState = [self cacheStateForSongId:songId];
        if (currentState != XCAudioFileCacheStateNone) {
            return currentState;
        }
        return XCAudioFileCacheStateNone;
    }
    
    // 步骤 2: L2 → L3（如果需要验证）
    if (expectedSize > 0) {
        BOOL confirmed = [self confirmCompleteSong:songId expectedSize:expectedSize];
        if (confirmed) {
            return XCAudioFileCacheStateComplete;
        }
    }
    
    return XCAudioFileCacheStateTempFile;
}

#pragma mark - 预加载支持

- (void)setCurrentPrioritySong:(NSString *)songId {
    if (songId && songId.length > 0) {
        [self.memoryManager setCurrentSongPriority:songId];
    }
}

- (NSString *)currentPrioritySongId {
    return self.memoryManager.currentPrioritySongId;
}

#pragma mark - 删除操作

- (void)deleteAllCacheForSongId:(NSString *)songId {
    if (!songId || songId.length == 0) {
        return;
    }
    [self.memoryManager clearSegmentsForSongId:songId];
    [self.tempManager deleteTempFileForSongId:songId];
    [self.persistentManager deleteCacheForSongId:songId];
    NSLog(@"[AudioCacheManager] Deleted all cache for song: %@", songId);
}

- (void)deleteCompleteCacheForSongId:(NSString *)songId {
    if (!songId || songId.length == 0) {
        return;
    }
    [self.persistentManager deleteCacheForSongId:songId];
}

- (void)deleteTempCacheForSongId:(NSString *)songId {
    if (!songId || songId.length == 0) {
        return;
    }
    [self.tempManager deleteTempFileForSongId:songId];
}

- (void)clearAllCache {
    [self.memoryManager clearAllCache];
    [self.tempManager clearAllTempCache];
    [self.persistentManager clearAllCache];
    NSLog(@"[AudioCacheManager] Cleared all cache");
}

- (void)clearMemoryCache {
    [self.memoryManager clearAllCache];
}

- (void)clearTempCache {
    [self.tempManager clearAllTempCache];
}

- (void)clearCompleteCache {
    [self.persistentManager clearAllCache];
}

#pragma mark - 统计信息

- (NSInteger)memoryCacheSize {
    return self.memoryManager.totalCost;
}

- (NSInteger)tempCacheSize {
    return self.tempManager.totalTempCacheSize;
}

- (NSInteger)completeCacheSize {
    return self.persistentManager.totalCacheSize;
}

- (NSInteger)totalCacheSize {
    return [self memoryCacheSize] + [self tempCacheSize] + [self completeCacheSize];
}

- (NSInteger)completeCacheSongCount {
    return self.persistentManager.cachedSongCount;
}

- (NSInteger)tempCacheFileCount {
    return self.tempManager.tempFileCount;
}

- (NSDictionary *)cacheStatistics {
    return @{
        @"L1_Memory": @{
            @"size": @([self memoryCacheSize]),
            @"costLimit": @(kAudioCacheMemoryLimit)
        },
        @"L2_Temp": @{
            @"size": @([self tempCacheSize]),
            @"fileCount": @([self tempCacheFileCount]),
            @"sizeLimit": @(kAudioCacheTempLimit)
        },
        @"L3_Complete": @{
            @"size": @([self completeCacheSize]),
            @"songCount": @([self completeCacheSongCount]),
            @"sizeLimit": @(kAudioCacheDiskLimit)
        },
        @"Total": @([self totalCacheSize])
    };
}

#pragma mark - 容量管理

- (BOOL)isCompleteCacheOverLimit {
    return [self completeCacheSize] > kAudioCacheDiskLimit;
}

- (NSInteger)cleanCompleteCacheToSize:(NSInteger)targetSize {
    return [self.persistentManager cleanCacheToSize:targetSize];
}

- (NSInteger)cleanExpiredTempFiles {
    return [self.tempManager cleanExpiredTempFiles];
}

#pragma mark - 缓存索引查询

- (XCAudioSongCacheInfo *)cacheInfoForSongId:(NSString *)songId {
    if (!songId || songId.length == 0) {
        return nil;
    }
    return [self.indexManager getSongCacheInfo:songId];
}

- (void)updatePlayTimeForSongId:(NSString *)songId {
    if (!songId || songId.length == 0) {
        return;
    }
    [self.indexManager updatePlayTimeForSongId:songId];
}

@end
