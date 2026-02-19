//
//  XCAudioCachePhase7Test.h
//  Spotify - clone
//
//  Phase 7: 预加载机制测试
//  测试 XCPreloadManager 的各项功能
//

#import <Foundation/Foundation.h>

/// Phase 7 预加载机制测试类
/// @discussion 测试预加载管理器的各项功能，包括启动、取消、并发控制、优先级等
@interface XCAudioCachePhase7Test : NSObject

/// 运行所有 Phase 7 测试
+ (void)runAllTests;

/// 测试 1: 单例模式
+ (void)testSingleton;

/// 测试 2: 预加载启动和状态查询
+ (void)testPreloadStartAndStatus;

/// 测试 3: 取消预加载
+ (void)testCancelPreload;

/// 测试 4: 取消所有预加载
+ (void)testCancelAllPreloads;

/// 测试 5: 优先级队列
+ (void)testPriorityQueue;

/// 测试 6: 真实歌曲预加载（使用 ID: 2140776005）
+ (void)testRealSongPreload;

/// 测试 7: 进度回调
+ (void)testProgressCallback;

/// 测试 8: 完成回调
+ (void)testCompletionCallback;

/// 测试 9: 并发控制
+ (void)testConcurrentControl;

/// 测试 10: 批量预加载
+ (void)testBatchPreload;

/// 测试 11: 分段限制
+ (void)testSegmentLimit;

/// 测试 12: 暂停和恢复
+ (void)testPauseAndResume;

/// 测试 13: 预加载统计
+ (void)testStatistics;

/// 测试 14: 下一首高优先级预加载
+ (void)testNextSongPreload;

@end
