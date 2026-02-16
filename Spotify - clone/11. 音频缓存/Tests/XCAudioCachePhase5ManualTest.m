//
//  XCAudioCachePhase5ManualTest.m
//  Spotify - clone
//
//  Phase 5 手动测试示例代码
//  可单独调用每个测试方法
//

#import <Foundation/Foundation.h>
#import "../L2/XCTempCacheManager.h"
#import "../L3/XCAudioSongCacheInfo.h"
#import "../L3/XCCacheIndexManager.h"
#import "../L3/XCPersistentCacheManager.h"

#pragma mark - 手动测试函数

/// 测试 1: 基础写入和追加
static void testL2BasicWrite() {
    NSLog(@"\n=== 测试1: L2 基础写入和追加 ===");
    
    XCTempCacheManager *manager = [XCTempCacheManager sharedInstance];
    NSString *songId = @"l2_test_song_001";
    
    // 清理之前的测试数据
    [manager deleteTempFileForSongId:songId];
    
    // 第一次写入
    NSString *part1 = @"First part of song data. ";
    BOOL success1 = [manager writeTempSongData:[part1 dataUsingEncoding:NSUTF8StringEncoding] forSongId:songId];
    NSLog(@"第一次写入: %@", success1 ? @"✅ 成功" : @"❌ 失败");
    
    // 第二次追加
    NSString *part2 = @"Second part appended.";
    BOOL success2 = [manager writeTempSongData:[part2 dataUsingEncoding:NSUTF8StringEncoding] forSongId:songId];
    NSLog(@"第二次追加: %@", success2 ? @"✅ 成功" : @"❌ 失败");
    
    // 验证文件大小
    NSInteger size = [manager tempFileSizeForSongId:songId];
    NSInteger expectedSize = part1.length + part2.length;
    NSLog(@"文件大小: %ld bytes (期望: %ld) %@", (long)size, (long)expectedSize,
          size == expectedSize ? @"✅" : @"❌");
    
    // 验证文件存在
    BOOL exists = [manager hasTempFileForSongId:songId];
    NSLog(@"文件存在: %@", exists ? @"✅ 是" : @"❌ 否");
    
    // 清理
    [manager deleteTempFileForSongId:songId];
}

/// 测试 2: 完整性验证
static void testL2CompleteCheck() {
    NSLog(@"\n=== 测试2: L2 完整性验证 ===");
    
    XCTempCacheManager *manager = [XCTempCacheManager sharedInstance];
    NSString *songId = @"l2_test_song_002";
    
    // 清理
    [manager deleteTempFileForSongId:songId];
    
    // 写入 1000 字节数据
    NSMutableData *data = [NSMutableData dataWithLength:1000];
    [manager writeTempSongData:data forSongId:songId];
    
    // 验证完整性
    BOOL isComplete1000 = [manager isTempFileComplete:songId expectedSize:1000];
    BOOL isComplete500 = [manager isTempFileComplete:songId expectedSize:500];
    BOOL isComplete2000 = [manager isTempFileComplete:songId expectedSize:2000];
    
    NSLog(@"期望 1000 bytes: %@ (应该是 ✅)", isComplete1000 ? @"✅ 完整" : @"❌ 不完整");
    NSLog(@"期望 500 bytes:  %@ (应该是 ❌)", isComplete500 ? @"✅ 完整" : @"❌ 不完整");
    NSLog(@"期望 2000 bytes: %@ (应该是 ❌)", isComplete2000 ? @"✅ 完整" : @"❌ 不完整");
    
    // 清理
    [manager deleteTempFileForSongId:songId];
}

/// 测试 3: L2 → L3 流转
static void testL2ToL3Flow() {
    NSLog(@"\n=== 测试3: L2 → L3 流转 ===");
    
    XCTempCacheManager *tempManager = [XCTempCacheManager sharedInstance];
    XCPersistentCacheManager *l3Manager = [XCPersistentCacheManager sharedInstance];
    XCCacheIndexManager *indexManager = [XCCacheIndexManager sharedInstance];
    
    NSString *songId = @"l2_test_song_003";
    
    // 清理
    [tempManager deleteTempFileForSongId:songId];
    [l3Manager deleteCacheForSongId:songId];
    
    // 创建 L2 临时文件
    NSData *data = [@"Complete song data ready for L3" dataUsingEncoding:NSUTF8StringEncoding];
    [tempManager writeTempSongData:data forSongId:songId];
    
    NSLog(@"L2 文件存在: %@", [tempManager hasTempFileForSongId:songId] ? @"✅ 是" : @"❌ 否");
    NSLog(@"L3 缓存存在: %@", [l3Manager hasCompleteCacheForSongId:songId] ? @"✅ 是" : @"❌ 否");
    
    // 移动到 L3
    BOOL moved = [tempManager moveToPersistentCache:songId];
    NSLog(@"移动到 L3: %@", moved ? @"✅ 成功" : @"❌ 失败");
    
    // 验证状态
    NSLog(@"L2 文件存在: %@", [tempManager hasTempFileForSongId:songId] ? @"✅ 是 (异常)" : @"❌ 否 (正确)");
    NSLog(@"L3 缓存存在: %@", [l3Manager hasCompleteCacheForSongId:songId] ? @"✅ 是 (正确)" : @"❌ 否 (异常)");
    
    // 验证索引
    XCAudioSongCacheInfo *info = [indexManager getSongCacheInfo:songId];
    NSLog(@"索引记录: %@", info ? @"✅ 存在" : @"❌ 不存在");
    if (info) {
        NSLog(@"  - SongId: %@", info.songId);
        NSLog(@"  - TotalSize: %ld bytes", (long)info.totalSize);
        NSLog(@"  - PlayCount: %ld", (long)info.playCount);
    }
    
    // 清理
    [l3Manager deleteCacheForSongId:songId];
}

