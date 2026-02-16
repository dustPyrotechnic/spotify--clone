//
//  XCAudioCachePhase5Test.m
//  Spotify - clone
//

#import "XCAudioCachePhase5Test.h"
#import "../L2/XCTempCacheManager.h"
#import "../L3/XCAudioSongCacheInfo.h"
#import "../L3/XCCacheIndexManager.h"
#import "../L3/XCPersistentCacheManager.h"
#import "../XCAudioCachePathUtils.h"

@implementation XCAudioCachePhase5Test

+ (void)runAllTests {
    NSLog(@"[Phase5Test] ========== Phase 5 Test Start ==========");
    
    // 先清理环境
    [[XCTempCacheManager sharedInstance] clearAllTempCache];
    [[XCPersistentCacheManager sharedInstance] clearAllCache];
    [[XCCacheIndexManager sharedInstance] clearAllCache];
    
    // 基础功能测试
    [self testSingleton];
    [self testWriteTempFile];
    [self testAppendWrite];
    [self testTempFileURL];
    [self testHasTempFile];
    [self testTempFileSize];
    
    // 完整性验证测试
    [self testIsTempFileComplete];
    
    // L2 → L3 流转测试
    [self testMoveToPersistentCache];
    [self testConfirmCompleteAndMove];
    
    // 删除测试
    [self testDeleteTempFile];
    
    // 过期清理测试
    [self testCleanExpiredFiles];
    
    // 统计测试
    [self testStatistics];
    
    // 完整流程测试
    [self testL1ToL2ToL3Flow];
    
    // 测试结束清理
    [[XCTempCacheManager sharedInstance] clearAllTempCache];
    [[XCPersistentCacheManager sharedInstance] clearAllCache];
    [[XCCacheIndexManager sharedInstance] clearAllCache];
    
    NSLog(@"[Phase5Test] ========== Phase 5 Test End ==========");
}

#pragma mark - 基础功能测试

+ (void)testSingleton {
    NSLog(@"[Phase5Test] Testing singleton...");
    
    XCTempCacheManager *manager1 = [XCTempCacheManager sharedInstance];
    XCTempCacheManager *manager2 = [XCTempCacheManager sharedInstance];
    
    NSAssert(manager1 == manager2, @"Singleton should return same instance");
    
    NSLog(@"[Phase5Test] Singleton OK");
}

+ (void)testWriteTempFile {
    NSLog(@"[Phase5Test] Testing writeTempFile...");
    
    XCTempCacheManager *manager = [XCTempCacheManager sharedInstance];
    NSString *songId = @"test_write_temp";
    NSString *content = @"Part 1 data ";
    NSData *data = [content dataUsingEncoding:NSUTF8StringEncoding];
    
    // 写入
    BOOL success = [manager writeTempSongData:data forSongId:songId];
    NSAssert(success == YES, @"Write should succeed");
    
    // 验证文件存在
    NSAssert([manager hasTempFileForSongId:songId] == YES, @"Temp file should exist after write");
    
    // 验证文件大小
    NSInteger fileSize = [manager tempFileSizeForSongId:songId];
    NSAssert(fileSize == data.length, @"File size should match data length");
    
    // 清理
    [manager deleteTempFileForSongId:songId];
    
    NSLog(@"[Phase5Test] writeTempFile OK");
}

