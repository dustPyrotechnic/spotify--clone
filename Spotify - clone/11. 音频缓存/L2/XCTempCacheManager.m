//
//  XCTempCacheManager.m
//  Spotify - clone
//

#import "XCTempCacheManager.h"
#import "../XCAudioCachePathUtils.h"
#import "../L3/XCPersistentCacheManager.h"

@interface XCTempCacheManager ()
@property (nonatomic, strong) dispatch_queue_t ioQueue;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSFileHandle *> *fileHandles;
@property (nonatomic, strong) dispatch_queue_t fileHandleQueue;
@end

@implementation XCTempCacheManager

#pragma mark - 单例

+ (instancetype)sharedInstance {
    static XCTempCacheManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _ioQueue = dispatch_queue_create("com.spotifyclone.cache.temp", DISPATCH_QUEUE_SERIAL);
        _fileHandleQueue = dispatch_queue_create("com.spotifyclone.cache.temp.filehandle", DISPATCH_QUEUE_SERIAL);
        _fileHandles = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)dealloc {
    // 关闭所有打开的 fileHandle
    for (NSFileHandle *handle in self.fileHandles.allValues) {
        [handle closeFile];
    }
}

#pragma mark - 写入操作

- (BOOL)writeTempSongData:(NSData *)data forSongId:(NSString *)songId {
    if (!data || data.length == 0 || !songId || songId.length == 0) {
        NSLog(@"[TempCache] Invalid parameters for writeTempSongData");
        return NO;
    }
    
    __block BOOL success = NO;
    dispatch_sync(self.ioQueue, ^{
        NSString *filePath = [[XCAudioCachePathUtils sharedInstance] tempFilePathForSongId:songId];
        NSFileManager *fm = [NSFileManager defaultManager];
        
        // 确保目录存在
        NSString *dirPath = [filePath stringByDeletingLastPathComponent];
        if (![fm fileExistsAtPath:dirPath]) {
            NSError *error;
            [fm createDirectoryAtPath:dirPath
          withIntermediateDirectories:YES
                           attributes:nil
                                error:&error];
            if (error) {
                NSLog(@"[TempCache] Failed to create directory: %@", error.localizedDescription);
                return;
            }
        }
        
        // 如果文件不存在，创建空文件
        if (![fm fileExistsAtPath:filePath]) {
            success = [fm createFileAtPath:filePath contents:nil attributes:nil];
            if (!success) {
                NSLog(@"[TempCache] Failed to create temp file: %@", filePath);
                return;
            }
        }
        
        // 追加写入数据
        NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:filePath];
        if (!fileHandle) {
            NSLog(@"[TempCache] Failed to open file for writing: %@", filePath);
            return;
        }
        
        @try {
            [fileHandle seekToEndOfFile];
            [fileHandle writeData:data];
            success = YES;
            NSLog(@"[TempCache] Appended %ld bytes to temp file: %@", (long)data.length, songId);
        } @catch (NSException *exception) {
            NSLog(@"[TempCache] Exception writing to file: %@", exception.reason);
            success = NO;
        } @finally {
            [fileHandle closeFile];
        }
    });
    
    return success;
}

- (NSFileHandle *)fileHandleForWritingTempFile:(NSString *)songId {
    if (!songId || songId.length == 0) return nil;
    
    NSString *filePath = [[XCAudioCachePathUtils sharedInstance] tempFilePathForSongId:songId];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    // 确保文件存在
    if (![fm fileExistsAtPath:filePath]) {
        BOOL created = [fm createFileAtPath:filePath contents:nil attributes:nil];
        if (!created) {
            NSLog(@"[TempCache] Failed to create temp file for handle: %@", songId);
            return nil;
        }
    }
    
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:filePath];
    if (handle) {
        dispatch_sync(self.fileHandleQueue, ^{
            self.fileHandles[songId] = handle;
        });
    }
    
    return handle;
}

#pragma mark - 读取操作

- (NSURL *)tempFileURLForSongId:(NSString *)songId {
    NSString *path = [self tempFilePathForSongId:songId];
    if (path) {
        return [NSURL fileURLWithPath:path];
    }
    return nil;
}

