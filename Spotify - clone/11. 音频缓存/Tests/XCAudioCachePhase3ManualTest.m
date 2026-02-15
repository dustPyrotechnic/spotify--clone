//
//  XCAudioCachePhase3ManualTest.m
//  Spotify - clone
//
//  Phase 3 手动测试示例代码
//  可单独调用每个测试方法
//

#import <Foundation/Foundation.h>
#import "XCMemoryCacheManager.h"
#import "XCAudioSegmentInfo.h"

#pragma mark - 手动测试函数（可在任意地方调用）

/// 测试 1: 基础存储读取
static void testBasicStoreAndRetrieve() {
    NSLog(@"=== 测试1: 基础存储读取 ===");
    
    XCMemoryCacheManager *manager = [XCMemoryCacheManager sharedInstance];
    [manager clearAllCache];
    
    NSString *songId = @"song_001";
    NSData *data = [@"Hello World" dataUsingEncoding:NSUTF8StringEncoding];
    
    // 存储
    [manager storeSegmentData:data forSongId:songId segmentIndex:0];
    
    // 读取
    NSData *retrieved = [manager segmentDataForSongId:songId segmentIndex:0];
    NSString *result = [[NSString alloc] initWithData:retrieved encoding:NSUTF8StringEncoding];
    
    NSLog(@"原始: Hello World");
    NSLog(@"读取: %@", result);
    NSLog(@"结果: %@", [result isEqualToString:@"Hello World"] ? @"✅ 通过" : @"❌ 失败");
}

/// 测试 2: 模拟播放时的分段存储
static void testSimulatePlayback() {
    NSLog(@"\n=== 测试2: 模拟播放时分段存储 ===");
    
    XCMemoryCacheManager *manager = [XCMemoryCacheManager sharedInstance];
    [manager clearAllCache];
    
    NSString *songId = @"playing_song_123";
    [manager setCurrentSongPriority:songId];
    
    // 模拟下载并存储前 5 个分段（约 2.5MB）
    for (NSInteger i = 0; i < 5; i++) {
        // 创建 512KB 的模拟数据
        NSMutableData *segmentData = [NSMutableData dataWithLength:512 * 1024];
        [manager storeSegmentData:segmentData forSongId:songId segmentIndex:i];
        NSLog(@"存储分段 %ld (512KB)", (long)i);
    }
    
    // 验证存储
    NSInteger count = [manager segmentCountForSongId:songId];
    NSLog(@"已存储分段数: %ld", (long)count);
    NSLog(@"结果: %@", count == 5 ? @"✅ 通过" : @"❌ 失败");
}

/// 测试 3: 切歌时的 L1→L2 准备
static void testSongSwitchPreparation() {
    NSLog(@"\n=== 测试3: 切歌准备（获取所有分段） ===");
    
    XCMemoryCacheManager *manager = [XCMemoryCacheManager sharedInstance];
    [manager clearAllCache];
    
    NSString *currentSong = @"current_song";
    
    // 存储分段（模拟乱序下载）
    [manager storeSegmentData:[@"data3" dataUsingEncoding:NSUTF8StringEncoding]
                   forSongId:currentSong segmentIndex:3];
    [manager storeSegmentData:[@"data1" dataUsingEncoding:NSUTF8StringEncoding]
                   forSongId:currentSong segmentIndex:1];
    [manager storeSegmentData:[@"data0" dataUsingEncoding:NSUTF8StringEncoding]
                   forSongId:currentSong segmentIndex:0];
    [manager storeSegmentData:[@"data2" dataUsingEncoding:NSUTF8StringEncoding]
                   forSongId:currentSong segmentIndex:2];
    
    // 获取所有分段（用于合并到 L2）
    NSArray<XCAudioSegmentInfo *> *segments = [manager getAllSegmentsForSongId:currentSong];
    
    NSLog(@"分段数量: %lu", (unsigned long)segments.count);
    NSLog(@"分段顺序:");
    for (XCAudioSegmentInfo *info in segments) {
        NSLog(@"  - index=%ld, offset=%lld, size=%ld", 
              (long)info.index, info.offset, (long)info.size);
    }
    
    // 验证顺序正确
    BOOL orderCorrect = YES;
    for (NSInteger i = 0; i < segments.count; i++) {
        if (segments[i].index != i) {
            orderCorrect = NO;
            break;
        }
    }
    NSLog(@"结果: %@", orderCorrect ? @"✅ 通过（顺序正确）" : @"❌ 失败（顺序错误）");
}

/// 测试 4: 内存警告模拟
static void testMemoryWarning() {
    NSLog(@"\n=== 测试4: 内存警告处理 ===");
    
    XCMemoryCacheManager *manager = [XCMemoryCacheManager sharedInstance];
    [manager clearAllCache];
    
    NSString *prioritySong = @"priority_song";
    NSString *otherSong1 = @"other_song_1";
    NSString *otherSong2 = @"other_song_2";
    
    // 设置优先歌曲
    [manager setCurrentSongPriority:prioritySong];
    
    // 为所有歌曲存储分段
    for (NSString *song in @[prioritySong, otherSong1, otherSong2]) {
        for (NSInteger i = 0; i < 3; i++) {
            [manager storeSegmentData:[@"data" dataUsingEncoding:NSUTF8StringEncoding]
                           forSongId:song segmentIndex:i];
        }
    }
    
    NSLog(@"清理前:");
    NSLog(@"  优先歌曲分段: %ld", (long)[manager segmentCountForSongId:prioritySong]);
    NSLog(@"  其他歌曲1分段: %ld", (long)[manager segmentCountForSongId:otherSong1]);
    NSLog(@"  其他歌曲2分段: %ld", (long)[manager segmentCountForSongId:otherSong2]);
    
    // 模拟内存警告
    [manager trimCache];
    
    NSLog(@"清理后:");
    NSLog(@"  优先歌曲分段: %ld %@", (long)[manager segmentCountForSongId:prioritySong],
          [manager segmentCountForSongId:prioritySong] == 3 ? @"✅" : @"❌");
    NSLog(@"  其他歌曲1分段: %ld %@", (long)[manager segmentCountForSongId:otherSong1],
          [manager segmentCountForSongId:otherSong1] == 0 ? @"✅" : @"❌");
    NSLog(@"  其他歌曲2分段: %ld %@", (long)[manager segmentCountForSongId:otherSong2],
          [manager segmentCountForSongId:otherSong2] == 0 ? @"✅" : @"❌");
}

/// 运行所有手动测试
static void runPhase3ManualTests() {
    NSLog(@"\n\n╔══════════════════════════════════════╗");
    NSLog(@"║     Phase 3 手动测试开始            ║");
    NSLog(@"╚══════════════════════════════════════╝\n");
    
    testBasicStoreAndRetrieve();
    testSimulatePlayback();
    testSongSwitchPreparation();
    testMemoryWarning();
    
    NSLog(@"\n╔══════════════════════════════════════╗");
    NSLog(@"║     Phase 3 手动测试结束            ║");
    NSLog(@"╚══════════════════════════════════════╝\n");
}

#pragma mark - 使用示例

/*
// 在任意 .m 文件中调用：
 
#import "XCAudioCachePhase3ManualTest.m"
 
- (void)someMethod {
    // 运行单个测试
    testBasicStoreAndRetrieve();
    
    // 或运行所有手动测试
    runPhase3ManualTests();
}
*/
