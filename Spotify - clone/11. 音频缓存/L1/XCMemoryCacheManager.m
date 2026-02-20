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
@property (nonatomic, assign) NSInteger totalCost;  // 跟踪总内存占用
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
        _totalCost = 0;
        
        // 【初始化日志】L1 内存缓存管理器初始化完成，缓存上限 100MB
        // 注册内存警告通知，系统内存紧张时自动清理非优先歌曲缓存
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
    // 【参数校验】确保数据和 songId 有效，无效则记录错误日志并返回
    if (!data || data.length == 0 || !songId || songId.length == 0) {
        NSLog(@"[MemoryCache] Invalid parameters for storeSegmentData");
        return;
    }
    // 【存储流程】1.生成缓存键 2.计算成本 3.存储到 NSCache 4.更新歌曲集合 5.记录日志
    
    XCSegmentCacheKey *key = [self keyForSongId:songId segmentIndex:segmentIndex];
    NSInteger cost = data.length;
    
    // 【成本计算】检查是否为新分段，用于准确统计内存占用
    BOOL isNewSegment = ([self.cache objectForKey:key] == nil);
    
    // 【NSCache 存储】使用 cost 参数让 NSCache 自动管理内存
    [self.cache setObject:data forKey:key cost:cost];
    
    // 【成本更新】仅新分段增加成本，覆盖不增加
    if (isNewSegment) {
        self.totalCost += cost;
    }
    
    // 【线程安全】使用 barrier 异步更新歌曲 ID 集合
    dispatch_barrier_async(self.syncQueue, ^{
        [self.cachedSongIds addObject:songId];
    });
    
    // 【存储日志】记录分段存储成功信息，用于调试追踪
    NSLog(@"[MemoryCache] Stored segment %@_%ld, size: %ld bytes, totalCost: %ld", 
          songId, (long)segmentIndex, (long)cost, (long)self.totalCost);
}

- (NSData *)segmentDataForSongId:(NSString *)songId
                    segmentIndex:(NSInteger)segmentIndex {
    // 【参数校验】songId 无效直接返回 nil
    if (!songId || songId.length == 0) return nil;
    
    // 【缓存读取】从 NSCache 获取分段数据
    XCSegmentCacheKey *key = [self keyForSongId:songId segmentIndex:segmentIndex];
    NSData *data = [self.cache objectForKey:key];
    
    // 【命中日志】缓存命中时记录日志，方便分析缓存效率
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
    // 【参数校验】songId 无效返回空数组
    if (!songId || songId.length == 0) return @[];
    
    NSMutableArray<XCAudioSegmentInfo *> *segments = [NSMutableArray array];
    NSInteger index = 0;
    
    // 【遍历收集】按索引顺序查找所有分段，直到断点
    while (YES) {
        NSData *data = [self segmentDataForSongId:songId segmentIndex:index];
        if (!data) break; // 断点：找不到该索引的分段
        
        // 【构建信息】创建 XCAudioSegmentInfo 包含元数据和实际数据
        XCAudioSegmentInfo *info = [[XCAudioSegmentInfo alloc] initWithIndex:index
                                                                      offset:index * kAudioSegmentSize
                                                                        size:data.length];
        info.data = data;
        info.isDownloaded = YES;
        [segments addObject:info];
        
        index++;
        
        // 【安全保护】防止异常情况下无限循环（最多支持约 5GB 文件）
        if (index > 10000) {
            NSLog(@"[MemoryCache] Warning: too many segments for %@", songId);
            break;
        }
    }
    
    // 【排序确认】按 index 升序排列，确保合并时顺序正确
    [segments sortUsingComparator:^NSComparisonResult(XCAudioSegmentInfo *a, XCAudioSegmentInfo *b) {
        return a.index < b.index ? NSOrderedAscending : NSOrderedDescending;
    }];
    
    // 【统计日志】记录获取的分段数量，用于调试
    NSLog(@"[MemoryCache] Got %ld segments for %@", (long)segments.count, songId);
    return [segments copy];
}

