//
//  XCPersistentCacheManager.m
//  Spotify - clone
//

#import "XCPersistentCacheManager.h"
#import "XCCacheIndexManager.h"
#import "XCAudioSongCacheInfo.h"
#import "../XCAudioCachePathUtils.h"

@interface XCPersistentCacheManager ()
@property (nonatomic, strong) dispatch_queue_t ioQueue;
@end

@implementation XCPersistentCacheManager

#pragma mark - 单例

+ (instancetype)sharedInstance {
    static XCPersistentCacheManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _ioQueue = dispatch_queue_create("com.spotifyclone.cache.persistent", DISPATCH_QUEUE_SERIAL);
        [self ensureCacheDirectoryExists];
    }
    return self;
}

#pragma mark - 目录管理

- (void)ensureCacheDirectoryExists {
    NSString *cacheDir = [XCAudioCachePathUtils sharedInstance].cacheDirectory;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if (![fm fileExistsAtPath:cacheDir]) {
        NSError *error;
        [fm createDirectoryAtPath:cacheDir
      withIntermediateDirectories:YES
                       attributes:nil
                            error:&error];
        if (error) {
            NSLog(@"[PersistentCache] Failed to create cache directory: %@", error.localizedDescription);
        } else {
            NSLog(@"[PersistentCache] Cache directory created: %@", cacheDir);
        }
    }
}

#pragma mark - 写入操作

- (BOOL)writeCompleteSongData:(NSData *)data forSongId:(NSString *)songId {
    if (!data || data.length == 0 || !songId || songId.length == 0) {
        NSLog(@"[PersistentCache] Invalid parameters");
        return NO;
    }
    
    NSString *filePath = [[XCAudioCachePathUtils sharedInstance] cacheFilePathForSongId:songId];
    
    __block BOOL success = NO;
    dispatch_sync(self.ioQueue, ^{
        success = [data writeToFile:filePath atomically:YES];
        
        if (success) {
            // 更新索引
            XCAudioSongCacheInfo *info = [[XCAudioSongCacheInfo alloc] initWithSongId:songId
                                                                             totalSize:data.length];
            [info updatePlayTime];
            [[XCCacheIndexManager sharedInstance] addSongCacheInfo:info];
            
            NSLog(@"[PersistentCache] Written complete song: %@, size: %ld", songId, (long)data.length);
        } else {
            NSLog(@"[PersistentCache] Failed to write song: %@", songId);
        }
    });
    
    return success;
}

- (BOOL)moveTempFileToCache:(NSString *)tempFilePath forSongId:(NSString *)songId {
    if (!tempFilePath || !songId || songId.length == 0) {
        return NO;
    }
    
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:tempFilePath]) {
        NSLog(@"[PersistentCache] Temp file not found: %@", tempFilePath);
        return NO;
    }
    
    NSString *cachePath = [[XCAudioCachePathUtils sharedInstance] cacheFilePathForSongId:songId];
    
    __block BOOL success = NO;
    __block NSError *blockError = nil;
    dispatch_sync(self.ioQueue, ^{
        // 如果目标文件已存在，先删除
        if ([fm fileExistsAtPath:cachePath]) {
            [fm removeItemAtPath:cachePath error:nil];
        }
        
        // 移动文件
        NSError *error = nil;
        success = [fm moveItemAtPath:tempFilePath toPath:cachePath error:&error];
        blockError = error;
        
        if (success) {
            // 获取文件大小
            NSDictionary *attrs = [fm attributesOfItemAtPath:cachePath error:nil];
            NSInteger fileSize = [attrs[NSFileSize] integerValue];
            
            // 更新索引
            XCAudioSongCacheInfo *info = [[XCAudioSongCacheInfo alloc] initWithSongId:songId
                                                                             totalSize:fileSize];
            [info updatePlayTime];
            [[XCCacheIndexManager sharedInstance] addSongCacheInfo:info];
            
            NSLog(@"[PersistentCache] Moved temp to cache: %@, size: %ld", songId, (long)fileSize);
        } else {
            NSLog(@"[PersistentCache] Failed to move file: %@", blockError.localizedDescription);
        }
    });
    
    return success;
}

#pragma mark - 读取操作

- (NSURL *)cachedURLForSongId:(NSString *)songId {
    NSString *path = [self cachedFilePathForSongId:songId];
    if (path) {
        return [NSURL fileURLWithPath:path];
    }
    return nil;
}