/// 测试 4: 验证后移动（不完整不移动）
static void testL2ConfirmAndMove() {
    NSLog(@"\n=== 测试4: 验证后移动（完整性检查） ===");
    
    XCTempCacheManager *tempManager = [XCTempCacheManager sharedInstance];
    XCPersistentCacheManager *l3Manager = [XCPersistentCacheManager sharedInstance];
    
    NSString *songId = @"l2_test_song_004";
    
    // 清理
    [tempManager deleteTempFileForSongId:songId];
    [l3Manager deleteCacheForSongId:songId];
    
    // 创建 500 字节的文件
    NSMutableData *data = [NSMutableData dataWithLength:500];
    [tempManager writeTempSongData:data forSongId:songId];
    
    // 尝试用错误的大小移动 - 应该失败
    NSLog(@"尝试用 1000 bytes 期望移动...");
    BOOL moved1 = [tempManager confirmCompleteAndMoveToCache:songId expectedSize:1000];
    NSLog(@"结果: %@ (应该是 ❌)", moved1 ? @"✅ 成功 (异常)" : @"❌ 失败 (正确)");
    NSLog(@"L2 文件还在: %@", [tempManager hasTempFileForSongId:songId] ? @"✅ 是 (正确)" : @"❌ 否 (异常)");
    
    // 用正确的大小移动 - 应该成功
    NSLog(@"尝试用 500 bytes 期望移动...");
    BOOL moved2 = [tempManager confirmCompleteAndMoveToCache:songId expectedSize:500];
    NSLog(@"结果: %@ (应该是 ✅)", moved2 ? @"✅ 成功 (正确)" : @"❌ 失败 (异常)");
    NSLog(@"L2 文件还在: %@", [tempManager hasTempFileForSongId:songId] ? @"✅ 是 (异常)" : @"❌ 否 (正确)");
    NSLog(@"L3 缓存存在: %@", [l3Manager hasCompleteCacheForSongId:songId] ? @"✅ 是 (正确)" : @"❌ 否 (异常)");
    
    // 清理
    [l3Manager deleteCacheForSongId:songId];
}

/// 测试 5: 过期清理
static void testL2ExpiredClean() {
    NSLog(@"\n=== 测试5: 过期文件清理 ===");
    
    XCTempCacheManager *manager = [XCTempCacheManager sharedInstance];
    
    // 创建 5 个测试文件
    for (NSInteger i = 0; i < 5; i++) {
        NSString *songId = [NSString stringWithFormat:@"l2_expire_test_%ld", (long)i];
        [manager deleteTempFileForSongId:songId]; // 先清理旧的
        [manager writeTempSongData:[@"test" dataUsingEncoding:NSUTF8StringEncoding] forSongId:songId];
    }
    
    NSInteger countBefore = [manager tempFileCount];
    NSLog(@"清理前文件数量: %ld", (long)countBefore);
    
    // 清理 0 天前的文件（清理所有）
    NSInteger cleaned = [manager cleanTempFilesOlderThanDays:0];
    NSLog(@"清理文件数量: %ld", (long)cleaned);
    
    NSInteger countAfter = [manager tempFileCount];
    NSLog(@"清理后文件数量: %ld %@", (long)countAfter, countAfter == 0 ? @"✅" : @"❌");
}

/// 测试 6: 统计信息
static void testL2Statistics() {
    NSLog(@"\n=== 测试6: 统计信息 ===");
    
    XCTempCacheManager *manager = [XCTempCacheManager sharedInstance];
    [manager clearAllTempCache];
    
    // 添加不同大小的文件
    NSString *content1 = @"Small file";
    NSString *content2 = @"Medium file with more content";
    NSString *content3 = @"Large file with much more content here";
    
    [manager writeTempSongData:[content1 dataUsingEncoding:NSUTF8StringEncoding] forSongId:@"stat_1"];
    [manager writeTempSongData:[content2 dataUsingEncoding:NSUTF8StringEncoding] forSongId:@"stat_2"];
    [manager writeTempSongData:[content3 dataUsingEncoding:NSUTF8StringEncoding] forSongId:@"stat_3"];
    
    NSInteger count = [manager tempFileCount];
    NSInteger totalSize = [manager totalTempCacheSize];
    NSInteger expectedSize = content1.length + content2.length + content3.length;
    
    NSLog(@"文件数量: %ld (期望: 3) %@", (long)count, count == 3 ? @"✅" : @"❌");
    NSLog(@"总大小: %ld bytes (期望: %ld) %@", (long)totalSize, (long)expectedSize,
          totalSize == expectedSize ? @"✅" : @"❌");
    
    // 清理
    [manager clearAllTempCache];
}

/// 运行所有手动测试
static void runPhase5ManualTests() {
    NSLog(@"\n\n╔══════════════════════════════════════╗");
    NSLog(@"║     Phase 5 手动测试开始            ║");
    NSLog(@"╚══════════════════════════════════════╝\n");
    
    testL2BasicWrite();
    testL2CompleteCheck();
    testL2ToL3Flow();
    testL2ConfirmAndMove();
    testL2ExpiredClean();
    testL2Statistics();
    
    NSLog(@"\n╔══════════════════════════════════════╗");
    NSLog(@"║     Phase 5 手动测试结束            ║");
    NSLog(@"╚══════════════════════════════════════╝\n");
}

#pragma mark - 使用示例

/*
// 在任意 .m 文件中调用：
 
#import "XCAudioCachePhase5ManualTest.m"
 
- (void)someMethod {
    // 运行单个测试
    testL2BasicWrite();
    
    // 或运行所有手动测试
    runPhase5ManualTests();
}
*/
