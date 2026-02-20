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

// 记录 songId 对应的原始 URL，用于确定正确的文件扩展名
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSURL *> *songURLMap;
@property (nonatomic, strong) dispatch_queue_t urlMapQueue;

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
        // 【初始化】创建三层缓存管理器实例（单例模式）
        _memoryManager = [XCMemoryCacheManager sharedInstance];      // L1: 内存分段缓存
        _tempManager = [XCTempCacheManager sharedInstance];          // L2: 临时文件缓存
        _persistentManager = [XCPersistentCacheManager sharedInstance]; // L3: 永久缓存
        _indexManager = [XCCacheIndexManager sharedInstance];        // 缓存索引管理
        
        // 初始化 URL 映射表
        _songURLMap = [NSMutableDictionary dictionary];
        _urlMapQueue = dispatch_queue_create("com.spotifyclone.cache.urlmap", DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}
#pragma mark - 三级查询（L3 → L2 → nil）

- (XCAudioFileCacheState)cacheStateForSongId:(NSString *)songId {
  // 【参数校验】songId 无效返回无缓存状态
  if (!songId || songId.length == 0) {
      return XCAudioFileCacheStateNone;
  }

  // 【三级查询】按优先级检查：L3(永久) > L2(临时) > L1(内存)
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
  // 【参数校验】songId 无效返回 nil
  if (!songId || songId.length == 0) {
      return nil;
  }

  // 【L3 查询】优先检查永久缓存，命中则更新 LRU 时间
  NSString *path = [self cachedFilePathForSongId:songId];
  if (path) {
      [self.indexManager updatePlayTimeForSongId:songId];
      return [NSURL fileURLWithPath:path];
  }

  return nil; // L1 内存缓存不提供文件 URL
}