- (void)clearSegmentsForSongId:(NSString *)songId {
    // 【参数校验】songId 无效直接返回
    if (!songId || songId.length == 0) return;
    
    // 【清理统计】统计移除的分段数量和释放的内存
    NSInteger index = 0;
    NSInteger removedCount = 0;
    NSInteger removedCost = 0;
    
    // 【遍历清理】逐个查找并移除该歌曲的所有分段
    while (YES) {
        XCSegmentCacheKey *key = [self keyForSongId:songId segmentIndex:index];
        
        // 检查该键是否存在
        NSData *data = [self.cache objectForKey:key];
        if (!data) break; // 该索引无数据，说明已清理完毕
        
        removedCost += data.length;
        [self.cache removeObjectForKey:key];
        removedCount++;
        index++;
        
        // 【安全保护】防止无限循环
        if (index > 10000) break;
    }
    
    // 【成本修正】更新总内存占用，防止负数
    self.totalCost -= removedCost;
    if (self.totalCost < 0) self.totalCost = 0;
    
    // 【线程安全】异步移除歌曲 ID
    dispatch_barrier_async(self.syncQueue, ^{
        [self.cachedSongIds removeObject:songId];
    });
    
    // 【清理日志】记录清理结果，用于内存监控
    NSLog(@"[MemoryCache] Cleared %ld segments for %@, freed: %ld bytes, totalCost: %ld", 
          (long)removedCount, songId, (long)removedCost, (long)self.totalCost);
}

#pragma mark - 优先级管理

- (void)setCurrentSongPriority:(NSString *)songId {
    NSString *oldSongId = self.currentPrioritySongId;
    self.currentPrioritySongId = [songId copy];
    
    NSLog(@"[MemoryCache] Priority song changed: %@ -> %@", oldSongId ?: @"nil", songId ?: @"nil");
}

#pragma mark - 缓存统计

- (NSInteger)totalCost {
    return _totalCost;
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
    
    // 【策略分支】无优先歌曲时清理全部缓存
    if (!prioritySongId) {
        [self.cache removeAllObjects];
        self.totalCost = 0;
        dispatch_barrier_async(self.syncQueue, ^{
            [self.cachedSongIds removeAllObjects];
        });
        NSLog(@"[MemoryCache] Trimmed all cache (no priority song)");
        return;
    }
    
    // 【智能清理】只保留当前播放歌曲的分段，清理其他歌曲
    NSMutableArray<XCSegmentCacheKey *> *keysToRemove = [NSMutableArray array];
    __block NSInteger removedCost = 0;
    
    // 【遍历标记】NSCache 不支持枚举，通过 cachedSongIds 推断需清理的键
    dispatch_sync(self.syncQueue, ^{
        for (NSString *songId in self.cachedSongIds) {
            if (![songId isEqualToString:prioritySongId]) {
                // 标记该歌曲的所有分段需要删除
                NSInteger index = 0;
                while (index < 10000) {
                    XCSegmentCacheKey *key = [[XCSegmentCacheKey alloc] initWithSongId:songId segmentIndex:index];
                    NSData *data = [self.cache objectForKey:key];
                    if (data) {
                        [keysToRemove addObject:key];
                        removedCost += data.length;
                        index++;
                    } else {
                        break;
                    }
                }
            }
        }
    });
    
    // 【执行删除】批量移除非优先歌曲的分段
    for (XCSegmentCacheKey *key in keysToRemove) {
        [self.cache removeObjectForKey:key];
    }
    
    // 【成本更新】修正总内存占用
    self.totalCost -= removedCost;
    if (self.totalCost < 0) self.totalCost = 0;
    
    // 【集合更新】移除非优先歌曲的 ID
    dispatch_barrier_async(self.syncQueue, ^{
        NSMutableSet *songsToRemove = [NSMutableSet set];
        for (NSString *songId in self.cachedSongIds) {
            if (![songId isEqualToString:prioritySongId]) {
                [songsToRemove addObject:songId];
            }
        }
        [self.cachedSongIds minusSet:songsToRemove];
    });
    
    // 【清理日志】记录清理结果，保留歌曲信息
    NSLog(@"[MemoryCache] Trimmed cache, freed: %ld bytes, totalCost: %ld, kept priority song: %@", 
          (long)removedCost, (long)self.totalCost, prioritySongId);
}

