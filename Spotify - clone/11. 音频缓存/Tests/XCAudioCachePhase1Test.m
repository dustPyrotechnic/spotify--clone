//
//  XCAudioCachePhase1Test.m
//  Spotify - clone
//

#import "XCAudioCachePhase1Test.h"
#import "../XCAudioCacheConst.h"
#import "../L1/XCAudioSegmentInfo.h"
#import "../L3/XCAudioSongCacheInfo.h"
#import "../XCAudioCachePathUtils.h"

@implementation XCAudioCachePhase1Test

+ (void)runAllTests {
    NSLog(@"[Phase1Test] ========== Phase 1 Test Start ==========");
    
    [self testConstants];
    [self testDirectoryCreation];
    [self testPathUtils];
    [self testSegmentInfo];
    [self testSongCacheInfo];
    
    NSLog(@"[Phase1Test] ========== Phase 1 Test End ==========");
}

+ (void)testConstants {
    NSLog(@"[Phase1Test] Testing constants...");
    
    NSAssert(kAudioSegmentSize == 512 * 1024, @"Segment size should be 512KB");
    NSAssert(kAudioCacheMemoryLimit == 100 * 1024 * 1024, @"Memory limit should be 100MB");
    NSAssert(kAudioCacheDiskLimit == 1024 * 1024 * 1024, @"Disk limit should be 1GB");
    NSAssert(kAudioCacheTempLimit == 500 * 1024 * 1024, @"Temp limit should be 500MB");
    NSAssert(kAudioTempFileExpireTime == 7 * 24 * 60 * 60, @"Expire time should be 7 days");
    
    NSLog(@"[Phase1Test] Constants OK");
}

+ (void)testDirectoryCreation {
    NSLog(@"[Phase1Test] Testing directory creation...");
    
    XCAudioCachePathUtils *utils = [XCAudioCachePathUtils sharedInstance];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    BOOL tempExists = [fm fileExistsAtPath:utils.tempDirectory];
    BOOL cacheExists = [fm fileExistsAtPath:utils.cacheDirectory];
    
    NSAssert(tempExists, @"Temp directory should exist");
    NSAssert(cacheExists, @"Cache directory should exist");
    
    NSLog(@"[Phase1Test] Temp dir: %@", utils.tempDirectory);
    NSLog(@"[Phase1Test] Cache dir: %@", utils.cacheDirectory);
    NSLog(@"[Phase1Test] Directory creation OK");
}

+ (void)testPathUtils {
    NSLog(@"[Phase1Test] Testing path utils...");
    
    XCAudioCachePathUtils *utils = [XCAudioCachePathUtils sharedInstance];
    
    NSString *tempPath = [utils tempFilePathForSongId:@"test123"];
    NSString *cachePath = [utils cacheFilePathForSongId:@"test123"];
    
    NSAssert([tempPath containsString:@"test123.mp3.tmp"], @"Temp path should contain songId");
    NSAssert([cachePath containsString:@"test123.mp3"], @"Cache path should contain songId");
    NSAssert(![cachePath containsString:@".tmp"], @"Cache path should not have .tmp extension");
    
    NSLog(@"[Phase1Test] Temp path: %@", tempPath);
    NSLog(@"[Phase1Test] Cache path: %@", cachePath);
    NSLog(@"[Phase1Test] Path utils OK");
}

+ (void)testSegmentInfo {
    NSLog(@"[Phase1Test] Testing XCAudioSegmentInfo...");
    
    XCAudioSegmentInfo *info = [[XCAudioSegmentInfo alloc] initWithIndex:5 offset:1024 size:512000];
    
    NSAssert(info.index == 5, @"Index should be 5");
    NSAssert(info.offset == 1024, @"Offset should be 1024");
    NSAssert(info.size == 512000, @"Size should be 512000");
    NSAssert(info.isDownloaded == NO, @"isDownloaded should be NO initially");
    
    NSString *testData = @"Test segment data";
    info.data = [testData dataUsingEncoding:NSUTF8StringEncoding];
    NSAssert(info.data != nil, @"Data should be settable");
    NSAssert(info.data.length == testData.length, @"Data length should match");
    
    NSLog(@"[Phase1Test] SegmentInfo: index=%ld, offset=%lld, size=%ld", 
          (long)info.index, info.offset, (long)info.size);
    NSLog(@"[Phase1Test] XCAudioSegmentInfo OK");
}

+ (void)testSongCacheInfo {
    NSLog(@"[Phase1Test] Testing XCAudioSongCacheInfo...");
    
    XCAudioSongCacheInfo *info = [[XCAudioSongCacheInfo alloc] initWithSongId:@"song456" totalSize:5242880];
    
    NSAssert([info.songId isEqualToString:@"song456"], @"SongId should match");
    NSAssert(info.totalSize == 5242880, @"TotalSize should be 5MB");
    NSAssert(info.cacheTime > 0, @"CacheTime should be set");
    NSAssert(info.lastPlayTime == info.cacheTime, @"LastPlayTime should equal cacheTime initially");
    NSAssert(info.playCount == 0, @"PlayCount should be 0 initially");
    
    NSTimeInterval oldPlayTime = info.lastPlayTime;
    [info updatePlayTime];
    NSAssert(info.lastPlayTime > oldPlayTime, @"LastPlayTime should update");
    NSAssert(info.playCount == 1, @"PlayCount should increment");
    
    NSLog(@"[Phase1Test] SongCacheInfo: songId=%@, totalSize=%ld", info.songId, (long)info.totalSize);
    NSLog(@"[Phase1Test] XCAudioSongCacheInfo OK");
}

@end