- (NSString *)cachedFilePathForSongId:(NSString *)songId {
    if (!songId || songId.length == 0) {
        return nil;
    }
    
    // 获取该歌曲对应的原始 URL，用于确定正确的文件扩展名
    __block NSURL *originalURL = nil;
    dispatch_sync(self.urlMapQueue, ^{
        originalURL = self.songURLMap[songId];
    });
    
    NSFileManager *fm = [NSFileManager defaultManager];
    XCAudioCachePathUtils *pathUtils = [XCAudioCachePathUtils sharedInstance];
    
    // 先查 L3（使用正确的扩展名）
    NSString *l3Path = [pathUtils cacheFilePathForSongId:songId originalURL:originalURL];
    if ([fm fileExistsAtPath:l3Path]) {
        [self.indexManager updatePlayTimeForSongId:songId];
        return l3Path;
    }
    
    // 再查 L2（使用正确的扩展名）
    NSString *l2Path = [pathUtils tempFilePathForSongId:songId originalURL:originalURL];
    if ([fm fileExistsAtPath:l2Path]) {
        return l2Path;
    }
    
    // 如果 originalURL 为 nil，尝试搜索 L2 目录中匹配的文件（任何扩展名）
    if (!originalURL) {
        NSString *tempDir = pathUtils.tempDirectory;
        NSArray *contents = [fm contentsOfDirectoryAtPath:tempDir error:nil];
        NSString *pattern = [NSString stringWithFormat:@"%@_tmp.", songId];
        for (NSString *fileName in contents) {
            if ([fileName hasPrefix:pattern]) {
                return [tempDir stringByAppendingPathComponent:fileName];
            }
        }
    }
    
    // 兼容旧格式：检查 .mp3 扩展名的文件（迁移用）
    NSString *oldL3Path = [pathUtils cacheFilePathForSongId:songId];
    if ([fm fileExistsAtPath:oldL3Path]) {
        [self.indexManager updatePlayTimeForSongId:songId];
        return oldL3Path;
    }
    NSString *oldL2Path = [pathUtils tempFilePathForSongId:songId];
    if ([fm fileExistsAtPath:oldL2Path]) {
        return oldL2Path;
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

#pragma mark - URL 记录

/// 记录 songId 对应的原始 URL，用于确定正确的文件扩展名
- (void)recordOriginalURL:(NSURL *)url forSongId:(NSString *)songId {
    if (!songId || songId.length == 0 || !url) {
        return;
    }
    dispatch_barrier_async(self.urlMapQueue, ^{
        self.songURLMap[songId] = url;
    });
}

/// 获取 songId 对应的原始 URL
- (NSURL *)originalURLForSongId:(NSString *)songId {
    if (!songId || songId.length == 0) {
        return nil;
    }
    __block NSURL *url = nil;
    dispatch_sync(self.urlMapQueue, ^{
        url = self.songURLMap[songId];
    });
    return url;
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
    // 【参数校验】songId 无效记录错误日志
    if (!songId || songId.length == 0) {
        NSLog(@"[AudioCacheManager] finalizeCurrentSong: songId is empty");
        return NO;
    }
    
    // 【检查 L1】确认内存中有该歌曲的分段数据
    NSInteger segmentCount = [self.memoryManager segmentCountForSongId:songId];
    if (segmentCount == 0) {
        NSLog(@"[AudioCacheManager] No L1 segments for song: %@", songId);
        return NO;
    }
    
    // 【L1→L2】获取临时文件路径（使用正确的扩展名），使用流式合并写入
    NSURL *originalURL = [self originalURLForSongId:songId];
    NSString *tempPath = [[XCAudioCachePathUtils sharedInstance] tempFilePathForSongId:songId 
                                                                            originalURL:originalURL];
    
    BOOL success = [self.memoryManager writeMergedSegmentsToFile:tempPath
                                                      forSongId:songId];
    if (!success) {
        NSLog(@"[AudioCacheManager] Failed to write merged segments to L2: %@", songId);
        return NO;
    }
    
    // 【流程日志】记录 L1→L2 合并完成，保留 L1 用于可能正在播放的场景
    NSLog(@"[AudioCacheManager] Finalized song %@ to L2 (%ld segments), ext: %@",
          songId, (long)segmentCount, [originalURL.path pathExtension] ?: @"mp3");
    
    // 【注意】此处不清空 L1，歌曲可能仍在播放，清空应在切歌后或验证完成后
    
    return YES;
}

- (BOOL)confirmCompleteSong:(NSString *)songId
               expectedSize:(NSInteger)expectedSize {
    // 【参数校验】songId 无效记录错误日志
    if (!songId || songId.length == 0) {
        NSLog(@"[AudioCacheManager] confirmCompleteSong: songId is empty");
        return NO;
    }
    
    // 【检查 L2】确认临时文件存在（使用正确的扩展名）
    NSURL *originalURL = [self originalURLForSongId:songId];
    NSString *tempPath = [[XCAudioCachePathUtils sharedInstance] tempFilePathForSongId:songId 
                                                                            originalURL:originalURL];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:tempPath]) {
        // 兼容旧格式：检查 .mp3.tmp 文件
        NSString *oldTempPath = [[XCAudioCachePathUtils sharedInstance] tempFilePathForSongId:songId];
        if (![fm fileExistsAtPath:oldTempPath]) {
            NSLog(@"[AudioCacheManager] No L2 temp file for song: %@", songId);
            return NO;
        }
    }
    
    // 【L2→L3】验证文件完整性并移动到永久缓存（使用正确的扩展名）
    NSString *cachePath = [[XCAudioCachePathUtils sharedInstance] cacheFilePathForSongId:songId 
                                                                               originalURL:originalURL];
    BOOL success = [self.persistentManager moveTempFileToCache:tempPath 
                                                    cachePath:cachePath
                                                     forSongId:songId];
    if (success) {
        // 【清理 L1】移动到 L3 成功后，清空 L1 分段释放内存
        [self.memoryManager clearSegmentsForSongId:songId];
        NSLog(@"[AudioCacheManager] Confirmed and moved song %@ to L3", songId);
    } else {
        // 【保留 L2】文件不完整，保留在临时缓存中
        NSLog(@"[AudioCacheManager] Song %@ incomplete, keeping in L2", songId);
    }
    
    return success;
}

- (XCAudioFileCacheState)saveAndFinalizeSong:(NSString *)songId
                                expectedSize:(NSInteger)expectedSize {
    // 【参数校验】songId 无效返回无缓存状态
    if (!songId || songId.length == 0) {
        return XCAudioFileCacheStateNone;
    }
    
    // 【步骤 1】L1 → L2：合并内存分段到临时文件
    BOOL finalized = [self finalizeCurrentSong:songId];
    if (!finalized) {
        // 无 L1 分段，检查是否已有 L2/L3 缓存
        XCAudioFileCacheState currentState = [self cacheStateForSongId:songId];
        if (currentState != XCAudioFileCacheStateNone) {
            return currentState;
        }
        return XCAudioFileCacheStateNone;
    }
    
    // 【步骤 2】L2 → L3：验证完整性后移动到永久缓存
    if (expectedSize > 0) {
        BOOL confirmed = [self confirmCompleteSong:songId expectedSize:expectedSize];
        if (confirmed) {
            return XCAudioFileCacheStateComplete;
        }
    }
    
    return XCAudioFileCacheStateTempFile; // 未验证或不完整，保留在 L2
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
    // 【统计汇总】返回三层缓存的详细统计信息，用于调试和监控
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
