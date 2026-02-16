//
//  XCAudioCachePhase4Test.m
//  Spotify - clone
//

#import "XCAudioCachePhase4Test.h"
#import "../L3/XCPersistentCacheManager.h"
#import "../L3/XCCacheIndexManager.h"
#import "../L3/XCAudioSongCacheInfo.h"
#import "../L1/XCMemoryCacheManager.h"
#import "../L1/XCAudioSegmentInfo.h"
#import "../XCAudioCachePathUtils.h"

@implementation XCAudioCachePhase4Test

+ (void)runAllTests {
    NSLog(@"[Phase4Test] ========== Phase 4 Test Start ==========");
    
    // 先清理环境
    [[XCMemoryCacheManager sharedInstance] clearAllCache];
    [[XCPersistentCacheManager sharedInstance] clearAllCache];
    [[XCCacheIndexManager sharedInstance] clearAllCache];
    
    // A. L3 基础功能测试
    [self testSingleton];
    [self testWriteCompleteSong];
    [self testCachedURL];
    [self testHasCompleteCache];
    [self testDeleteCache];
    [self testCacheStatistics];
    
    // B. 分段合并测试
    [self testMergeAllSegments];
    [self testWriteMergedSegmentsToFile];
    [self testLargeFileMerge];
    
    // C. 流程测试
    [self testL1ToL3Flow];
    [self testMoveTempFileToCache];
    
    // 测试结束清理
    [[XCMemoryCacheManager sharedInstance] clearAllCache];
    [[XCPersistentCacheManager sharedInstance] clearAllCache];
    [[XCCacheIndexManager sharedInstance] clearAllCache];
    
    NSLog(@"[Phase4Test] ========== Phase 4 Test End ==========");
}

#pragma mark - A. L3 基础功能测试

+ (void)testSingleton {
    NSLog(@"[Phase4Test] Testing singleton...");
    
    XCPersistentCacheManager *manager1 = [XCPersistentCacheManager sharedInstance];
    XCPersistentCacheManager *manager2 = [XCPersistentCacheManager sharedInstance];
    
    NSAssert(manager1 == manager2, @"Singleton should return same instance");
    
    NSLog(@"[Phase4Test] Singleton OK");
}

+ (void)testWriteCompleteSong {
    NSLog(@"[Phase4Test] Testing writeCompleteSongData...");
    
    XCPersistentCacheManager *manager = [XCPersistentCacheManager sharedInstance];
    NSString *songId = @"test_complete_song_001";
    NSString *content = @"This is a complete song data simulation";
    NSData *data = [content dataUsingEncoding:NSUTF8StringEncoding];
    
    // 写入
    BOOL success = [manager writeCompleteSongData:data forSongId:songId];
    NSAssert(success == YES, @"Write should succeed");
    
    // 验证文件存在
    NSAssert([manager hasCompleteCacheForSongId:songId] == YES, @"Should have cache after write");
    
    // 验证文件大小
    NSInteger fileSize = [manager fileSizeForSongId:songId];
    NSAssert(fileSize == data.length, @"File size should match data length");
    
    // 验证索引更新
    XCAudioSongCacheInfo *info = [[XCCacheIndexManager sharedInstance] getSongCacheInfo:songId];
    NSAssert(info != nil, @"Index should be updated");
    NSAssert([info.songId isEqualToString:songId], @"SongId should match");
    NSAssert(info.totalSize == data.length, @"Total size should match");
    
    // 清理
    [manager deleteCacheForSongId:songId];
    
    NSLog(@"[Phase4Test] writeCompleteSongData OK");
}

+ (void)testCachedURL {
    NSLog(@"[Phase4Test] Testing cachedURL...");
    
    XCPersistentCacheManager *manager = [XCPersistentCacheManager sharedInstance];
    NSString *songId = @"test_url_song";
    NSData *data = [@"test data" dataUsingEncoding:NSUTF8StringEncoding];
    
    // 写入前应该返回 nil
    NSURL *urlBefore = [manager cachedURLForSongId:songId];
    NSAssert(urlBefore == nil, @"URL should be nil before write");
    
    // 写入
    [manager writeCompleteSongData:data forSongId:songId];
    
    // 写入后应该返回有效 URL
    NSURL *urlAfter = [manager cachedURLForSongId:songId];
    NSAssert(urlAfter != nil, @"URL should not be nil after write");
    NSAssert([urlAfter isFileURL], @"Should be a file URL");
    
    // 验证文件可读
    NSData *readData = [NSData dataWithContentsOfURL:urlAfter];
    NSAssert(readData != nil, @"Should be able to read file");
    NSAssert([readData isEqualToData:data], @"Read data should match original");
    
    // 清理
    [manager deleteCacheForSongId:songId];
    
    NSLog(@"[Phase4Test] cachedURL OK");
}

