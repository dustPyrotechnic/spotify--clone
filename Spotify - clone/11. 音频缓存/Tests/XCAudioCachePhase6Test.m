//
//  XCAudioCachePhase6Test.m
//  Spotify - clone
//
//  Phase 6 测试实现
//

#import "XCAudioCachePhase6Test.h"
#import "XCAudioCacheManager.h"
#import "XCAudioCachePathUtils.h"
#import "XCAudioCacheConst.h"
#import "XCAudioSongCacheInfo.h"
#import "XCCacheIndexManager.h"

static NSString *const kTestPrefix = @"[Phase6Test]";

@implementation XCAudioCachePhase6Test

+ (void)runAllTests {
    NSLog(@"%@ ========== Phase 6 Test Start ==========", kTestPrefix);
    
    @try {
        [self testSingleton];
        [self testCacheState];
        [self testThreeLevelQuery];
        [self testL1SegmentStorage];
        [self testL1ToL2Flow];
        [self testL2ToL3Flow];
        [self testSongSwitchingFlow];
        [self testDeletion];
        [self testPriority];
        [self testStatistics];
        [self testCacheIndexQuery];
        [self testPerformance];
    } @catch (NSException *exception) {
        NSLog(@"%@ ❌ Test failed with exception: %@", kTestPrefix, exception);
    }
    
    NSLog(@"%@ ========== Phase 6 Test End ==========", kTestPrefix);
}

#pragma mark - 测试单例

+ (void)testSingleton {
    NSLog(@"%@ Testing singleton...", kTestPrefix);
    
    XCAudioCacheManager *instance1 = [XCAudioCacheManager sharedInstance];
    XCAudioCacheManager *instance2 = [XCAudioCacheManager sharedInstance];
    
    NSAssert(instance1 != nil, @"Singleton instance should not be nil");
    NSAssert(instance1 == instance2, @"Singleton should return same instance");
    
    NSLog(@"%@ ✅ Singleton OK", kTestPrefix);
}

#pragma mark - 测试缓存状态查询

+ (void)testCacheState {
    NSLog(@"%@ Testing cache state...", kTestPrefix);
    
    XCAudioCacheManager *manager = [XCAudioCacheManager sharedInstance];
    NSString *songId = @"test_state_song";
    
    // 清理
    [manager deleteAllCacheForSongId:songId];
    
    // 测试 None 状态
    XCAudioFileCacheState state = [manager cacheStateForSongId:songId];
    NSAssert(state == XCAudioFileCacheStateNone, @"Initial state should be None");
    
    // 存储 L1 分段
    NSData *segment = [@"test data" dataUsingEncoding:NSUTF8StringEncoding];
    [manager storeSegment:segment forSongId:songId segmentIndex:0];
    
    state = [manager cacheStateForSongId:songId];
    NSAssert(state == XCAudioFileCacheStateInMemory, @"State should be InMemory");
    
    // 清理
    [manager deleteAllCacheForSongId:songId];
    
    NSLog(@"%@ ✅ Cache state OK", kTestPrefix);
}

#pragma mark - 测试三级查询

