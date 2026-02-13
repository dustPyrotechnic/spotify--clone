//
//  XCCacheIndexManager.m
//  Spotify - clone
//

#import "XCCacheIndexManager.h"
#import "XCAudioSongCacheInfo.h"
#import "../XCAudioCachePathUtils.h"

@interface XCCacheIndexManager ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, XCAudioSongCacheInfo *> *cacheIndex;
@property (nonatomic, strong) dispatch_queue_t ioQueue;
@end

@implementation XCCacheIndexManager

+ (instancetype)sharedInstance {
    static XCCacheIndexManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _cacheIndex = [NSMutableDictionary dictionary];
        _ioQueue = dispatch_queue_create("com.spotifyclone.cache.index", DISPATCH_QUEUE_SERIAL);
        [self loadIndex];
    }
    return self;
}

- (void)loadIndex {
    NSString *path = [XCAudioCachePathUtils sharedInstance].manifestPath;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if (![fm fileExistsAtPath:path]) {
        NSLog(@"[CacheIndex] No existing index, starting fresh");
        return;
    }
    
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) {
        NSLog(@"[CacheIndex] Failed to read index file");
        return;
    }
    
    NSError *error;
    NSArray *array = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (error || ![array isKindOfClass:[NSArray class]]) {
        NSLog(@"[CacheIndex] Failed to parse index: %@", error.localizedDescription);
        return;
    }
    
    for (NSDictionary *dict in array) {
        XCAudioSongCacheInfo *info = [self infoFromDictionary:dict];
        if (info) {
            _cacheIndex[info.songId] = info;
        }
    }
    
    NSLog(@"[CacheIndex] Loaded %ld songs from index", (long)_cacheIndex.count);
}

- (void)saveIndex {
    dispatch_async(_ioQueue, ^{
        NSMutableArray *array = [NSMutableArray arrayWithCapacity:self.cacheIndex.count];
        for (XCAudioSongCacheInfo *info in self.cacheIndex.allValues) {
            NSDictionary *dict = [self dictionaryFromInfo:info];
            if (dict) {
                [array addObject:dict];
            }
        }
        
        NSError *error;
        NSData *data = [NSJSONSerialization dataWithJSONObject:array options:NSJSONWritingPrettyPrinted error:&error];
        if (error) {
            NSLog(@"[CacheIndex] Failed to serialize index: %@", error.localizedDescription);
            return;
        }
        
        NSString *path = [XCAudioCachePathUtils sharedInstance].manifestPath;
        BOOL success = [data writeToFile:path atomically:YES];
        if (!success) {
            NSLog(@"[CacheIndex] Failed to write index file");
        }
    });
}

- (XCAudioSongCacheInfo *)infoFromDictionary:(NSDictionary *)dict {
    if (!dict || ![dict isKindOfClass:[NSDictionary class]]) return nil;
    
    NSString *songId = dict[@"songId"];
    NSNumber *totalSize = dict[@"totalSize"];
    if (!songId || !totalSize) return nil;
    
    XCAudioSongCacheInfo *info = [[XCAudioSongCacheInfo alloc] initWithSongId:songId totalSize:totalSize.integerValue];
    info.cacheTime = [dict[@"cacheTime"] doubleValue];
    info.lastPlayTime = [dict[@"lastPlayTime"] doubleValue];
    info.playCount = [dict[@"playCount"] integerValue];
    info.md5Hash = dict[@"md5Hash"];
    
    return info;
}

- (NSDictionary *)dictionaryFromInfo:(XCAudioSongCacheInfo *)info {
    if (!info) return nil;
    return @{
        @"songId": info.songId,
        @"totalSize": @(info.totalSize),
        @"cacheTime": @(info.cacheTime),
        @"lastPlayTime": @(info.lastPlayTime),
        @"playCount": @(info.playCount),
        @"md5Hash": info.md5Hash ?: @""
    };
}

- (void)addSongCacheInfo:(XCAudioSongCacheInfo *)info {
    if (!info || !info.songId) return;
    
    _cacheIndex[info.songId] = info;
    [self saveIndex];
    NSLog(@"[CacheIndex] Added song: %@, size: %ld", info.songId, (long)info.totalSize);
}

- (XCAudioSongCacheInfo *)getSongCacheInfo:(NSString *)songId {
    return _cacheIndex[songId];
}

- (void)removeSongCacheInfo:(NSString *)songId {
    if (!songId) return;
    
    [_cacheIndex removeObjectForKey:songId];
    [self saveIndex];
    NSLog(@"[CacheIndex] Removed song: %@", songId);
}

- (void)updatePlayTimeForSongId:(NSString *)songId {
    XCAudioSongCacheInfo *info = _cacheIndex[songId];
    if (!info) return;
    
    [info updatePlayTime];
    [self saveIndex];
}

- (NSInteger)totalCacheSize {
    NSInteger total = 0;
    for (XCAudioSongCacheInfo *info in _cacheIndex.allValues) {
        total += info.totalSize;
    }
    return total;
}

- (NSInteger)cachedSongCount {
    return _cacheIndex.count;
}

- (NSInteger)cleanCacheToSize:(NSInteger)targetSize {
    NSInteger currentSize = [self totalCacheSize];
    if (currentSize <= targetSize) return 0;
    
    NSArray *sortedSongs = [_cacheIndex.allValues sortedArrayUsingComparator:^NSComparisonResult(XCAudioSongCacheInfo *a, XCAudioSongCacheInfo *b) {
        return a.lastPlayTime > b.lastPlayTime ? NSOrderedDescending : NSOrderedAscending;
    }];
    
    NSInteger deletedCount = 0;
    XCAudioCachePathUtils *pathUtils = [XCAudioCachePathUtils sharedInstance];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    for (XCAudioSongCacheInfo *info in sortedSongs) {
        if (currentSize <= targetSize) break;
        
        NSString *cachePath = [pathUtils cacheFilePathForSongId:info.songId];
        NSError *error;
        
        // 如果文件存在则删除，不存在也删除索引记录
        if ([fm fileExistsAtPath:cachePath]) {
            [fm removeItemAtPath:cachePath error:&error];
            if (error) {
                NSLog(@"[CacheIndex] Failed to remove file: %@", error.localizedDescription);
                continue;
            }
        }
        
        [_cacheIndex removeObjectForKey:info.songId];
        currentSize -= info.totalSize;
        deletedCount++;
        NSLog(@"[CacheIndex] Cleaned song: %@", info.songId);
    }
    
    [self saveIndex];
    NSLog(@"[CacheIndex] Cleaned %ld songs, current size: %ld", (long)deletedCount, (long)currentSize);
    return deletedCount;
}

- (void)clearAllCache {
    XCAudioCachePathUtils *pathUtils = [XCAudioCachePathUtils sharedInstance];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    for (NSString *songId in _cacheIndex.allKeys) {
        NSString *cachePath = [pathUtils cacheFilePathForSongId:songId];
        [fm removeItemAtPath:cachePath error:nil];
    }
    
    [_cacheIndex removeAllObjects];
    [self saveIndex];
    NSLog(@"[CacheIndex] Cleared all cache");
}

@end
