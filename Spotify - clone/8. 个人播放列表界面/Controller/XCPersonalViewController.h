//
//  XCPersonalViewController.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/1.
//
//  Controller 层 - 个人播放列表界面
//  整合 Model 和 View，处理用户交互
//

#import <UIKit/UIKit.h>
#import "XCPersonalModel.h"
#import "XCPersonalView.h"
#import "XCPersonalLoginProtocol.h"

NS_ASSUME_NONNULL_BEGIN

/// 个人播放列表视图控制器（MVC 中的 Controller 层）
@interface XCPersonalViewController : UIViewController <UICollectionViewDataSource, 
                                                        UICollectionViewDelegate,
                                                        UISearchResultsUpdating,
                                                        XCPersonalViewDelegate,
                                                        XCLoginStatusObserver>

#pragma mark - MVC 组件
/// Model 层（单例）
@property (nonatomic, strong, readonly) XCPersonalModel* model;
/// View 层
@property (nonatomic, strong, readonly) XCPersonalView* mainView;

#pragma mark - 导航栏组件
/// 搜索控制器
@property (nonatomic, strong, readonly) UISearchController* searchController;
/// 创建按钮
@property (nonatomic, strong, readonly) UIBarButtonItem* createButton;
/// 筛选按钮
@property (nonatomic, strong, readonly) UIBarButtonItem* filterButton;
/// 视图切换按钮
@property (nonatomic, strong, readonly) UIBarButtonItem* viewModeButton;

#pragma mark - 测试入口（DEBUG 模式下可用）
/// 快速添加测试数据
- (void)addTestDataForDebugging;
/// 清除所有数据
- (void)clearAllDataForDebugging;

@end

NS_ASSUME_NONNULL_END
