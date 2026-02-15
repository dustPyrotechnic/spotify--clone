//
//  XCAudioCachePhase3Test.m
//  Spotify - clone
//

#import "XCAudioCachePhase3Test.h"
#import "../L1/XCMemoryCacheManager.h"
#import "../L1/XCAudioSegmentInfo.h"
#import "../XCAudioCacheConst.h"

@implementation XCAudioCachePhase3Test

+ (void)runAllTests {
    NSLog(@"[Phase3Test] ========== Phase 3 Test Start ==========");
    
    // 先清理缓存
    [[XCMemoryCacheManager sharedInstance] clearAllCache];
    
    [self testSingleton];
    [self testStoreAndRetrieveSegment];
    [self testHasSegment];
    [self testMultipleSegments];
    [self testGetAllSegments];
    [self testClearSegmentsForSong];
    [self testPrioritySong];
    [self testCacheStatistics];
    [self testConcurrentAccess];
    
    // 测试结束清理
    [[XCMemoryCacheManager sharedInstance] clearAllCache];
    
    NSLog(@"[Phase3Test] ========== Phase 3 Test End ==========");
}

#pragma mark - 基础功能测试

+ (void)testSingleton {
    NSLog(@"[Phase3Test] Testing singleton...");
    
    XCMemoryCacheManager *manager1 = [XCMemoryCacheManager sharedInstance];
    XCMemoryCacheManager *manager2 = [XCMemoryCacheManager sharedInstance];
    
    NSAssert(manager1 == manager2, @"Singleton should return same instance");
    
    NSLog(@"[Phase3Test] Singleton OK");
}

+ (void)testStoreAndRetrieveSegment {
    NSLog(@"[Phase3Test] Testing store and retrieve segment...");
    
    XCMemoryCacheManager *manager = [XCMemoryCacheManager sharedInstance];
    NSString *testData = @"Test segment data for song 123";
    NSData *data = [testData dataUsingEncoding:NSUTF8StringEncoding];
    NSString *songId = @"test_song_123";
    NSInteger segmentIndex = 0;
    
    // 存储
    [manager storeSegmentData:data forSongId:songId segmentIndex:segmentIndex];
    
    // 读取
    NSData *retrieved = [manager segmentDataForSongId:songId segmentIndex:segmentIndex];
    NSAssert(retrieved != nil, @"Should retrieve stored segment");
    
    NSString *result = [[NSString alloc] initWithData:retrieved encoding:NSUTF8StringEncoding];
    NSAssert([result isEqualToString:testData], @"Retrieved data should match original");
    
    // 清理
    [manager clearSegmentsForSongId:songId];
    
    NSLog(@"[Phase3Test] Store and retrieve OK");
}

+ (void)testHasSegment {
    NSLog(@"[Phase3Test] Testing hasSegment...");
    
    XCMemoryCacheManager *manager = [XCMemoryCacheManager sharedInstance];
    NSString *songId = @"test_song_has";
    
    // 不存在时返回 NO
    BOOL existsBefore = [manager hasSegmentForSongId:songId segmentIndex:0];
    NSAssert(existsBefore == NO, @"Should not have segment before storing");
    
    // 存储后返回 YES
    NSData *data = [@"test" dataUsingEncoding:NSUTF8StringEncoding];
    [manager storeSegmentData:data forSongId:songId segmentIndex:0];
    
    BOOL existsAfter = [manager hasSegmentForSongId:songId segmentIndex:0];
    NSAssert(existsAfter == YES, @"Should have segment after storing");
    
    // 不存在的索引返回 NO
    BOOL existsOtherIndex = [manager hasSegmentForSongId:songId segmentIndex:999];
    NSAssert(existsOtherIndex == NO, @"Should not have segment at other index");
    
    // 清理
    [manager clearSegmentsForSongId:songId];
    
    NSLog(@"[Phase3Test] hasSegment OK");
}

+ (void)testMultipleSegments {
    NSLog(@"[Phase3Test] Testing multiple segments...");
    
    XCMemoryCacheManager *manager = [XCMemoryCacheManager sharedInstance];
    NSString *songId = @"test_song_multi";
    
    // 存储多个分段
    for (NSInteger i = 0; i < 5; i++) {
        NSString *content = [NSString stringWithFormat:@"Segment %ld data", (long)i];
        NSData *data = [content dataUsingEncoding:NSUTF8StringEncoding];
        [manager storeSegmentData:data forSongId:songId segmentIndex:i];
    }
    
    // 验证每个分段
    for (NSInteger i = 0; i < 5; i++) {
        NSData *data = [manager segmentDataForSongId:songId segmentIndex:i];
        NSAssert(data != nil, @"Should retrieve segment %ld", (long)i);
        
        NSString *expected = [NSString stringWithFormat:@"Segment %ld data", (long)i];
        NSString *result = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSAssert([result isEqualToString:expected], @"Segment %ld data should match", (long)i);
    }
    
    // 验证分段数量
    NSInteger count = [manager segmentCountForSongId:songId];
    NSAssert(count == 5, @"Should have 5 segments, got %ld", (long)count);
    
    // 清理
    [manager clearSegmentsForSongId:songId];
    
    NSLog(@"[Phase3Test] Multiple segments OK");
}

