//
//  XCAudioCachePhase8Test.m
//  Spotify - clone
//
//  Phase 8: 系统集成测试实现
//

#import "XCAudioCachePhase8Test.h"
#import "XCAudioCacheManager.h"
#import "XCPreloadManager.h"
#import "XCAudioCachePathUtils.h"
#import "XCAudioSongCacheInfo.h"
#import "XCCacheIndexManager.h"

// 导入播放器模型（使用相对路径）
#import "../../5. TabBar附加视图，搜索部分/1. 音乐播放器/音乐播放详细页面/XCMusicPlayerModel.h"
#import "../../数据结构/XC-YYSongData.h"

static NSString *const kTestPrefix = @"[Phase8Test]";

@implementation XCAudioCachePhase8Test

+ (void)runAllTests {
    NSLog(@"\n========================================");
    NSLog(@"%@ Phase 8 系统集成测试开始", kTestPrefix);
    NSLog(@"========================================\n");
    
    NSInteger passed = 0;
    NSInteger failed = 0;
    
    // 清理环境
    [[XCAudioCacheManager sharedInstance] clearAllCache];
    [[XCPreloadManager sharedInstance] cancelAllPreloads];
    
    // 测试列表
    NSArray *tests = @[
        @{
            @"name": @"L3 缓存命中播放",
            @"sel": NSStringFromSelector(@selector(testPlayerL3CacheHit))
        },
        @{
            @"name": @"L2 缓存命中播放",
            @"sel": NSStringFromSelector(@selector(testPlayerL2CacheHit))
        },
        @{
            @"name": @"切歌缓存流转",
            @"sel": NSStringFromSelector(@selector(testSongSwitchingCacheFlow))
        },
        @{
            @"name": @"缓存统计信息",
            @"sel": NSStringFromSelector(@selector(testPlayerCacheStatistics))
        },
        @{
            @"name": @"完整播放流程",
            @"sel": NSStringFromSelector(@selector(testCompletePlaybackFlow))
        },
    ];
    
    for (NSDictionary *test in tests) {
        NSString *name = test[@"name"];
        NSString *selStr = test[@"sel"];
        NSLog(@"\n%@ -------- 测试: %@ --------", kTestPrefix, name);
        
        @try {
            SEL sel = NSSelectorFromString(selStr);
            if ([self respondsToSelector:sel]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                [self performSelector:sel];
#pragma clang diagnostic pop
                NSLog(@"%@ ✅ %@ 通过", kTestPrefix, name);
                passed++;
            } else {
                NSLog(@"%@ ❌ %@ 找不到方法", kTestPrefix, name);
                failed++;
            }
        } @catch (NSException *exception) {
            NSLog(@"%@ ❌ %@ 异常: %@", kTestPrefix, name, exception.reason);
            failed++;
        }
    }
    
    NSLog(@"\n========================================");
    NSLog(@"%@ Phase 8 测试完成", kTestPrefix);
    NSLog(@"%@ 通过: %ld, 失败: %ld", kTestPrefix, (long)passed, (long)failed);
    NSLog(@"========================================\n");
}

#pragma mark - 测试 1: L3 缓存命中播放

+ (void)testPlayerL3CacheHit {
    XCMusicPlayerModel *player = [XCMusicPlayerModel sharedInstance];
    XCAudioCacheManager *cacheManager = [XCAudioCacheManager sharedInstance];
    NSString *songId = @"phase8_test_l3_song";
    
    // 清理
    [cacheManager deleteAllCacheForSongId:songId];
    
    // 创建 L3 缓存
    NSString *testData = @"Test L3 complete song data";
    NSData *songData = [testData dataUsingEncoding:NSUTF8StringEncoding];
    NSString *cachePath = [[XCAudioCachePathUtils sharedInstance] cacheFilePathForSongId:songId];
    [songData writeToFile:cachePath atomically:YES];
    
    // 添加到索引
    XCAudioSongCacheInfo *info = [[XCAudioSongCacheInfo alloc] initWithSongId:songId totalSize:songData.length];
    [[XCCacheIndexManager sharedInstance] addSongCacheInfo:info];
    
    // 验证缓存状态
    XCAudioFileCacheState state = [cacheManager cacheStateForSongId:songId];
    NSAssert(state == XCAudioFileCacheStateComplete, @"应该是 L3 完整缓存状态");
    
    // 验证缓存 URL 可以获取
    NSURL *cachedURL = [cacheManager cachedURLForSongId:songId];
    NSAssert(cachedURL != nil, @"应该能获取到 L3 缓存 URL");
    
    NSLog(@"%@ L3 缓存命中测试通过，文件大小: %ld bytes", kTestPrefix, (long)songData.length);
    
    // 清理
    [cacheManager deleteAllCacheForSongId:songId];
}

