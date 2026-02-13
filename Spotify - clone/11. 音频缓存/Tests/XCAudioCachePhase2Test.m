//
//  XCAudioCachePhase2Test.m
//  Spotify - clone
//

#import "XCAudioCachePhase2Test.h"
#import "../L3/XCCacheIndexManager.h"
#import "../L3/XCAudioSongCacheInfo.h"
#import "../XCAudioCachePathUtils.h"

@implementation XCAudioCachePhase2Test

+ (void)runAllTests {
    NSLog(@"[Phase2Test] ========== Phase 2 Test Start ==========");
    
    // 先清理所有测试数据
    [[XCCacheIndexManager sharedInstance] clearAllCache];
    
    [self testAddAndQuery];
    [self testUpdatePlayTime];
    [self testRemove];
    [self testStatistics];
    [self testLRUClean];
    
    // 测试结束清理
    [[XCCacheIndexManager sharedInstance] clearAllCache];
    
    NSLog(@"[Phase2Test] ========== Phase 2 Test End ==========");
}

+ (void)testAddAndQuery {
    NSLog(@"[Phase2Test] Testing add and query...");
    
    XCCacheIndexManager *manager = [XCCacheIndexManager sharedInstance];
    
    XCAudioSongCacheInfo *info = [[XCAudioSongCacheInfo alloc] initWithSongId:@"test_song_1" totalSize:5242880];
    [manager addSongCacheInfo:info];
    
    XCAudioSongCacheInfo *retrieved = [manager getSongCacheInfo:@"test_song_1"];
    NSAssert(retrieved != nil, @"Should retrieve added song");
    NSAssert([retrieved.songId isEqualToString:@"test_song_1"], @"SongId should match");
    NSAssert(retrieved.totalSize == 5242880, @"TotalSize should match");
    
    NSLog(@"[Phase2Test] Add and query OK");
}

+ (void)testUpdatePlayTime {
    NSLog(@"[Phase2Test] Testing update play time...");
    
    XCCacheIndexManager *manager = [XCCacheIndexManager sharedInstance];
    
    // 必须先重新添加 test_song_1（因为之前被 remove 了）
    [manager addSongCacheInfo:[[XCAudioSongCacheInfo alloc] initWithSongId:@"test_song_1" totalSize:5242880]];
    
    XCAudioSongCacheInfo *info = [manager getSongCacheInfo:@"test_song_1"];
    NSTimeInterval oldTime = info.lastPlayTime;
    NSInteger oldCount = info.playCount;
    
    [NSThread sleepForTimeInterval:0.1];
    [manager updatePlayTimeForSongId:@"test_song_1"];
    
    // 重新获取（因为 updatePlayTimeForSongId 会触发 save/load）
    info = [manager getSongCacheInfo:@"test_song_1"];
    NSAssert(info.lastPlayTime > oldTime, @"LastPlayTime should be updated");
    NSAssert(info.playCount == oldCount + 1, @"PlayCount should increment");
    
    NSLog(@"[Phase2Test] Update play time OK");
}

+ (void)testRemove {
    NSLog(@"[Phase2Test] Testing remove...");
    
    XCCacheIndexManager *manager = [XCCacheIndexManager sharedInstance];
    
    [manager removeSongCacheInfo:@"test_song_1"];
    XCAudioSongCacheInfo *retrieved = [manager getSongCacheInfo:@"test_song_1"];
    NSAssert(retrieved == nil, @"Should not retrieve removed song");
    
    NSLog(@"[Phase2Test] Remove OK");
}

+ (void)testStatistics {
    NSLog(@"[Phase2Test] Testing statistics...");
    
    XCCacheIndexManager *manager = [XCCacheIndexManager sharedInstance];
    
    NSInteger countBefore = [manager cachedSongCount];
    
    [manager addSongCacheInfo:[[XCAudioSongCacheInfo alloc] initWithSongId:@"stat_test_1" totalSize:1000000]];
    [manager addSongCacheInfo:[[XCAudioSongCacheInfo alloc] initWithSongId:@"stat_test_2" totalSize:2000000]];
    
    NSInteger countAfter = [manager cachedSongCount];
    NSInteger totalSize = [manager totalCacheSize];
    
    NSAssert(countAfter == countBefore + 2, @"Song count should increase by 2");
    NSAssert(totalSize >= 3000000, @"Total size should be at least 3MB");
    
    [manager removeSongCacheInfo:@"stat_test_1"];
    [manager removeSongCacheInfo:@"stat_test_2"];
    
    NSLog(@"[Phase2Test] Statistics OK");
}

+ (void)testLRUClean {
    NSLog(@"[Phase2Test] Testing LRU clean...");
    
    XCCacheIndexManager *manager = [XCCacheIndexManager sharedInstance];
    
    [manager addSongCacheInfo:[[XCAudioSongCacheInfo alloc] initWithSongId:@"lru_test_1" totalSize:1000000]];
    [manager addSongCacheInfo:[[XCAudioSongCacheInfo alloc] initWithSongId:@"lru_test_2" totalSize:1000000]];
    [manager addSongCacheInfo:[[XCAudioSongCacheInfo alloc] initWithSongId:@"lru_test_3" totalSize:1000000]];
    
    [NSThread sleepForTimeInterval:0.1];
    [manager updatePlayTimeForSongId:@"lru_test_3"];
    [NSThread sleepForTimeInterval:0.1];
    [manager updatePlayTimeForSongId:@"lru_test_2"];
    
    NSInteger countBefore = [manager cachedSongCount];
    NSInteger deleted = [manager cleanCacheToSize:2500000];
    NSInteger countAfter = [manager cachedSongCount];
    
    NSAssert(deleted > 0, @"Should delete at least 1 song");
    NSAssert(countAfter < countBefore, @"Count should decrease");
    
    XCAudioSongCacheInfo *info3 = [manager getSongCacheInfo:@"lru_test_3"];
    NSAssert(info3 != nil, @"Most recently played song should remain");
    
    [manager removeSongCacheInfo:@"lru_test_1"];
    [manager removeSongCacheInfo:@"lru_test_2"];
    [manager removeSongCacheInfo:@"lru_test_3"];
    
    NSLog(@"[Phase2Test] LRU clean OK");
}

@end