- (NSString *)tempFilePathForSongId:(NSString *)songId {
    if (!songId || songId.length == 0) return nil;
    
    NSString *path = [[XCAudioCachePathUtils sharedInstance] tempFilePathForSongId:songId];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if ([fm fileExistsAtPath:path]) {
        return path;
    }
    return nil;
}

#pragma mark - 查询操作

- (BOOL)hasTempFileForSongId:(NSString *)songId {
    return [self tempFilePathForSongId:songId] != nil;
}

- (NSInteger)tempFileSizeForSongId:(NSString *)songId {
    NSString *path = [self tempFilePathForSongId:songId];
    if (!path) return 0;
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDictionary *attrs = [fm attributesOfItemAtPath:path error:nil];
    return [attrs[NSFileSize] integerValue];
}

- (BOOL)isTempFileComplete:(NSString *)songId expectedSize:(NSInteger)expectedSize {
    if (expectedSize <= 0) return NO;
    
    NSInteger actualSize = [self tempFileSizeForSongId:songId];
    return actualSize == expectedSize;
}

#pragma mark - 删除操作

- (void)deleteTempFileForSongId:(NSString *)songId {
    if (!songId || songId.length == 0) return;
    
    dispatch_sync(self.ioQueue, ^{
        // 关闭可能打开的 fileHandle
        dispatch_sync(self.fileHandleQueue, ^{
            NSFileHandle *handle = self.fileHandles[songId];
            if (handle) {
                [handle closeFile];
                [self.fileHandles removeObjectForKey:songId];
            }
        });
        
        NSString *path = [[XCAudioCachePathUtils sharedInstance] tempFilePathForSongId:songId];
        NSFileManager *fm = [NSFileManager defaultManager];
        
        NSError *error;
        if ([fm fileExistsAtPath:path]) {
            [fm removeItemAtPath:path error:&error];
            if (error) {
                NSLog(@"[TempCache] Failed to delete temp file: %@", error.localizedDescription);
            } else {
                NSLog(@"[TempCache] Deleted temp file: %@", songId);
            }
        }
    });
}

- (void)clearAllTempCache {
    dispatch_sync(self.ioQueue, ^{
        // 关闭所有 fileHandle
        dispatch_sync(self.fileHandleQueue, ^{
            for (NSFileHandle *handle in self.fileHandles.allValues) {
                [handle closeFile];
            }
            [self.fileHandles removeAllObjects];
        });
        
        NSString *tempDir = [XCAudioCachePathUtils sharedInstance].tempDirectory;
        NSFileManager *fm = [NSFileManager defaultManager];
        
        NSError *error;
        NSArray *contents = [fm contentsOfDirectoryAtPath:tempDir error:&error];
        
        if (error) {
            NSLog(@"[TempCache] Failed to list temp directory: %@", error.localizedDescription);
            return;
        }
        
        NSInteger deletedCount = 0;
        for (NSString *fileName in contents) {
            if ([fileName hasSuffix:@".mp3.tmp"]) {
                NSString *filePath = [tempDir stringByAppendingPathComponent:fileName];
                [fm removeItemAtPath:filePath error:nil];
                deletedCount++;
            }
        }
        
        NSLog(@"[TempCache] Cleared %ld temp files", (long)deletedCount);
    });
}

#pragma mark - L2 → L3 流转

- (BOOL)moveToPersistentCache:(NSString *)songId {
    if (!songId || songId.length == 0) return NO;
    
    NSString *tempPath = [[XCAudioCachePathUtils sharedInstance] tempFilePathForSongId:songId];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if (![fm fileExistsAtPath:tempPath]) {
        NSLog(@"[TempCache] Temp file not found for moving: %@", songId);
        return NO;
    }
    
    // 关闭可能打开的 fileHandle
    dispatch_sync(self.fileHandleQueue, ^{
        NSFileHandle *handle = self.fileHandles[songId];
        if (handle) {
            [handle closeFile];
            [self.fileHandles removeObjectForKey:songId];
        }
    });
    
    // 使用 L3 管理器的移动方法
    BOOL success = [[XCPersistentCacheManager sharedInstance] moveTempFileToCache:tempPath forSongId:songId];
    
    if (success) {
        NSLog(@"[TempCache] Moved temp file to L3 cache: %@", songId);
    } else {
        NSLog(@"[TempCache] Failed to move temp file to L3: %@", songId);
    }
    
    return success;
}