+ (void)testGetAllSegments {
    NSLog(@"[Phase3Test] Testing getAllSegments...");
    
    XCMemoryCacheManager *manager = [XCMemoryCacheManager sharedInstance];
    NSString *songId = @"test_song_all";
    
    // 按非顺序存储分段
    [manager storeSegmentData:[@"data2" dataUsingEncoding:NSUTF8StringEncoding]
                   forSongId:songId
                segmentIndex:2];
    [manager storeSegmentData:[@"data0" dataUsingEncoding:NSUTF8StringEncoding]
                   forSongId:songId
                segmentIndex:0];
    [manager storeSegmentData:[@"data1" dataUsingEncoding:NSUTF8StringEncoding]
                   forSongId:songId
                segmentIndex:1];
    
    // 获取所有分段
    NSArray<XCAudioSegmentInfo *> *segments = [manager getAllSegmentsForSongId:songId];
    
    // 验证数量（注意：getAllSegments 是按顺序查找，如果中间有空缺会停止）
    NSAssert(segments.count == 3, @"Should have 3 segments, got %lu", (unsigned long)segments.count);
    
    // 验证顺序（应该是 0, 1, 2）
    for (NSInteger i = 0; i < segments.count; i++) {
        XCAudioSegmentInfo *info = segments[i];
        NSAssert(info.index == i, @"Segment at position %ld should have index %ld", (long)i, (long)i);
        NSAssert(info.data != nil, @"Segment %ld should have data", (long)i);
        NSAssert(info.isDownloaded == YES, @"Segment %ld should be marked downloaded", (long)i);
    }
    
    // 清理
    [manager clearSegmentsForSongId:songId];
    
    NSLog(@"[Phase3Test] getAllSegments OK");
}

+ (void)testClearSegmentsForSong {
    NSLog(@"[Phase3Test] Testing clearSegmentsForSong...");
    
    XCMemoryCacheManager *manager = [XCMemoryCacheManager sharedInstance];
    NSString *songId1 = @"test_song_clear_1";
    NSString *songId2 = @"test_song_clear_2";
    
    // 为两个歌曲存储分段
    for (NSInteger i = 0; i < 3; i++) {
        [manager storeSegmentData:[@"data" dataUsingEncoding:NSUTF8StringEncoding]
                       forSongId:songId1
                    segmentIndex:i];
        [manager storeSegmentData:[@"data" dataUsingEncoding:NSUTF8StringEncoding]
                       forSongId:songId2
                    segmentIndex:i];
    }
    
    // 验证都存在
    NSAssert([manager segmentCountForSongId:songId1] == 3, @"Song1 should have 3 segments");
    NSAssert([manager segmentCountForSongId:songId2] == 3, @"Song2 should have 3 segments");
    
    // 清理 song1
    [manager clearSegmentsForSongId:songId1];
    
    // 验证 song1 被清理
    NSAssert([manager segmentCountForSongId:songId1] == 0, @"Song1 should have 0 segments after clear");
    
    // 验证 song2 还在
    NSAssert([manager segmentCountForSongId:songId2] == 3, @"Song2 should still have 3 segments");
    
    // 验证具体分段
    NSAssert([manager hasSegmentForSongId:songId1 segmentIndex:0] == NO, @"Song1 segment should be gone");
    NSAssert([manager hasSegmentForSongId:songId2 segmentIndex:0] == YES, @"Song2 segment should exist");
    
    // 清理
    [manager clearSegmentsForSongId:songId2];
    
    NSLog(@"[Phase3Test] clearSegmentsForSong OK");
}

#pragma mark - 优先级管理测试

+ (void)testPrioritySong {
    NSLog(@"[Phase3Test] Testing priority song...");
    
    XCMemoryCacheManager *manager = [XCMemoryCacheManager sharedInstance];
    NSString *prioritySong = @"priority_song";
    NSString *otherSong = @"other_song";
    
    // 设置优先歌曲
    [manager setCurrentSongPriority:prioritySong];
    NSAssert([manager.currentPrioritySongId isEqualToString:prioritySong],
             @"Current priority song should be set");
    
    // 为两首歌曲存储分段
    for (NSInteger i = 0; i < 3; i++) {
        [manager storeSegmentData:[@"data" dataUsingEncoding:NSUTF8StringEncoding]
                       forSongId:prioritySong
                    segmentIndex:i];
        [manager storeSegmentData:[@"data" dataUsingEncoding:NSUTF8StringEncoding]
                       forSongId:otherSong
                    segmentIndex:i];
    }
    
    // 执行 trim（模拟内存警告）
    [manager trimCache];
    
    // 验证优先歌曲的分段还在
    NSAssert([manager segmentCountForSongId:prioritySong] == 3,
             @"Priority song should still have segments after trim");
    
    // 清理
    [[XCMemoryCacheManager sharedInstance] clearAllCache];
    
    NSLog(@"[Phase3Test] Priority song OK");
}

