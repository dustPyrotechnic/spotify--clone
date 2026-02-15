//
//  XCMemoryCacheManager.m
//  Spotify - clone
//

#import <UIKit/UIKit.h>
#import "XCMemoryCacheManager.h"
#import "XCAudioSegmentInfo.h"
#import "../XCAudioCacheConst.h"

// 内部使用的 NSCache 键包装类，用于跟踪歌曲ID
@interface XCSegmentCacheKey : NSObject <NSCopying>
@property (nonatomic, copy) NSString *songId;
@property (nonatomic, assign) NSInteger segmentIndex;
@property (nonatomic, copy) NSString *keyString;
- (instancetype)initWithSongId:(NSString *)songId segmentIndex:(NSInteger)segmentIndex;
@end

@implementation XCSegmentCacheKey

- (instancetype)initWithSongId:(NSString *)songId segmentIndex:(NSInteger)segmentIndex {
    self = [super init];
    if (self) {
        _songId = [songId copy];
        _segmentIndex = segmentIndex;
        _keyString = [NSString stringWithFormat:@"%@_%ld", songId, (long)segmentIndex];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    XCSegmentCacheKey *copy = [[XCSegmentCacheKey allocWithZone:zone] initWithSongId:self.songId
                                                                        segmentIndex:self.segmentIndex];
    return copy;
}

- (NSUInteger)hash {
    return self.keyString.hash;
}

- (BOOL)isEqual:(id)object {
    if (self == object) return YES;
    if (![object isKindOfClass:[XCSegmentCacheKey class]]) return NO;
    XCSegmentCacheKey *other = (XCSegmentCacheKey *)object;
    return [self.keyString isEqualToString:other.keyString];
}

@end

#pragma mark - XCMemoryCacheManager

@interface XCMemoryCacheManager () <NSCacheDelegate>
@property (nonatomic, strong) NSCache<XCSegmentCacheKey *, NSData *> *cache;
@property (nonatomic, strong) NSMutableSet<NSString *> *cachedSongIds;
@property (nonatomic, strong) dispatch_queue_t syncQueue;
@property (nonatomic, copy, readwrite) NSString *currentPrioritySongId;
@end

@implementation XCMemoryCacheManager

#pragma mark - 单例

+ (instancetype)sharedInstance {
    static XCMemoryCacheManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

#pragma mark - 初始化

- (instancetype)init {
    self = [super init];
    if (self) {
        _cache = [[NSCache alloc] init];
        _cache.name = @"com.spotifyclone.audio.cache.L1";
        _cache.totalCostLimit = kAudioCacheMemoryLimit; // 100MB
        _cache.delegate = self;
        
        _cachedSongIds = [NSMutableSet set];
        _syncQueue = dispatch_queue_create("com.spotifyclone.cache.memory", DISPATCH_QUEUE_CONCURRENT);
        
        // 注册内存警告通知
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleMemoryWarning)
                                                     name:UIApplicationDidReceiveMemoryWarningNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - 键生成

- (XCSegmentCacheKey *)keyForSongId:(NSString *)songId segmentIndex:(NSInteger)segmentIndex {
    return [[XCSegmentCacheKey alloc] initWithSongId:songId segmentIndex:segmentIndex];
}

#pragma mark - 分段存储与读取

- (void)storeSegmentData:(NSData *)data
              forSongId:(NSString *)songId
           segmentIndex:(NSInteger)segmentIndex {
    if (!data || data.length == 0 || !songId || songId.length == 0) {
        NSLog(@"[MemoryCache] Invalid parameters for storeSegmentData");
        return;
    }
    
    XCSegmentCacheKey *key = [self keyForSongId:songId segmentIndex:segmentIndex];
    NSInteger cost = data.length;
    
    [self.cache setObject:data forKey:key cost:cost];
    
    dispatch_barrier_async(self.syncQueue, ^{
        [self.cachedSongIds addObject:songId];
    });
    
    NSLog(@"[MemoryCache] Stored segment %@_%ld, size: %ld bytes", songId, (long)segmentIndex, (long)cost);
}

- (NSData *)segmentDataForSongId:(NSString *)songId
                    segmentIndex:(NSInteger)segmentIndex {
    if (!songId || songId.length == 0) return nil;
    
    XCSegmentCacheKey *key = [self keyForSongId:songId segmentIndex:segmentIndex];
    NSData *data = [self.cache objectForKey:key];
    
    if (data) {
        NSLog(@"[MemoryCache] Hit segment %@_%ld, size: %ld", songId, (long)segmentIndex, (long)data.length);
    }
    
    return data;
}

- (BOOL)hasSegmentForSongId:(NSString *)songId
               segmentIndex:(NSInteger)segmentIndex {
    return [self segmentDataForSongId:songId segmentIndex:segmentIndex] != nil;
}

- (NSArray<XCAudioSegmentInfo *> *)getAllSegmentsForSongId:(NSString *)songId {
    if (!songId || songId.length == 0) return @[];
    
    NSMutableArray<XCAudioSegmentInfo *> *segments = [NSMutableArray array];
    NSInteger index = 0;
    
    // 按索引顺序查找，直到找不到为止
    while (YES) {
        NSData *data = [self segmentDataForSongId:songId segmentIndex:index];
        if (!data) break;
        
        XCAudioSegmentInfo *info = [[XCAudioSegmentInfo alloc] initWithIndex:index
                                                                      offset:index * kAudioSegmentSize
                                                                        size:data.length];
        info.data = data;
        info.isDownloaded = YES;
        [segments addObject:info];
        
        index++;
        
        // 安全检查：防止无限循环
        if (index > 10000) {
            NSLog(@"[MemoryCache] Warning: too many segments for %@", songId);
            break;
        }
    }
    
    // 按 index 排序（理论上已经是顺序，但确保正确性）
    [segments sortUsingComparator:^NSComparisonResult(XCAudioSegmentInfo *a, XCAudioSegmentInfo *b) {
        return a.index < b.index ? NSOrderedAscending : NSOrderedDescending;
    }];
    
    NSLog(@"[MemoryCache] Got %ld segments for %@", (long)segments.count, songId);
    return [segments copy];
}

- (void)clearSegmentsForSongId:(NSString *)songId {
    if (!songId || songId.length == 0) return;
    
    // 找到该歌曲的所有分段并移除
    NSInteger index = 0;
    NSInteger removedCount = 0;
    
    while (YES) {
        XCSegmentCacheKey *key = [self keyForSongId:songId segmentIndex:index];
        
        // 检查该键是否存在
        NSData *data = [self.cache objectForKey:key];
        if (!data) break;
        
        [self.cache removeObjectForKey:key];
        removedCount++;
        index++;
        
        // 安全检查
        if (index > 10000) break;
    }
    
    dispatch_barrier_async(self.syncQueue, ^{
        [self.cachedSongIds removeObject:songId];
    });
    
    NSLog(@"[MemoryCache] Cleared %ld segments for %@", (long)removedCount, songId);
}

#pragma mark - 优先级管理

- (void)setCurrentSongPriority:(NSString *)songId {
    NSString *oldSongId = self.currentPrioritySongId;
    self.currentPrioritySongId = [songId copy];
    
    NSLog(@"[MemoryCache] Priority song changed: %@ -> %@", oldSongId ?: @"nil", songId ?: @"nil");
}

#pragma mark - 缓存统计

- (NSInteger)totalCost {
    // NSCache 不直接提供总成本查询，我们使用近似值
    // 实际使用时可以通过统计存储时的 cost 来跟踪
    // 这里返回 0 表示未知，或者可以实现自定义统计
    return 0;
}

- (NSInteger)cachedSongCount {
    __block NSInteger count = 0;
    dispatch_sync(self.syncQueue, ^{
        count = self.cachedSongIds.count;
    });
    return count;
}

- (NSInteger)segmentCountForSongId:(NSString *)songId {
    if (!songId || songId.length == 0) return 0;
    
    NSInteger count = 0;
    NSInteger index = 0;
    
    while (YES) {
        XCSegmentCacheKey *key = [self keyForSongId:songId segmentIndex:index];
        if ([self.cache objectForKey:key]) {
            count++;
            index++;
        } else {
            break;
        }
        
        if (index > 10000) break;
    }
    
    return count;
}

#pragma mark - 内存管理

- (void)handleMemoryWarning {
    NSLog(@"[MemoryCache] Received memory warning, trimming cache...");
    [self trimCache];
}

- (void)trimCache {
    NSString *prioritySongId = self.currentPrioritySongId;
    
    if (!prioritySongId) {
        // 没有优先歌曲，清理全部
        [self.cache removeAllObjects];
        dispatch_barrier_async(self.syncQueue, ^{
            [self.cachedSongIds removeAllObjects];
        });
        NSLog(@"[MemoryCache] Trimmed all cache (no priority song)");
        return;
    }
    
    // 只保留优先歌曲的分段
    NSMutableArray<XCSegmentCacheKey *> *keysToRemove = [NSMutableArray array];
    
    // 注意：NSCache 不提供枚举所有键的方法，所以我们从 cachedSongIds 推断
    dispatch_sync(self.syncQueue, ^{
        for (NSString *songId in self.cachedSongIds) {
            if (![songId isEqualToString:prioritySongId]) {
                // 标记该歌曲的所有分段需要删除
                NSInteger index = 0;
                while (index < 10000) {
                    XCSegmentCacheKey *key = [[XCSegmentCacheKey alloc] initWithSongId:songId segmentIndex:index];
                    if ([self.cache objectForKey:key]) {
                        [keysToRemove addObject:key];
                        index++;
                    } else {
                        break;
                    }
                }
            }
        }
    });
    
    // 执行删除
    for (XCSegmentCacheKey *key in keysToRemove) {
        [self.cache removeObjectForKey:key];
    }
    
    // 更新歌曲集合
    dispatch_barrier_async(self.syncQueue, ^{
        NSMutableSet *songsToRemove = [NSMutableSet set];
        for (NSString *songId in self.cachedSongIds) {
            if (![songId isEqualToString:prioritySongId]) {
                [songsToRemove addObject:songId];
            }
        }
        [self.cachedSongIds minusSet:songsToRemove];
    });
    
    NSLog(@"[MemoryCache] Trimmed cache, kept priority song: %@", prioritySongId);
}

- (void)clearAllCache {
    [self.cache removeAllObjects];
    dispatch_barrier_async(self.syncQueue, ^{
        [self.cachedSongIds removeAllObjects];
    });
    self.currentPrioritySongId = nil;
    NSLog(@"[MemoryCache] Cleared all cache");
}

#pragma mark - NSCacheDelegate

- (void)cache:(NSCache *)cache willEvictObject:(id)obj {
    // 当 NSCache 自动移除对象时调用（内存压力大时）
    // 可以在这里做日志记录，但通常不需要特别处理
    // NSLog(@"[MemoryCache] Object evicted due to memory pressure");
}

@end
