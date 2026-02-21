//
//  XCPersonalModelTestRunner.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/20.
//
//  Model 层测试运行器
//  用于在 App 中运行测试并显示结果
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Model 层测试运行器
@interface XCPersonalModelTestRunner : NSObject

/// 运行所有测试并在控制台输出结果
+ (void)runTests;

/// 运行测试并显示结果弹窗
/// @param viewController 用于显示弹窗的视图控制器
+ (void)runTestsAndShowResultInViewController:(UIViewController*)viewController;

/// 获取最后一次测试结果
+ (NSDictionary*)lastTestResults;

@end

NS_ASSUME_NONNULL_END