#pragma mark - 统计测试

+ (void)testCacheStatistics {
    NSLog(@"[Phase3Test] Testing cache statistics...");
    
    XCMemoryCacheManager *manager = [XCMemoryCacheManager sharedInstance];
    
    // 清理后开始
    [manager clearAllCache];
    
    // 初始状态
    NSInteger initialCount = [manager cachedSongCount];
    NSAssert(initialCount == 0, @"Initial song count should be 0");
    
    // 添加多个歌曲的分段
    [manager storeSegmentData:[@"data" dataUsingEncoding:NSUTF8StringEncoding]
                   forSongId:@"song_a"
                segmentIndex:0];
    [manager storeSegmentData:[@"data" dataUsingEncoding:NSUTF8StringEncoding]
                   forSongId:@"song_b"
                segmentIndex:0];
    [manager storeSegmentData:[@"data" dataUsingEncoding:NSUTF8StringEncoding]
                   forSongId:@"song_c"
                segmentIndex:0];
    
    // 为 song_a 添加更多分段
    [manager storeSegmentData:[@"data" dataUsingEncoding:NSUTF8StringEncoding]
                   forSongId:@"song_a"
                segmentIndex:1];
    [manager storeSegmentData:[@"data" dataUsingEncoding:NSUTF8StringEncoding]
                   forSongId:@"song_a"
                segmentIndex:2];
    
    // 验证歌曲数量
    NSInteger songCount = [manager cachedSongCount];
    NSAssert(songCount == 3, @"Should have 3 songs, got %ld", (long)songCount);
    
    // 验证分段数量
    NSInteger segmentCountA = [manager segmentCountForSongId:@"song_a"];
    NSInteger segmentCountB = [manager segmentCountForSongId:@"song_b"];
    NSAssert(segmentCountA == 3, @"Song A should have 3 segments");
    NSAssert(segmentCountB == 1, @"Song B should have 1 segment");
    
    // 清理一个歌曲
    [manager clearSegmentsForSongId:@"song_a"];
    
    // 验证更新后的数量
    NSInteger songCountAfter = [manager cachedSongCount];
    NSAssert(songCountAfter == 2, @"Should have 2 songs after removal");
    
    // 清理
    [manager clearAllCache];
    
    // 验证全部清空
    NSAssert([manager cachedSongCount] == 0, @"Song count should be 0 after clearAllCache");
    
    NSLog(@"[Phase3Test] Cache statistics OK");
}

#pragma mark - 并发测试

+ (void)testConcurrentAccess {
    NSLog(@"[Phase3Test] Testing concurrent access...");
    
    XCMemoryCacheManager *manager = [XCMemoryCacheManager sharedInstance];
    NSString *songId = @"concurrent_song";
    NSInteger concurrentCount = 100;
    
    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    // 并发存储
    for (NSInteger i = 0; i < concurrentCount; i++) {
        dispatch_group_async(group, queue, ^{
            NSString *content = [NSString stringWithFormat:@"Data %ld", (long)i];
            NSData *data = [content dataUsingEncoding:NSUTF8StringEncoding];
            [manager storeSegmentData:data forSongId:songId segmentIndex:i];
        });
    }
    
    // 等待存储完成
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    
    // 验证数量
    NSInteger count = [manager segmentCountForSongId:songId];
    NSAssert(count == concurrentCount, @"Should have %ld segments, got %ld", (long)concurrentCount, (long)count);
    
    // 并发读取
    __block NSInteger successCount = 0;
    dispatch_group_t readGroup = dispatch_group_create();
    
    for (NSInteger i = 0; i < concurrentCount; i++) {
        dispatch_group_async(readGroup, queue, ^{
            NSData *data = [manager segmentDataForSongId:songId segmentIndex:i];
            if (data) {
                @synchronized(self) {
                    successCount++;
                }
            }
        });
    }
    
    dispatch_group_wait(readGroup, DISPATCH_TIME_FOREVER);
    
    NSAssert(successCount == concurrentCount, @"All %ld concurrent reads should succeed, got %ld",
             (long)concurrentCount, (long)successCount);
    
    // 清理
    [manager clearSegmentsForSongId:songId];
    
    NSLog(@"[Phase3Test] Concurrent access OK");
}

@end
