//
//  XCPersonalModelTest.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/20.
//
//  XCPersonalModel 单元测试类
//  测试 Model 层的所有功能
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Model 层测试类
@interface XCPersonalModelTest : NSObject

#pragma mark - 测试入口
/// 运行所有测试
+ (void)runAllTests;

/// 运行单个测试并返回结果
+ (BOOL)runTest:(SEL)testSelector;

#pragma mark - 基础功能测试
/// 测试单例模式
+ (BOOL)testSingleton;

/// 测试数据加载
+ (BOOL)testDataLoading;

/// 测试数据保存
+ (BOOL)testDataSaving;

#pragma mark - CRUD 测试
/// 测试创建播放列表
+ (BOOL)testCreatePlaylist;

/// 测试删除播放列表
+ (BOOL)testDeletePlaylist;

/// 测试更新播放列表
+ (BOOL)testUpdatePlaylist;

/// 测试更新歌曲数量
+ (BOOL)testUpdateSongCount;

#pragma mark - 搜索排序测试
/// 测试搜索功能
+ (BOOL)testSearchFilter;

/// 测试排序功能
+ (BOOL)testSortPlaylists;

/// 测试清除过滤
+ (BOOL)testClearFilter;

#pragma mark - 扩展信息测试
/// 测试扩展信息查询
+ (BOOL)testPlaylistInfoQuery;

#pragma mark - 通知测试
/// 测试通知发送
+ (BOOL)testNotifications;

#pragma mark - 数据一致性测试
/// 测试数据一致性
+ (BOOL)testDataConsistency;

#pragma mark - 压力测试
/// 压力测试：大量数据
+ (BOOL)testLargeDataset;

/// 压力测试：频繁操作
+ (BOOL)testFrequentOperations;

#pragma mark - 测试统计
/// 获取测试结果统计
+ (NSDictionary*)testStatistics;

/// 打印测试报告
+ (void)printTestReport;

@end

NS_ASSUME_NONNULL_END