#pragma mark - 测试 2: L2 缓存命中播放

+ (void)testPlayerL2CacheHit {
    XCAudioCacheManager *cacheManager = [XCAudioCacheManager sharedInstance];
    NSString *songId = @"phase8_test_l2_song";
    
    // 清理
    [cacheManager deleteAllCacheForSongId:songId];
    
    // 创建 L2 临时缓存
    NSString *testData = @"Test L2 temp song data";
    NSData *songData = [testData dataUsingEncoding:NSUTF8StringEncoding];
    NSString *tempPath = [[XCAudioCachePathUtils sharedInstance] tempFilePathForSongId:songId];
    [songData writeToFile:tempPath atomically:YES];
    
    // 验证缓存状态
    XCAudioFileCacheState state = [cacheManager cacheStateForSongId:songId];
    NSAssert(state == XCAudioFileCacheStateTempFile, @"应该是 L2 临时缓存状态");
    
    // 验证缓存 URL 可以获取（应该返回 L2 路径）
    NSURL *cachedURL = [cacheManager cachedURLForSongId:songId];
    NSAssert(cachedURL != nil, @"应该能获取到 L2 缓存 URL");
    NSAssert([cachedURL.path hasSuffix:@".tmp"], @"L2 路径应该以 .tmp 结尾");
    
    NSLog(@"%@ L2 缓存命中测试通过，文件大小: %ld bytes", kTestPrefix, (long)songData.length);
    
    // 清理
    [cacheManager deleteAllCacheForSongId:songId];
}

#pragma mark - 测试 3: 切歌缓存流转

