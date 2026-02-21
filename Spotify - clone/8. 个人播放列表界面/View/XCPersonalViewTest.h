//
//  XCPersonalViewTest.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/20.
//
//  View 层测试类
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// View 层测试类
@interface XCPersonalViewTest : NSObject

#pragma mark - 测试入口
/// 运行所有测试
+ (void)runAllTests;

/// 运行单个测试
+ (BOOL)runTest:(SEL)testSelector;

#pragma mark - 视图创建测试
/// 测试 XCPersonalView 创建
+ (BOOL)testPersonalViewCreation;

/// 测试网格 Cell 创建
+ (BOOL)testGridCellCreation;

/// 测试列表 Cell 创建
+ (BOOL)testListCellCreation;

/// 测试空状态视图创建
+ (BOOL)testEmptyViewCreation;

/// 测试登录视图创建
+ (BOOL)testLoginViewCreation;

#pragma mark - 功能测试
/// 测试视图模式切换
+ (BOOL)testViewModeSwitching;

/// 测试布局更新
+ (BOOL)testLayoutUpdates;

/// 测试空状态显示
+ (BOOL)testEmptyViewDisplay;

/// 测试登录状态显示
+ (BOOL)testLoginViewDisplay;

#pragma mark - 测试统计
/// 获取测试结果统计
+ (NSDictionary*)testStatistics;

/// 打印测试报告
+ (void)printTestReport;

@end

NS_ASSUME_NONNULL_END