- (void)clearAllCache {
    [self.cache removeAllObjects];
    self.totalCost = 0;
    dispatch_barrier_async(self.syncQueue, ^{
        [self.cachedSongIds removeAllObjects];
    });
    self.currentPrioritySongId = nil;
    NSLog(@"[MemoryCache] Cleared all cache");
}

#pragma mark - 分段合并（Phase 4）

- (NSData *)mergeAllSegmentsForSongId:(NSString *)songId {
    // 【参数校验】songId 无效返回 nil
    if (!songId || songId.length == 0) return nil;
    
    // 【收集分段】获取该歌曲所有分段信息
    NSArray<XCAudioSegmentInfo *> *segments = [self getAllSegmentsForSongId:songId];
    if (segments.count == 0) return nil;
    
    // 【计算容量】预计算总大小，一次性分配内存提高效率
    NSInteger totalSize = 0;
    for (XCAudioSegmentInfo *seg in segments) {
        totalSize += seg.data.length;
    }
    
    // 【内存合并】按顺序追加所有分段数据到 NSMutableData
    NSMutableData *mergedData = [NSMutableData dataWithCapacity:totalSize];
    for (XCAudioSegmentInfo *seg in segments) {
        [mergedData appendData:seg.data];
    }
    
    // 【合并日志】记录合并结果，用于调试大文件
    NSLog(@"[MemoryCache] Merged %ld segments for %@, total size: %ld", 
          (long)segments.count, songId, (long)totalSize);
    
    return mergedData;
}

- (BOOL)writeMergedSegmentsToFile:(NSString *)filePath forSongId:(NSString *)songId {
    // 【参数校验】确保路径和 songId 有效
    if (!filePath || !songId || songId.length == 0) return NO;
    
    // 【收集分段】获取该歌曲所有分段
    NSArray<XCAudioSegmentInfo *> *segments = [self getAllSegmentsForSongId:songId];
    if (segments.count == 0) {
        NSLog(@"[MemoryCache] No segments to merge for %@", songId);
        return NO;
    }
    
    // 【目录准备】确保目标目录存在
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *dirPath = [filePath stringByDeletingLastPathComponent];
    
    NSError *error;
    if (![fm fileExistsAtPath:dirPath]) {
        [fm createDirectoryAtPath:dirPath
      withIntermediateDirectories:YES
                       attributes:nil
                            error:&error];
        if (error) {
            NSLog(@"[MemoryCache] Failed to create directory: %@", error.localizedDescription);
            return NO;
        }
    }
    
    // 【创建文件】创建空文件准备写入
    [fm createFileAtPath:filePath contents:nil attributes:nil];
    
    // 【流式写入】使用 NSFileHandle 流式追加，内存只保持一段（512KB）
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:filePath];
    if (!fileHandle) {
        NSLog(@"[MemoryCache] Failed to create file handle for %@", filePath);
        return NO;
    }
    
    // 【顺序写入】逐段写入文件，适合大文件（避免内存峰值）
    NSInteger totalWritten = 0;
    for (XCAudioSegmentInfo *seg in segments) {
        [fileHandle writeData:seg.data];
        totalWritten += seg.data.length;
    }
    
    [fileHandle closeFile];
    
    // 【写入日志】记录文件写入完成信息
    NSLog(@"[MemoryCache] Written merged segments to file: %@, segments: %ld, total: %ld bytes", 
          filePath, (long)segments.count, (long)totalWritten);
    
    return YES;
}

#pragma mark - NSCacheDelegate

- (void)cache:(NSCache *)cache willEvictObject:(id)obj {
    // 当 NSCache 自动移除对象时调用（内存压力大时）
    // 可以在这里做日志记录，但通常不需要特别处理
    // NSLog(@"[MemoryCache] Object evicted due to memory pressure");
}

@end