+ (void)testHasCompleteCache {
    NSLog(@"[Phase4Test] Testing hasCompleteCache...");
    
    XCPersistentCacheManager *manager = [XCPersistentCacheManager sharedInstance];
    NSString *songId = @"test_has_cache";
    
    // 不存在时
    BOOL existsBefore = [manager hasCompleteCacheForSongId:songId];
    NSAssert(existsBefore == NO, @"Should not have cache before write");
    
    // 写入
    [manager writeCompleteSongData:[@"data" dataUsingEncoding:NSUTF8StringEncoding] forSongId:songId];
    
    // 存在时
    BOOL existsAfter = [manager hasCompleteCacheForSongId:songId];
    NSAssert(existsAfter == YES, @"Should have cache after write");
    
    // 删除后
    [manager deleteCacheForSongId:songId];
    BOOL existsAfterDelete = [manager hasCompleteCacheForSongId:songId];
    NSAssert(existsAfterDelete == NO, @"Should not have cache after delete");
    
    NSLog(@"[Phase4Test] hasCompleteCache OK");
}

+ (void)testDeleteCache {
    NSLog(@"[Phase4Test] Testing deleteCache...");
    
    XCPersistentCacheManager *manager = [XCPersistentCacheManager sharedInstance];
    NSString *songId = @"test_delete";
    
    // 写入多个歌曲
    for (NSInteger i = 0; i < 3; i++) {
        NSString *sid = [NSString stringWithFormat:@"%@_%ld", songId, (long)i];
        [manager writeCompleteSongData:[@"data" dataUsingEncoding:NSUTF8StringEncoding] forSongId:sid];
    }
    
    // 删除其中一个
    NSString *targetSong = [NSString stringWithFormat:@"%@_1", songId];
    [manager deleteCacheForSongId:targetSong];
    
    // 验证删除成功
    NSAssert([manager hasCompleteCacheForSongId:targetSong] == NO, @"Deleted song should not exist");
    
    // 验证其他歌曲还在
    NSString *otherSong1 = [NSString stringWithFormat:@"%@_0", songId];
    NSString *otherSong2 = [NSString stringWithFormat:@"%@_2", songId];
    NSAssert([manager hasCompleteCacheForSongId:otherSong1] == YES, @"Other songs should exist");
    NSAssert([manager hasCompleteCacheForSongId:otherSong2] == YES, @"Other songs should exist");
    
    // 清理
    [[XCPersistentCacheManager sharedInstance] clearAllCache];
    
    NSLog(@"[Phase4Test] deleteCache OK");
}

+ (void)testCacheStatistics {
    NSLog(@"[Phase4Test] Testing cache statistics...");
    
    XCPersistentCacheManager *manager = [XCPersistentCacheManager sharedInstance];
    [manager clearAllCache];
    
    // 初始状态
    NSInteger initialCount = [manager cachedSongCount];
    NSInteger initialSize = [manager totalCacheSize];
    NSAssert(initialCount == 0, @"Initial count should be 0");
    NSAssert(initialSize == 0, @"Initial size should be 0");
    
    // 添加歌曲
    NSString *data1 = @"Song data 1 with more content";
    NSString *data2 = @"Song data 2 with different content length";
    [manager writeCompleteSongData:[data1 dataUsingEncoding:NSUTF8StringEncoding] forSongId:@"stat_song_1"];
    [manager writeCompleteSongData:[data2 dataUsingEncoding:NSUTF8StringEncoding] forSongId:@"stat_song_2"];
    
    // 验证统计
    NSInteger count = [manager cachedSongCount];
    NSInteger size = [manager totalCacheSize];
    NSAssert(count == 2, @"Should have 2 songs");
    NSAssert(size == data1.length + data2.length, @"Total size should match sum");
    
    // 清理
    [manager clearAllCache];
    
    NSLog(@"[Phase4Test] cacheStatistics OK");
}

#pragma mark - B. 分段合并测试

+ (void)testMergeAllSegments {
    NSLog(@"[Phase4Test] Testing mergeAllSegments...");
    
    XCMemoryCacheManager *manager = [XCMemoryCacheManager sharedInstance];
    [manager clearAllCache];
    
    NSString *songId = @"merge_test_song";
    
    // 存储 3 个分段
    [manager storeSegmentData:[@"Part1_" dataUsingEncoding:NSUTF8StringEncoding]
                   forSongId:songId
                segmentIndex:0];
    [manager storeSegmentData:[@"Part2_" dataUsingEncoding:NSUTF8StringEncoding]
                   forSongId:songId
                segmentIndex:1];
    [manager storeSegmentData:[@"Part3" dataUsingEncoding:NSUTF8StringEncoding]
                   forSongId:songId
                segmentIndex:2];
    
    // 合并
    NSData *merged = [manager mergeAllSegmentsForSongId:songId];
    NSAssert(merged != nil, @"Merged data should not be nil");
    
    NSString *result = [[NSString alloc] initWithData:merged encoding:NSUTF8StringEncoding];
    NSAssert([result isEqualToString:@"Part1_Part2_Part3"], @"Merged result should be 'Part1_Part2_Part3'");
    
    // 验证合并后 L1 数据还在（合并不删除原数据）
    NSAssert([manager segmentCountForSongId:songId] == 3, @"Original segments should still exist");
    
    // 清理
    [manager clearAllCache];
    
    NSLog(@"[Phase4Test] mergeAllSegments OK");
}