+ (void)testAppendWrite {
    NSLog(@"[Phase5Test] Testing append write...");
    
    XCTempCacheManager *manager = [XCTempCacheManager sharedInstance];
    NSString *songId = @"test_append";
    
    // 第一次写入
    NSString *part1 = @"Part 1 data ";
    NSData *data1 = [part1 dataUsingEncoding:NSUTF8StringEncoding];
    BOOL success1 = [manager writeTempSongData:data1 forSongId:songId];
    NSAssert(success1 == YES, @"First write should succeed");
    
    // 第二次写入（追加）
    NSString *part2 = @"Part 2 data";
    NSData *data2 = [part2 dataUsingEncoding:NSUTF8StringEncoding];
    BOOL success2 = [manager writeTempSongData:data2 forSongId:songId];
    NSAssert(success2 == YES, @"Second write should succeed");
    
    // 验证文件大小
    NSInteger fileSize = [manager tempFileSizeForSongId:songId];
    NSInteger expectedSize = data1.length + data2.length;
    NSAssert(fileSize == expectedSize, @"File size should be sum of both parts");
    
    // 验证文件内容
    NSString *filePath = [[XCAudioCachePathUtils sharedInstance] tempFilePathForSongId:songId];
    NSData *fileData = [NSData dataWithContentsOfFile:filePath];
    NSString *content = [[NSString alloc] initWithData:fileData encoding:NSUTF8StringEncoding];
    NSAssert([content isEqualToString:@"Part 1 data Part 2 data"], @"Content should be concatenated");
    
    // 清理
    [manager deleteTempFileForSongId:songId];
    
    NSLog(@"[Phase5Test] append write OK");
}

+ (void)testTempFileURL {
    NSLog(@"[Phase5Test] Testing tempFileURL...");
    
    XCTempCacheManager *manager = [XCTempCacheManager sharedInstance];
    NSString *songId = @"test_url";
    
    // 写入前应该返回 nil
    NSURL *urlBefore = [manager tempFileURLForSongId:songId];
    NSAssert(urlBefore == nil, @"URL should be nil before write");
    
    // 写入
    [manager writeTempSongData:[@"test" dataUsingEncoding:NSUTF8StringEncoding] forSongId:songId];
    
    // 写入后应该返回有效 URL
    NSURL *urlAfter = [manager tempFileURLForSongId:songId];
    NSAssert(urlAfter != nil, @"URL should not be nil after write");
    NSAssert([urlAfter isFileURL], @"Should be a file URL");
    NSAssert([urlAfter.absoluteString containsString:@".mp3.tmp"], @"URL should contain .mp3.tmp");
    
    // 清理
    [manager deleteTempFileForSongId:songId];
    
    NSLog(@"[Phase5Test] tempFileURL OK");
}

+ (void)testHasTempFile {
    NSLog(@"[Phase5Test] Testing hasTempFile...");
    
    XCTempCacheManager *manager = [XCTempCacheManager sharedInstance];
    NSString *songId = @"test_has_temp";
    
    // 不存在时
    BOOL existsBefore = [manager hasTempFileForSongId:songId];
    NSAssert(existsBefore == NO, @"Should not have temp file before write");
    
    // 写入
    [manager writeTempSongData:[@"data" dataUsingEncoding:NSUTF8StringEncoding] forSongId:songId];
    
    // 存在时
    BOOL existsAfter = [manager hasTempFileForSongId:songId];
    NSAssert(existsAfter == YES, @"Should have temp file after write");
    
    // 删除后
    [manager deleteTempFileForSongId:songId];
    BOOL existsAfterDelete = [manager hasTempFileForSongId:songId];
    NSAssert(existsAfterDelete == NO, @"Should not have temp file after delete");
    
    NSLog(@"[Phase5Test] hasTempFile OK");
}

+ (void)testTempFileSize {
    NSLog(@"[Phase5Test] Testing tempFileSize...");
    
    XCTempCacheManager *manager = [XCTempCacheManager sharedInstance];
    NSString *songId = @"test_size";
    
    // 不存在时返回 0
    NSInteger sizeBefore = [manager tempFileSizeForSongId:songId];
    NSAssert(sizeBefore == 0, @"Size should be 0 for non-existent file");
    
    // 写入 100 字节
    NSMutableData *data = [NSMutableData dataWithLength:100];
    [manager writeTempSongData:data forSongId:songId];
    
    // 验证大小
    NSInteger sizeAfter = [manager tempFileSizeForSongId:songId];
    NSAssert(sizeAfter == 100, @"Size should be 100");
    
    // 追加 50 字节
    NSMutableData *moreData = [NSMutableData dataWithLength:50];
    [manager writeTempSongData:moreData forSongId:songId];
    
    NSInteger sizeFinal = [manager tempFileSizeForSongId:songId];
    NSAssert(sizeFinal == 150, @"Size should be 150 after append");
    
    // 清理
    [manager deleteTempFileForSongId:songId];
    
    NSLog(@"[Phase5Test] tempFileSize OK");
}