+ (void)testThreeLevelQuery {
    NSLog(@"%@ Testing three-level query...", kTestPrefix);
    
    XCAudioCacheManager *manager = [XCAudioCacheManager sharedInstance];
    NSString *songId = @"test_query_song";
    
    // 清理
    [manager deleteAllCacheForSongId:songId];
    
    // 测试 1: 无缓存时返回 nil
    NSURL *url = [manager cachedURLForSongId:songId];
    NSAssert(url == nil, @"Should return nil when no cache");
    
    // 测试 2: 创建 L3 缓存，验证能查询到
    NSString *cachePath = [[XCAudioCachePathUtils sharedInstance] cacheFilePathForSongId:songId];
    NSData *songData = [@"Complete song data for L3" dataUsingEncoding:NSUTF8StringEncoding];
    [songData writeToFile:cachePath atomically:YES];
    
    // 添加到索引
    XCAudioSongCacheInfo *info = [[XCAudioSongCacheInfo alloc] initWithSongId:songId totalSize:songData.length];
    [[XCCacheIndexManager sharedInstance] addSongCacheInfo:info];
    
    url = [manager cachedURLForSongId:songId];
    NSAssert(url != nil, @"Should return L3 URL");
    NSAssert([url.path isEqualToString:cachePath], @"URL path should match cache path");
    
    // 清理 L3，创建 L2
    [manager deleteCompleteCacheForSongId:songId];
    NSString *tempPath = [[XCAudioCachePathUtils sharedInstance] tempFilePathForSongId:songId];
    [songData writeToFile:tempPath atomically:YES];
    
    url = [manager cachedURLForSongId:songId];
    NSAssert(url != nil, @"Should return L2 URL");
    NSAssert([url.path isEqualToString:tempPath], @"URL path should match temp path");
    
    // 清理
    [manager deleteAllCacheForSongId:songId];
    
    NSLog(@"%@ ✅ Three-level query OK", kTestPrefix);
}

#pragma mark - 测试 L1 分段存储

