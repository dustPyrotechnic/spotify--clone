//
//  XCAudioCachePhase8Test.h
//  Spotify - clone
//
//  Phase 8: 系统集成测试
//  测试 XCMusicPlayerModel 与新缓存系统的集成
//

#import <Foundation/Foundation.h>

/// Phase 8 集成测试类
/// @discussion 测试播放器与三级缓存系统的集成
@interface XCAudioCachePhase8Test : NSObject

/// 运行所有 Phase 8 测试
+ (void)runAllTests;

/// 测试 1: 播放器缓存查询（L3 命中）
+ (void)testPlayerL3CacheHit;

/// 测试 2: 播放器缓存查询（L2 命中）
+ (void)testPlayerL2CacheHit;

/// 测试 3: 切歌时缓存保存流程
+ (void)testSongSwitchingCacheFlow;

/// 测试 4: 50% 进度触发预加载
+ (void)testPreloadAt50Percent;

/// 测试 5: 播放器与缓存统计
+ (void)testPlayerCacheStatistics;

/// 测试 6: 完整播放流程（网络 -> L1 -> L2 -> L3）
+ (void)testCompletePlaybackFlow;

/// 测试 7: 播放列表预加载
+ (void)testPlaylistPreload;

@end
