//
//  XCAudioCacheTestRunner.h
//  Spotify - clone
//
//  音频缓存测试运行器
//  提供可视化测试界面
//

#import <UIKit/UIKit.h>

@interface XCAudioCacheTestRunner : NSObject

/// 显示测试菜单（从指定视图控制器弹出）
/// @param viewController 父视图控制器
+ (void)showTestMenuFromViewController:(UIViewController *)viewController;

/// 运行所有阶段的测试
+ (void)runAllPhaseTests;

@end