+ (void)testWriteMergedSegmentsToFile {
    NSLog(@"[Phase4Test] Testing writeMergedSegmentsToFile...");
    
    XCMemoryCacheManager *manager = [XCMemoryCacheManager sharedInstance];
    [manager clearAllCache];
    
    NSString *songId = @"file_merge_test";
    NSString *tempPath = [[XCAudioCachePathUtils sharedInstance] tempFilePathForSongId:songId];
    
    // 存储 3 个分段
    [manager storeSegmentData:[@"Hello " dataUsingEncoding:NSUTF8StringEncoding]
                   forSongId:songId
                segmentIndex:0];
    [manager storeSegmentData:[@"World " dataUsingEncoding:NSUTF8StringEncoding]
                   forSongId:songId
                segmentIndex:1];
    [manager storeSegmentData:[@"!" dataUsingEncoding:NSUTF8StringEncoding]
                   forSongId:songId
                segmentIndex:2];
    
    // 写入文件
    BOOL success = [manager writeMergedSegmentsToFile:tempPath forSongId:songId];
    NSAssert(success == YES, @"Write should succeed");
    
    // 验证文件存在
    NSFileManager *fm = [NSFileManager defaultManager];
    NSAssert([fm fileExistsAtPath:tempPath] == YES, @"File should exist");
    
    // 验证文件内容
    NSData *fileData = [NSData dataWithContentsOfFile:tempPath];
    NSString *content = [[NSString alloc] initWithData:fileData encoding:NSUTF8StringEncoding];
    NSAssert([content isEqualToString:@"Hello World !"], @"File content should be 'Hello World !'");
    
    // 清理
    [manager clearAllCache];
    [fm removeItemAtPath:tempPath error:nil];
    
    NSLog(@"[Phase4Test] writeMergedSegmentsToFile OK");
}

+ (void)testLargeFileMerge {
    NSLog(@"[Phase4Test] Testing large file merge (memory efficiency)...");
    
    XCMemoryCacheManager *manager = [XCMemoryCacheManager sharedInstance];
    [manager clearAllCache];
    
    NSString *songId = @"large_merge_test";
    NSString *tempPath = [[XCAudioCachePathUtils sharedInstance] tempFilePathForSongId:songId];
    
    // 创建 10 个 1KB 的分段（共 10KB，小文件方便测试，原理相同）
    NSInteger segmentCount = 10;
    NSInteger segmentSize = 1024; // 1KB
    
    for (NSInteger i = 0; i < segmentCount; i++) {
        NSMutableData *segmentData = [NSMutableData dataWithLength:segmentSize];
        // 填充特定标记，方便验证
        memset(segmentData.mutableBytes, 'A' + (int)i, segmentSize);
        [manager storeSegmentData:segmentData forSongId:songId segmentIndex:i];
    }
    
    // 使用流式合并
    BOOL success = [manager writeMergedSegmentsToFile:tempPath forSongId:songId];
    NSAssert(success == YES, @"Large file merge should succeed");
    
    // 验证文件大小
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDictionary *attrs = [fm attributesOfItemAtPath:tempPath error:nil];
    NSInteger fileSize = [attrs[NSFileSize] integerValue];
    NSAssert(fileSize == segmentCount * segmentSize, @"File size should match total segments size");
    
    NSLog(@"[Phase4Test] Large file merge OK (size: %ld bytes)", (long)fileSize);
    
    // 清理
    [manager clearAllCache];
    [fm removeItemAtPath:tempPath error:nil];
}

#pragma mark - C. 流程测试