#pragma mark - 完整性验证测试

+ (void)testIsTempFileComplete {
    NSLog(@"[Phase5Test] Testing isTempFileComplete...");
    
    XCTempCacheManager *manager = [XCTempCacheManager sharedInstance];
    NSString *songId = @"test_complete_check";
    
    // 写入 1000 字节的数据
    NSMutableData *data = [NSMutableData dataWithLength:1000];
    [manager writeTempSongData:data forSongId:songId];
    
    // 验证完整性 - 正确大小
    BOOL isComplete = [manager isTempFileComplete:songId expectedSize:1000];
    NSAssert(isComplete == YES, @"Should be complete when size matches");
    
    // 验证完整性 - 错误大小
    BOOL isNotComplete = [manager isTempFileComplete:songId expectedSize:2000];
    NSAssert(isNotComplete == NO, @"Should not be complete when size doesn't match");
    
    // 验证完整性 - 小于实际大小
    BOOL isNotComplete2 = [manager isTempFileComplete:songId expectedSize:500];
    NSAssert(isNotComplete2 == NO, @"Should not be complete when expected size is smaller");
    
    // 清理
    [manager deleteTempFileForSongId:songId];
    
    NSLog(@"[Phase5Test] isTempFileComplete OK");
}

#pragma mark - L2 → L3 流转测试

+ (void)testMoveToPersistentCache {
    NSLog(@"[Phase5Test] Testing moveToPersistentCache...");
    
    XCTempCacheManager *tempManager = [XCTempCacheManager sharedInstance];
    XCPersistentCacheManager *persistentManager = [XCPersistentCacheManager sharedInstance];
    XCCacheIndexManager *indexManager = [XCCacheIndexManager sharedInstance];
    
    NSString *songId = @"test_move_to_l3";
    NSString *tempPath = [[XCAudioCachePathUtils sharedInstance] tempFilePathForSongId:songId];
    NSString *cachePath = [[XCAudioCachePathUtils sharedInstance] cacheFilePathForSongId:songId];
    
    // 创建临时文件
    NSData *data = [@"Complete song data for L3" dataUsingEncoding:NSUTF8StringEncoding];
    [tempManager writeTempSongData:data forSongId:songId];
    
    NSAssert([tempManager hasTempFileForSongId:songId] == YES, @"Temp file should exist");
    
    // 移动到 L3
    BOOL moved = [tempManager moveToPersistentCache:songId];
    NSAssert(moved == YES, @"Move should succeed");
    
    // 验证临时文件已删除
    NSFileManager *fm = [NSFileManager defaultManager];
    NSAssert([fm fileExistsAtPath:tempPath] == NO, @"Temp file should be deleted");
    
    // 验证 L3 文件存在
    NSAssert([fm fileExistsAtPath:cachePath] == YES, @"Cache file should exist");
    NSAssert([persistentManager hasCompleteCacheForSongId:songId] == YES, @"L3 should have cache");
    
    // 验证索引已更新
    XCAudioSongCacheInfo *info = [indexManager getSongCacheInfo:songId];
    NSAssert(info != nil, @"Index should be updated");
    NSAssert([info.songId isEqualToString:songId], @"SongId should match");
    NSAssert(info.totalSize == data.length, @"Total size should match");
    
    // 清理
    [persistentManager deleteCacheForSongId:songId];
    
    NSLog(@"[Phase5Test] moveToPersistentCache OK");
}