- (NSString *)cachedFilePathForSongId:(NSString *)songId {
    if (!songId || songId.length == 0) return nil;
    
    NSString *path = [[XCAudioCachePathUtils sharedInstance] cacheFilePathForSongId:songId];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if ([fm fileExistsAtPath:path]) {
        return path;
    }
    return nil;
}

#pragma mark - 查询操作

- (BOOL)hasCompleteCacheForSongId:(NSString *)songId {
    return [self cachedFilePathForSongId:songId] != nil;
}

- (NSInteger)fileSizeForSongId:(NSString *)songId {
    NSString *path = [self cachedFilePathForSongId:songId];
    if (!path) return 0;
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDictionary *attrs = [fm attributesOfItemAtPath:path error:nil];
    return [attrs[NSFileSize] integerValue];
}

#pragma mark - 删除操作

- (void)deleteCacheForSongId:(NSString *)songId {
    if (!songId || songId.length == 0) return;
    
    NSString *path = [[XCAudioCachePathUtils sharedInstance] cacheFilePathForSongId:songId];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    dispatch_sync(self.ioQueue, ^{
        NSError *error;
        if ([fm fileExistsAtPath:path]) {
            [fm removeItemAtPath:path error:&error];
            if (error) {
                NSLog(@"[PersistentCache] Failed to delete file: %@", error.localizedDescription);
            } else {
                NSLog(@"[PersistentCache] Deleted cache for: %@", songId);
            }
        }
        
        // 更新索引
        [[XCCacheIndexManager sharedInstance] removeSongCacheInfo:songId];
    });
}

- (void)clearAllCache {
    dispatch_sync(self.ioQueue, ^{ 
        NSString *cacheDir = [XCAudioCachePathUtils sharedInstance].cacheDirectory;
        NSFileManager *fm = [NSFileManager defaultManager];
        
        NSError *error;
        NSArray *contents = [fm contentsOfDirectoryAtPath:cacheDir error:&error];
        
        if (error) {
            NSLog(@"[PersistentCache] Failed to list cache directory: %@", error.localizedDescription);
            return;
        }
        
        for (NSString *fileName in contents) {
            // 只删除 .mp3 文件，保留 index.plist
            if ([fileName hasSuffix:@".mp3"]) {
                NSString *filePath = [cacheDir stringByAppendingPathComponent:fileName];
                [fm removeItemAtPath:filePath error:nil];
            }
        }
        
        // 清空索引
        [[XCCacheIndexManager sharedInstance] clearAllCache];
        
        NSLog(@"[PersistentCache] Cleared all cache");
    });
}

#pragma mark - 统计与清理

- (NSInteger)totalCacheSize {
    XCCacheIndexManager *indexManager = [XCCacheIndexManager sharedInstance];
    return [indexManager totalCacheSize];
}

- (NSInteger)cachedSongCount {
    XCCacheIndexManager *indexManager = [XCCacheIndexManager sharedInstance];
    return [indexManager cachedSongCount];
}

- (NSInteger)cleanCacheToSize:(NSInteger)targetSize {
    NSInteger currentSize = [self totalCacheSize];
    if (currentSize <= targetSize) return 0;
    
    XCCacheIndexManager *indexManager = [XCCacheIndexManager sharedInstance];
    
    // 获取所有缓存信息并按 lastPlayTime 排序（最久未播放的在前面）
    NSMutableArray<XCAudioSongCacheInfo *> *allSongs = [NSMutableArray array];
    // 注意：这里假设 XCCacheIndexManager 提供获取所有歌曲的方法
    // 如果没有，需要通过其他方式获取
    
    // 简化为调用 XCCacheIndexManager 的清理方法
    NSInteger deletedCount = [indexManager cleanCacheToSize:targetSize];
    
    NSLog(@"[PersistentCache] Cleaned %ld songs to target size: %ld", (long)deletedCount, (long)targetSize);
    return deletedCount;
}

- (NSInteger)cleanOldestCache:(NSInteger)sizeToPreserve {
    NSInteger currentSize = [self totalCacheSize];
    NSInteger targetSize = currentSize - sizeToPreserve;
    
    if (targetSize <= 0) return 0;
    
    return [self cleanCacheToSize:targetSize];
}

@end