- (BOOL)confirmCompleteAndMoveToCache:(NSString *)songId expectedSize:(NSInteger)expectedSize {
    if (![self isTempFileComplete:songId expectedSize:expectedSize]) {
        NSLog(@"[TempCache] File incomplete, cannot move to L3: %@ (expected: %ld, actual: %ld)",
              songId, (long)expectedSize, (long)[self tempFileSizeForSongId:songId]);
        return NO;
    }
    
    return [self moveToPersistentCache:songId];
}

#pragma mark - 过期清理

- (NSInteger)cleanExpiredTempFiles {
    return [self cleanTempFilesOlderThanDays:7];
}

- (NSInteger)cleanTempFilesOlderThanDays:(NSInteger)days {
    if (days < 0) return 0;
    
    __block NSInteger deletedCount = 0;
    dispatch_sync(self.ioQueue, ^{
        NSString *tempDir = [XCAudioCachePathUtils sharedInstance].tempDirectory;
        NSFileManager *fm = [NSFileManager defaultManager];
        
        NSError *error;
        NSArray *contents = [fm contentsOfDirectoryAtPath:tempDir error:&error];
        
        if (error) {
            NSLog(@"[TempCache] Failed to list temp directory: %@", error.localizedDescription);
            return;
        }
        
        NSTimeInterval expireInterval = days * 24 * 60 * 60;
        NSDate *now = [NSDate date];
        
        for (NSString *fileName in contents) {
            if (![fileName hasSuffix:@".mp3.tmp"]) continue;
            
            NSString *filePath = [tempDir stringByAppendingPathComponent:fileName];
            
            // 提取 songId（去掉 .mp3.tmp 后缀）
            NSString *songId = [fileName stringByReplacingOccurrencesOfString:@".mp3.tmp" withString:@""];
            
            // 关闭可能打开的 fileHandle
            dispatch_sync(self.fileHandleQueue, ^{
                NSFileHandle *handle = self.fileHandles[songId];
                if (handle) {
                    [handle closeFile];
                    [self.fileHandles removeObjectForKey:songId];
                }
            });
            
            NSDictionary *attrs = [fm attributesOfItemAtPath:filePath error:nil];
            NSDate *createDate = attrs[NSFileCreationDate];
            
            if (createDate) {
                NSTimeInterval age = [now timeIntervalSinceDate:createDate];
                if (age > expireInterval) {
                    NSError *deleteError;
                    [fm removeItemAtPath:filePath error:&deleteError];
                    if (!deleteError) {
                        deletedCount++;
                        NSLog(@"[TempCache] Cleaned expired temp file: %@ (age: %.1f days)", 
                              fileName, age / 86400.0);
                    }
                }
            }
        }
    });
    
    NSLog(@"[TempCache] Cleaned %ld expired temp files", (long)deletedCount);
    return deletedCount;
}

#pragma mark - 统计信息

- (NSInteger)totalTempCacheSize {
    __block NSInteger totalSize = 0;
    dispatch_sync(self.ioQueue, ^{
        NSString *tempDir = [XCAudioCachePathUtils sharedInstance].tempDirectory;
        NSFileManager *fm = [NSFileManager defaultManager];
        
        NSError *error;
        NSArray *contents = [fm contentsOfDirectoryAtPath:tempDir error:&error];
        
        if (error) return;
        
        for (NSString *fileName in contents) {
            if ([fileName hasSuffix:@".mp3.tmp"]) {
                NSString *filePath = [tempDir stringByAppendingPathComponent:fileName];
                NSDictionary *attrs = [fm attributesOfItemAtPath:filePath error:nil];
                totalSize += [attrs[NSFileSize] integerValue];
            }
        }
    });
    
    return totalSize;
}

- (NSInteger)tempFileCount {
    __block NSInteger count = 0;
    dispatch_sync(self.ioQueue, ^{
        NSString *tempDir = [XCAudioCachePathUtils sharedInstance].tempDirectory;
        NSFileManager *fm = [NSFileManager defaultManager];
        
        NSError *error;
        NSArray *contents = [fm contentsOfDirectoryAtPath:tempDir error:&error];
        
        if (error) return;
        
        for (NSString *fileName in contents) {
            if ([fileName hasSuffix:@".mp3.tmp"]) {
                count++;
            }
        }
    });
    
    return count;
}

@end