+ (void)testConfirmCompleteAndMove {
    NSLog(@"[Phase5Test] Testing confirmCompleteAndMove...");
    
    XCTempCacheManager *tempManager = [XCTempCacheManager sharedInstance];
    XCPersistentCacheManager *persistentManager = [XCPersistentCacheManager sharedInstance];
    
    NSString *songId = @"test_confirm_move";
    
    // 创建 1000 字节的临时文件
    NSMutableData *data = [NSMutableData dataWithLength:1000];
    [tempManager writeTempSongData:data forSongId:songId];
    
    // 尝试用错误的大小移动 - 应该失败
    BOOL movedWithWrongSize = [tempManager confirmCompleteAndMoveToCache:songId expectedSize:2000];
    NSAssert(movedWithWrongSize == NO, @"Should not move with wrong size");
    
    // 验证临时文件还在
    NSAssert([tempManager hasTempFileForSongId:songId] == YES, @"Temp file should still exist");
    NSAssert([persistentManager hasCompleteCacheForSongId:songId] == NO, @"L3 should not have cache");
    
    // 用正确的大小移动 - 应该成功
    BOOL movedWithRightSize = [tempManager confirmCompleteAndMoveToCache:songId expectedSize:1000];
    NSAssert(movedWithRightSize == YES, @"Should move with correct size");
    
    // 验证已移动到 L3
    NSAssert([tempManager hasTempFileForSongId:songId] == NO, @"Temp file should be deleted");
    NSAssert([persistentManager hasCompleteCacheForSongId:songId] == YES, @"L3 should have cache");
    
    // 清理
    [persistentManager deleteCacheForSongId:songId];
    
    NSLog(@"[Phase5Test] confirmCompleteAndMove OK");
}

#pragma mark - 删除测试

+ (void)testDeleteTempFile {
    NSLog(@"[Phase5Test] Testing deleteTempFile...");
    
    XCTempCacheManager *manager = [XCTempCacheManager sharedInstance];
    
    // 创建多个临时文件
    for (NSInteger i = 0; i < 3; i++) {
        NSString *songId = [NSString stringWithFormat:@"delete_test_%ld", (long)i];
        [manager writeTempSongData:[@"data" dataUsingEncoding:NSUTF8StringEncoding] forSongId:songId];
    }
    
    // 验证都存在
    NSAssert([manager tempFileCount] == 3, @"Should have 3 temp files");
    
    // 删除其中一个
    [manager deleteTempFileForSongId:@"delete_test_1"];
    
    // 验证删除成功
    NSAssert([manager hasTempFileForSongId:@"delete_test_1"] == NO, @"Deleted file should not exist");
    NSAssert([manager tempFileCount] == 2, @"Should have 2 temp files after delete");
    
    // 验证其他文件还在
    NSAssert([manager hasTempFileForSongId:@"delete_test_0"] == YES, @"Other files should exist");
    NSAssert([manager hasTempFileForSongId:@"delete_test_2"] == YES, @"Other files should exist");
    
    // 清理
    [manager clearAllTempCache];
    
    NSLog(@"[Phase5Test] deleteTempFile OK");
}

#pragma mark - 过期清理测试

+ (void)testCleanExpiredFiles {
    NSLog(@"[Phase5Test] Testing cleanExpiredFiles...");
    
    XCTempCacheManager *manager = [XCTempCacheManager sharedInstance];
    
    // 创建临时文件
    for (NSInteger i = 0; i < 3; i++) {
        NSString *songId = [NSString stringWithFormat:@"expire_test_%ld", (long)i];
        [manager writeTempSongData:[@"data" dataUsingEncoding:NSUTF8StringEncoding] forSongId:songId];
    }
    
    NSInteger countBefore = [manager tempFileCount];
    NSAssert(countBefore == 3, @"Should have 3 temp files");
    
    // 清理 0 天前的文件（应该清理所有文件）
    NSInteger cleaned = [manager cleanTempFilesOlderThanDays:0];
    NSAssert(cleaned == 3, @"Should clean all 3 files");
    
    NSInteger countAfter = [manager tempFileCount];
    NSAssert(countAfter == 0, @"Should have 0 temp files after clean");
    
    NSLog(@"[Phase5Test] cleanExpiredFiles OK");
}

#pragma mark - 统计测试