+ (void)testL1ToL3Flow {
    NSLog(@"[Phase4Test] Testing L1 to L3 flow...");
    
    XCMemoryCacheManager *memoryManager = [XCMemoryCacheManager sharedInstance];
    XCPersistentCacheManager *persistentManager = [XCPersistentCacheManager sharedInstance];
    XCCacheIndexManager *indexManager = [XCCacheIndexManager sharedInstance];
    
    [memoryManager clearAllCache];
    [persistentManager clearAllCache];
    [indexManager clearAllCache];
    
    NSString *songId = @"flow_test_song";
    NSInteger expectedSize = 0;
    
    // 步骤 1: 模拟播放时存储分段到 L1
    NSLog(@"[Phase4Test] Step 1: Storing segments to L1...");
    for (NSInteger i = 0; i < 5; i++) {
        NSString *content = [NSString stringWithFormat:@"Segment%ld-", (long)i];
        NSData *segment = [content dataUsingEncoding:NSUTF8StringEncoding];
        [memoryManager storeSegmentData:segment forSongId:songId segmentIndex:i];
        expectedSize += segment.length;
    }
    
    NSAssert([memoryManager segmentCountForSongId:songId] == 5, @"Should have 5 segments in L1");
    
    // 步骤 2: 模拟切歌，合并到 L3
    NSLog(@"[Phase4Test] Step 2: Merging to L3...");
    NSString *cachePath = [[XCAudioCachePathUtils sharedInstance] cacheFilePathForSongId:songId];
    BOOL merged = [memoryManager writeMergedSegmentsToFile:cachePath forSongId:songId];
    NSAssert(merged == YES, @"Merge should succeed");
    
    // 步骤 3: 更新索引
    NSLog(@"[Phase4Test] Step 3: Updating index...");
    XCAudioSongCacheInfo *info = [[XCAudioSongCacheInfo alloc] initWithSongId:songId totalSize:expectedSize];
    [info updatePlayTime];
    [indexManager addSongCacheInfo:info];
    
    // 步骤 4: 清空 L1
    NSLog(@"[Phase4Test] Step 4: Clearing L1...");
    [memoryManager clearSegmentsForSongId:songId];
    
    // 步骤 5: 验证最终状态
    NSLog(@"[Phase4Test] Step 5: Verifying final state...");
    NSAssert([memoryManager segmentCountForSongId:songId] == 0, @"L1 should be empty");
    NSAssert([persistentManager hasCompleteCacheForSongId:songId] == YES, @"L3 should have the file");
    NSAssert([indexManager getSongCacheInfo:songId] != nil, @"Index should have the record");
    
    // 验证文件内容正确
    NSData *l3Data = [NSData dataWithContentsOfFile:cachePath];
    NSAssert(l3Data.length == expectedSize, @"L3 file size should match");
    
    NSLog(@"[Phase4Test] L1 to L3 flow OK");
}

+ (void)testMoveTempFileToCache {
    NSLog(@"[Phase4Test] Testing moveTempFileToCache...");
    
    XCMemoryCacheManager *memoryManager = [XCMemoryCacheManager sharedInstance];
    XCPersistentCacheManager *persistentManager = [XCPersistentCacheManager sharedInstance];
    XCCacheIndexManager *indexManager = [XCCacheIndexManager sharedInstance];
    
    [memoryManager clearAllCache];
    [persistentManager clearAllCache];
    [indexManager clearAllCache];
    
    NSString *songId = @"move_temp_test";
    NSString *tempPath = [[XCAudioCachePathUtils sharedInstance] tempFilePathForSongId:songId];
    NSString *cachePath = [[XCAudioCachePathUtils sharedInstance] cacheFilePathForSongId:songId];
    
    // 步骤 1: 存储分段并合并到临时文件
    [memoryManager storeSegmentData:[@"Temp " dataUsingEncoding:NSUTF8StringEncoding]
                        forSongId:songId
                     segmentIndex:0];
    [memoryManager storeSegmentData:[@"File " dataUsingEncoding:NSUTF8StringEncoding]
                        forSongId:songId
                     segmentIndex:1];
    [memoryManager storeSegmentData:[@"Data" dataUsingEncoding:NSUTF8StringEncoding]
                        forSongId:songId
                     segmentIndex:2];
    
    [memoryManager writeMergedSegmentsToFile:tempPath forSongId:songId];
    
    // 验证临时文件存在
    NSFileManager *fm = [NSFileManager defaultManager];
    NSAssert([fm fileExistsAtPath:tempPath] == YES, @"Temp file should exist");
    
    // 步骤 2: 移动临时文件到 L3
    BOOL moved = [persistentManager moveTempFileToCache:tempPath forSongId:songId];
    NSAssert(moved == YES, @"Move should succeed");
    
    // 步骤 3: 验证状态
    NSAssert([fm fileExistsAtPath:tempPath] == NO, @"Temp file should be gone");
    NSAssert([fm fileExistsAtPath:cachePath] == YES, @"Cache file should exist");
    NSAssert([persistentManager hasCompleteCacheForSongId:songId] == YES, @"L3 should have cache");
    
    // 验证索引
    XCAudioSongCacheInfo *info = [indexManager getSongCacheInfo:songId];
    NSAssert(info != nil, @"Index should be updated");
    
    NSLog(@"[Phase4Test] moveTempFileToCache OK");
}

@end