+ (void)testSongSwitchingCacheFlow {
    XCAudioCacheManager *cacheManager = [XCAudioCacheManager sharedInstance];
    NSString *songId = @"phase8_test_switch_song";
    
    // 清理
    [cacheManager deleteAllCacheForSongId:songId];
    
    // 步骤 1: 模拟播放，存储分段到 L1
    NSData *seg0 = [@"MusicPart1_" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *seg1 = [@"MusicPart2_" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *seg2 = [@"MusicPart3" dataUsingEncoding:NSUTF8StringEncoding];
    NSInteger totalSize = seg0.length + seg1.length + seg2.length;
    
    [cacheManager storeSegment:seg0 forSongId:songId segmentIndex:0];
    [cacheManager storeSegment:seg1 forSongId:songId segmentIndex:1];
    [cacheManager storeSegment:seg2 forSongId:songId segmentIndex:2];
    
    // 验证 L1 状态
    XCAudioFileCacheState state = [cacheManager cacheStateForSongId:songId];
    NSAssert(state == XCAudioFileCacheStateInMemory, @"应该是 L1 内存缓存状态");
    NSAssert([cacheManager segmentCountForSongId:songId] == 3, @"应该有 3 个分段");
    
    // 步骤 2: 模拟切歌，执行完整保存流程
    XCAudioFileCacheState finalState = [cacheManager saveAndFinalizeSong:songId expectedSize:totalSize];
    
    // 验证 L3 状态
    NSAssert(finalState == XCAudioFileCacheStateComplete, @"保存后应该是 L3 完整缓存状态");
    NSAssert([cacheManager hasCompleteCacheForSongId:songId], @"应该有 L3 完整缓存");
    NSAssert(![cacheManager hasMemoryCacheForSongId:songId], @"L1 应该已清空");
    
    // 验证文件内容
    NSURL *cacheURL = [cacheManager cachedURLForSongId:songId];
    NSData *cachedData = [NSData dataWithContentsOfURL:cacheURL];
    NSString *cachedContent = [[NSString alloc] initWithData:cachedData encoding:NSUTF8StringEncoding];
    NSAssert([cachedContent isEqualToString:@"MusicPart1_MusicPart2_MusicPart3"], @"缓存内容应该正确");
    
    NSLog(@"%@ 切歌缓存流转测试通过", kTestPrefix);
    
    // 清理
    [cacheManager deleteAllCacheForSongId:songId];
}

#pragma mark - 测试 4: 缓存统计信息

+ (void)testPlayerCacheStatistics {
    XCAudioCacheManager *cacheManager = [XCAudioCacheManager sharedInstance];
    XCMusicPlayerModel *player = [XCMusicPlayerModel sharedInstance];
    
    // 清理
    [cacheManager clearAllCache];
    
    // 创建一些测试数据
    NSString *songId1 = @"phase8_stats_song1";
    NSString *songId2 = @"phase8_stats_song2";
    
    // L1 缓存
    [cacheManager storeSegment:[@"test" dataUsingEncoding:NSUTF8StringEncoding]
                     forSongId:songId1
                  segmentIndex:0];
    
    // L3 缓存
    NSData *songData = [@"Complete song" dataUsingEncoding:NSUTF8StringEncoding];
    NSString *cachePath = [[XCAudioCachePathUtils sharedInstance] cacheFilePathForSongId:songId2];
    [songData writeToFile:cachePath atomically:YES];
    XCAudioSongCacheInfo *info = [[XCAudioSongCacheInfo alloc] initWithSongId:songId2 totalSize:songData.length];
    [[XCCacheIndexManager sharedInstance] addSongCacheInfo:info];
    
    // 获取统计
    NSDictionary *stats = [cacheManager cacheStatistics];
    NSLog(@"%@ 缓存统计: %@", kTestPrefix, stats);
    
    // 验证统计信息存在
    NSAssert(stats[@"L1_Memory"] != nil, @"应该有 L1 统计");
    NSAssert(stats[@"L2_Temp"] != nil, @"应该有 L2 统计");
    NSAssert(stats[@"L3_Complete"] != nil, @"应该有 L3 统计");
    NSAssert(stats[@"Total"] != nil, @"应该有总计");
    
    // 验证 L1 大小不为 0（因为我们添加了分段）
    NSInteger l1Size = [stats[@"L1_Memory"][@"size"] integerValue];
    NSAssert(l1Size > 0, @"L1 大小应该大于 0");
    
    NSLog(@"%@ 缓存统计测试通过", kTestPrefix);
    
    // 清理
    [cacheManager clearAllCache];
}

#pragma mark - 测试 5: 完整播放流程

+ (void)testCompletePlaybackFlow {
    XCAudioCacheManager *cacheManager = [XCAudioCacheManager sharedInstance];
    XCMusicPlayerModel *player = [XCMusicPlayerModel sharedInstance];
    
    NSString *songId = @"phase8_complete_flow";
    
    // 清理
    [cacheManager deleteAllCacheForSongId:songId];
    
    // 验证初始状态
    XCAudioFileCacheState state = [cacheManager cacheStateForSongId:songId];
    NSAssert(state == XCAudioFileCacheStateNone, @"初始状态应该是 None");
    
    // 模拟播放中的分段缓存（L1）
    NSData *seg0 = [@"Segment0Data" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *seg1 = [@"Segment1Data" dataUsingEncoding:NSUTF8StringEncoding];
    [cacheManager storeSegment:seg0 forSongId:songId segmentIndex:0];
    [cacheManager storeSegment:seg1 forSongId:songId segmentIndex:1];
    
    state = [cacheManager cacheStateForSongId:songId];
    NSAssert(state == XCAudioFileCacheStateInMemory, @"应该有 L1 缓存");
    
    // 设置优先歌曲
    [cacheManager setCurrentPrioritySong:songId];
    NSAssert([cacheManager.currentPrioritySongId isEqualToString:songId], @"优先歌曲应该设置正确");
    
    // 模拟切歌，保存到 L2/L3
    NSInteger expectedSize = seg0.length + seg1.length;
    [cacheManager saveAndFinalizeSong:songId expectedSize:expectedSize];
    
    // 验证最终状态
    state = [cacheManager cacheStateForSongId:songId];
    NSAssert(state == XCAudioFileCacheStateComplete, @"最终应该是 L3 完整缓存");
    
    // 验证可以通过 cachedURLForSongId 获取
    NSURL *playURL = [cacheManager cachedURLForSongId:songId];
    NSAssert(playURL != nil, @"应该能获取播放 URL");
    
    NSLog(@"%@ 完整播放流程测试通过", kTestPrefix);
    
    // 清理
    [cacheManager deleteAllCacheForSongId:songId];
}

@end