+ (void)testStatistics {
    NSLog(@"[Phase5Test] Testing statistics...");
    
    XCTempCacheManager *manager = [XCTempCacheManager sharedInstance];
    [manager clearAllTempCache];
    
    // 初始状态
    NSInteger initialCount = [manager tempFileCount];
    NSInteger initialSize = [manager totalTempCacheSize];
    NSAssert(initialCount == 0, @"Initial count should be 0");
    NSAssert(initialSize == 0, @"Initial size should be 0");
    
    // 添加不同大小的文件
    NSString *data1 = @"Song data 1";
    NSString *data2 = @"Song data 2 with more content";
    [manager writeTempSongData:[data1 dataUsingEncoding:NSUTF8StringEncoding] forSongId:@"stat_song_1"];
    [manager writeTempSongData:[data2 dataUsingEncoding:NSUTF8StringEncoding] forSongId:@"stat_song_2"];
    
    // 验证统计
    NSInteger count = [manager tempFileCount];
    NSInteger size = [manager totalTempCacheSize];
    NSAssert(count == 2, @"Should have 2 temp files");
    NSAssert(size == data1.length + data2.length, @"Total size should match sum");
    
    // 清理
    [manager clearAllTempCache];
    
    NSLog(@"[Phase5Test] statistics OK");
}

#pragma mark - 完整流程测试

+ (void)testL1ToL2ToL3Flow {
    NSLog(@"[Phase5Test] Testing L1 → L2 → L3 complete flow...");
    
    // 模拟 L1 分段合并到 L2，然后验证完整后移动到 L3
    XCTempCacheManager *tempManager = [XCTempCacheManager sharedInstance];
    XCPersistentCacheManager *persistentManager = [XCPersistentCacheManager sharedInstance];
    XCCacheIndexManager *indexManager = [XCCacheIndexManager sharedInstance];
    
    NSString *songId = @"complete_flow_test";
    NSInteger expectedTotalSize = 0;
    
    // 步骤 1: 模拟分段下载并追加到 L2（实际场景是从 L1 合并）
    NSLog(@"[Phase5Test] Step 1: Writing segments to L2...");
    for (NSInteger i = 0; i < 5; i++) {
        NSString *content = [NSString stringWithFormat:@"Segment%ld-", (long)i];
        NSData *segmentData = [content dataUsingEncoding:NSUTF8StringEncoding];
        [tempManager writeTempSongData:segmentData forSongId:songId];
        expectedTotalSize += segmentData.length;
    }
    
    // 验证 L2 状态
    NSInteger l2Size = [tempManager tempFileSizeForSongId:songId];
    NSAssert(l2Size == expectedTotalSize, @"L2 file size should match expected");
    NSAssert([tempManager hasTempFileForSongId:songId] == YES, @"L2 should have temp file");
    
    // 步骤 2: 模拟切歌时验证完整性并移动到 L3
    NSLog(@"[Phase5Test] Step 2: Confirming complete and moving to L3...");
    BOOL moved = [tempManager confirmCompleteAndMoveToCache:songId expectedSize:expectedTotalSize];
    NSAssert(moved == YES, @"Should move successfully when complete");
    
    // 步骤 3: 验证最终状态
    NSLog(@"[Phase5Test] Step 3: Verifying final state...");
    
    // L2 已清空
    NSAssert([tempManager hasTempFileForSongId:songId] == NO, @"L2 should be empty");
    
    // L3 存在
    NSAssert([persistentManager hasCompleteCacheForSongId:songId] == YES, @"L3 should have complete cache");
    
    // 索引已更新
    XCAudioSongCacheInfo *info = [indexManager getSongCacheInfo:songId];
    NSAssert(info != nil, @"Index should have the record");
    NSAssert(info.totalSize == expectedTotalSize, @"Index size should match");
    
    // 验证文件内容
    NSData *l3Data = [NSData dataWithContentsOfURL:[persistentManager cachedURLForSongId:songId]];
    NSString *l3Content = [[NSString alloc] initWithData:l3Data encoding:NSUTF8StringEncoding];
    NSAssert([l3Content isEqualToString:@"Segment0-Segment1-Segment2-Segment3-Segment4-"], 
             @"L3 content should be correct");
    
    // 清理
    [persistentManager deleteCacheForSongId:songId];
    
    NSLog(@"[Phase5Test] L1 → L2 → L3 flow OK");
}

@end