+ (void)testL1SegmentStorage {
    NSLog(@"%@ Testing L1 segment storage...", kTestPrefix);
    
    XCAudioCacheManager *manager = [XCAudioCacheManager sharedInstance];
    NSString *songId = @"test_l1_song";
    
    // 清理
    [manager clearMemoryCacheForSongId:songId];
    
    // 存储多个分段
    NSData *seg0 = [@"Segment 0 data" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *seg1 = [@"Segment 1 data" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *seg2 = [@"Segment 2 data" dataUsingEncoding:NSUTF8StringEncoding];
    
    [manager storeSegment:seg0 forSongId:songId segmentIndex:0];
    [manager storeSegment:seg1 forSongId:songId segmentIndex:1];
    [manager storeSegment:seg2 forSongId:songId segmentIndex:2];
    
    // 验证存在性
    NSAssert([manager hasSegmentForSongId:songId segmentIndex:0], @"Segment 0 should exist");
    NSAssert([manager hasSegmentForSongId:songId segmentIndex:1], @"Segment 1 should exist");
    NSAssert([manager hasSegmentForSongId:songId segmentIndex:2], @"Segment 2 should exist");
    NSAssert(![manager hasSegmentForSongId:songId segmentIndex:3], @"Segment 3 should not exist");
    
    // 验证数量
    NSInteger count = [manager segmentCountForSongId:songId];
    NSAssert(count == 3, @"Should have 3 segments");
    
    // 验证读取
    NSData *retrieved0 = [manager getSegmentForSongId:songId segmentIndex:0];
    NSAssert([retrieved0 isEqualToData:seg0], @"Segment 0 data should match");
    
    // 清理
    [manager clearMemoryCacheForSongId:songId];
    
    NSLog(@"%@ ✅ L1 segment storage OK", kTestPrefix);
}

#pragma mark - 测试 L1 → L2 流转

+ (void)testL1ToL2Flow {
    NSLog(@"%@ Testing L1 -> L2 flow...", kTestPrefix);
    
    XCAudioCacheManager *manager = [XCAudioCacheManager sharedInstance];
    NSString *songId = @"test_l1_l2_flow";
    
    // 清理
    [manager deleteAllCacheForSongId:songId];
    
    // 创建 L1 分段
    NSData *seg0 = [@"Part1_" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *seg1 = [@"Part2_" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *seg2 = [@"Part3" dataUsingEncoding:NSUTF8StringEncoding];
    
    [manager storeSegment:seg0 forSongId:songId segmentIndex:0];
    [manager storeSegment:seg1 forSongId:songId segmentIndex:1];
    [manager storeSegment:seg2 forSongId:songId segmentIndex:2];
    
    // 执行 L1 → L2 流转
    BOOL success = [manager finalizeCurrentSong:songId];
    NSAssert(success, @"Finalize should succeed");
    
    // 验证 L2 文件存在
    NSAssert([manager hasTempCacheForSongId:songId], @"Should have temp cache after finalize");
    
    // 验证 L2 文件内容
    NSURL *tempURL = [manager cachedURLForSongId:songId];
    NSData *tempData = [NSData dataWithContentsOfURL:tempURL];
    NSString *tempContent = [[NSString alloc] initWithData:tempData encoding:NSUTF8StringEncoding];
    NSAssert([tempContent isEqualToString:@"Part1_Part2_Part3"], @"Merged content should be correct");
    
    // 清理
    [manager deleteAllCacheForSongId:songId];
    
    NSLog(@"%@ ✅ L1 -> L2 flow OK", kTestPrefix);
}

#pragma mark - 测试 L2 → L3 流转

+ (void)testL2ToL3Flow {
    NSLog(@"%@ Testing L2 -> L3 flow...", kTestPrefix);
    
    XCAudioCacheManager *manager = [XCAudioCacheManager sharedInstance];
    NSString *songId = @"test_l2_l3_flow";
    
    // 清理
    [manager deleteAllCacheForSongId:songId];
    
    // 创建 L2 临时文件
    NSData *songData = [@"Complete song data" dataUsingEncoding:NSUTF8StringEncoding];
    NSString *tempPath = [[XCAudioCachePathUtils sharedInstance] tempFilePathForSongId:songId];
    [songData writeToFile:tempPath atomically:YES];
    
    // 验证 L2 存在，L3 不存在
    NSAssert([manager hasTempCacheForSongId:songId], @"Should have temp cache");
    NSAssert(![manager hasCompleteCacheForSongId:songId], @"Should not have complete cache yet");
    
    // 执行 L2 → L3 流转
    BOOL success = [manager confirmCompleteSong:songId expectedSize:songData.length];
    NSAssert(success, @"Confirm and move should succeed");
    
    // 验证 L3 存在，L2 不存在
    NSAssert([manager hasCompleteCacheForSongId:songId], @"Should have complete cache");
    NSAssert(![manager hasTempCacheForSongId:songId], @"Should not have temp cache after move");
    
    // 清理
    [manager deleteAllCacheForSongId:songId];
    
    NSLog(@"%@ ✅ L2 -> L3 flow OK", kTestPrefix);
}

#pragma mark - 测试完整切歌流程

+ (void)testSongSwitchingFlow {
    NSLog(@"%@ Testing song switching flow...", kTestPrefix);
    
    XCAudioCacheManager *manager = [XCAudioCacheManager sharedInstance];
    NSString *songId = @"test_switch_flow";
    
    // 清理
    [manager deleteAllCacheForSongId:songId];
    
    // 步骤 1: 模拟播放，存储分段到 L1
    NSData *seg0 = [@"MusicPart1_" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *seg1 = [@"MusicPart2_" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *seg2 = [@"MusicPart3" dataUsingEncoding:NSUTF8StringEncoding];
    NSInteger totalSize = seg0.length + seg1.length + seg2.length;
    
    [manager storeSegment:seg0 forSongId:songId segmentIndex:0];
    [manager storeSegment:seg1 forSongId:songId segmentIndex:1];
    [manager storeSegment:seg2 forSongId:songId segmentIndex:2];
    
    NSAssert([manager cacheStateForSongId:songId] == XCAudioFileCacheStateInMemory, @"Should be InMemory");
    
    // 步骤 2: 切歌，执行完整保存流程
    XCAudioFileCacheState finalState = [manager saveAndFinalizeSong:songId expectedSize:totalSize];
    
    NSAssert(finalState == XCAudioFileCacheStateComplete, @"Should be Complete after save");
    NSAssert([manager hasCompleteCacheForSongId:songId], @"Should have complete cache");
    
    // 验证文件内容正确
    NSURL *cacheURL = [manager cachedURLForSongId:songId];
    NSData *cachedData = [NSData dataWithContentsOfURL:cacheURL];
    NSString *cachedContent = [[NSString alloc] initWithData:cachedData encoding:NSUTF8StringEncoding];
    NSAssert([cachedContent isEqualToString:@"MusicPart1_MusicPart2_MusicPart3"], @"Cached content should be correct");
    
    // 清理
    [manager deleteAllCacheForSongId:songId];
    
    NSLog(@"%@ ✅ Song switching flow OK", kTestPrefix);
}

#pragma mark - 测试删除操作

+ (void)testDeletion {
    NSLog(@"%@ Testing deletion...", kTestPrefix);
    
    XCAudioCacheManager *manager = [XCAudioCacheManager sharedInstance];
    NSString *songId = @"test_delete";
    
    // 创建 L1/L2/L3 缓存
    [manager storeSegment:[@"test" dataUsingEncoding:NSUTF8StringEncoding]
                forSongId:songId
             segmentIndex:0];
    
    NSData *songData = [@"song data" dataUsingEncoding:NSUTF8StringEncoding];
    NSString *tempPath = [[XCAudioCachePathUtils sharedInstance] tempFilePathForSongId:songId];
    [songData writeToFile:tempPath atomically:YES];
    
    NSString *cachePath = [[XCAudioCachePathUtils sharedInstance] cacheFilePathForSongId:songId];
    [songData writeToFile:cachePath atomically:YES];
    XCAudioSongCacheInfo *info = [[XCAudioSongCacheInfo alloc] initWithSongId:songId totalSize:songData.length];
    [[XCCacheIndexManager sharedInstance] addSongCacheInfo:info];
    
    // 验证都有
    NSAssert([manager hasMemoryCacheForSongId:songId], @"Should have L1");
    NSAssert([manager hasTempCacheForSongId:songId], @"Should have L2");
    NSAssert([manager hasCompleteCacheForSongId:songId], @"Should have L3");
    
    // 删除 L1
    [manager clearMemoryCacheForSongId:songId];
    NSAssert(![manager hasMemoryCacheForSongId:songId], @"Should not have L1");
    
    // 重新创建 L1
    [manager storeSegment:[@"test" dataUsingEncoding:NSUTF8StringEncoding]
                forSongId:songId
             segmentIndex:0];
    
    // 删除全部
    [manager deleteAllCacheForSongId:songId];
    NSAssert(![manager hasMemoryCacheForSongId:songId], @"Should not have L1 after delete all");
    NSAssert(![manager hasTempCacheForSongId:songId], @"Should not have L2 after delete all");
    NSAssert(![manager hasCompleteCacheForSongId:songId], @"Should not have L3 after delete all");
    
    NSLog(@"%@ ✅ Deletion OK", kTestPrefix);
}

#pragma mark - 测试优先级

+ (void)testPriority {
    NSLog(@"%@ Testing priority...", kTestPrefix);
    
    XCAudioCacheManager *manager = [XCAudioCacheManager sharedInstance];
    NSString *songId = @"test_priority";
    
    [manager setCurrentPrioritySong:songId];
    NSAssert([manager.currentPrioritySongId isEqualToString:songId], @"Priority song should be set");
    
    NSLog(@"%@ ✅ Priority OK", kTestPrefix);
}

#pragma mark - 测试统计信息

+ (void)testStatistics {
    NSLog(@"%@ Testing statistics...", kTestPrefix);
    
    XCAudioCacheManager *manager = [XCAudioCacheManager sharedInstance];
    
    NSDictionary *stats = [manager cacheStatistics];
    NSAssert(stats != nil, @"Statistics should not be nil");
    NSAssert(stats[@"L1_Memory"] != nil, @"Should have L1 stats");
    NSAssert(stats[@"L2_Temp"] != nil, @"Should have L2 stats");
    NSAssert(stats[@"L3_Complete"] != nil, @"Should have L3 stats");
    NSAssert(stats[@"Total"] != nil, @"Should have total");
    
    NSLog(@"%@ Cache Statistics: %@", kTestPrefix, stats);
    NSLog(@"%@ ✅ Statistics OK", kTestPrefix);
}

#pragma mark - 测试缓存索引查询

+ (void)testCacheIndexQuery {
    NSLog(@"%@ Testing cache index query...", kTestPrefix);
    
    XCAudioCacheManager *manager = [XCAudioCacheManager sharedInstance];
    NSString *songId = @"test_index_query";
    
    // 清理
    [manager deleteAllCacheForSongId:songId];
    
    // 无缓存时查询应为 nil
    XCAudioSongCacheInfo *info = [manager cacheInfoForSongId:songId];
    NSAssert(info == nil, @"Should return nil for uncached song");
    
    // 创建 L3 缓存
    NSData *songData = [@"indexed song" dataUsingEncoding:NSUTF8StringEncoding];
    NSString *cachePath = [[XCAudioCachePathUtils sharedInstance] cacheFilePathForSongId:songId];
    [songData writeToFile:cachePath atomically:YES];
    
    info = [[XCAudioSongCacheInfo alloc] initWithSongId:songId totalSize:songData.length];
    [[XCCacheIndexManager sharedInstance] addSongCacheInfo:info];
    
    // 查询索引
    info = [manager cacheInfoForSongId:songId];
    NSAssert(info != nil, @"Should return info for cached song");
    NSAssert([info.songId isEqualToString:songId], @"SongId should match");
    NSAssert(info.totalSize == songData.length, @"TotalSize should match");
    
    // 清理
    [manager deleteAllCacheForSongId:songId];
    
    NSLog(@"%@ ✅ Cache index query OK", kTestPrefix);
}

#pragma mark - 性能测试

+ (void)testPerformance {
    NSLog(@"%@ Testing performance...", kTestPrefix);
    
    XCAudioCacheManager *manager = [XCAudioCacheManager sharedInstance];
    NSString *songId = @"test_performance";
    NSInteger segmentCount = 100;
    
    // 清理
    [manager deleteAllCacheForSongId:songId];
    
    // 性能测试 1: L1 分段存储
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    for (NSInteger i = 0; i < segmentCount; i++) {
        NSData *data = [NSData dataWithBytes:(uint8_t[]) { (uint8_t)(i % 256) } length:1];
        [manager storeSegment:data forSongId:songId segmentIndex:i];
    }
    CFAbsoluteTime storeTime = CFAbsoluteTimeGetCurrent() - start;
    NSLog(@"%@ Store %ld segments: %.3fms", kTestPrefix, (long)segmentCount, storeTime * 1000);
    
    // 性能测试 2: L1 分段读取
    start = CFAbsoluteTimeGetCurrent();
    for (NSInteger i = 0; i < segmentCount; i++) {
        [manager getSegmentForSongId:songId segmentIndex:i];
    }
    CFAbsoluteTime readTime = CFAbsoluteTimeGetCurrent() - start;
    NSLog(@"%@ Read %ld segments: %.3fms", kTestPrefix, (long)segmentCount, readTime * 1000);
    
    // 性能测试 3: 状态查询
    start = CFAbsoluteTimeGetCurrent();
    for (NSInteger i = 0; i < 1000; i++) {
        [manager cacheStateForSongId:songId];
    }
    CFAbsoluteTime stateTime = CFAbsoluteTimeGetCurrent() - start;
    NSLog(@"%@ State query 1000 times: %.3fms", kTestPrefix, stateTime * 1000);
    
    // 断言性能要求
    NSAssert(storeTime < 1.0, @"Store should be fast");
    NSAssert(readTime < 1.0, @"Read should be fast");
    NSAssert(stateTime < 1.0, @"State query should be fast");
    
    // 清理
    [manager deleteAllCacheForSongId:songId];
    
    NSLog(@"%@ ✅ Performance OK", kTestPrefix);
}

@end
