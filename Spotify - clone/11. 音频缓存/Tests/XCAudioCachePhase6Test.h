//
//  XCAudioCachePhase6Test.h
//  Spotify - clone
//
//  Phase 6 测试：缓存管理器整合测试
//

#import <Foundation/Foundation.h>

/// Phase 6 测试类
/// @discussion 测试 XCAudioCacheManager 的三级缓存整合功能
@interface XCAudioCachePhase6Test : NSObject

/// 运行所有 Phase 6 测试
+ (void)runAllTests;

/// 测试单例
+ (void)testSingleton;

/// 测试缓存状态查询
+ (void)testCacheState;

/// 测试三级查询（L3 → L2 → nil）
+ (void)testThreeLevelQuery;

/// 测试 L1 分段存储
+ (void)testL1SegmentStorage;

/// 测试 L1 → L2 流转
+ (void)testL1ToL2Flow;

/// 测试 L2 → L3 流转
+ (void)testL2ToL3Flow;

/// 测试完整的切歌流程
+ (void)testSongSwitchingFlow;

/// 测试删除操作
+ (void)testDeletion;

/// 测试优先级设置
+ (void)testPriority;

/// 测试统计信息
+ (void)testStatistics;

/// 测试缓存索引查询
+ (void)testCacheIndexQuery;

/// 性能测试
+ (void)testPerformance;

@end
