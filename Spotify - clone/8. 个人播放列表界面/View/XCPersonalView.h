//
//  XCPersonalView.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/1.
//
//  View 层 - 个人播放列表主视图
//  职责：UI 展示，不包含业务逻辑
//

#import <UIKit/UIKit.h>
#import "XCPersonalLoginProtocol.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark - 视图模式枚举
typedef NS_ENUM(NSInteger, XCPlaylistViewMode) {
    XCPlaylistViewModeGrid = 0,     // 网格视图（2列）
    XCPlaylistViewModeList          // 列表视图（单行）
};

#pragma mark - View 代理协议
@protocol XCPersonalViewDelegate <NSObject>

@optional
/// 点击播放列表
- (void)personalView:(UIView*)view didSelectPlaylistAtIndex:(NSInteger)index;
/// 长按播放列表
- (void)personalView:(UIView*)view didLongPressPlaylistAtIndex:(NSInteger)index;
/// 点击空状态的创建按钮
- (void)personalViewDidTapCreateButton:(UIView*)view;
/// 点击登录按钮（预留）
- (void)personalViewDidTapLoginButton:(UIView*)view;
/// 视图模式改变
- (void)personalView:(UIView*)view didChangeViewMode:(XCPlaylistViewMode)mode;

@end

#pragma mark - XCPersonalView 主视图
@interface XCPersonalView : UIView

#pragma mark - 子视图
/// 集合视图（网格/列表共用）
@property (nonatomic, strong, readonly) UICollectionView* collectionView;
/// 空状态视图
@property (nonatomic, strong, readonly) UIView* emptyView;
/// 登录提示视图（预留）
@property (nonatomic, strong, readonly) UIView* loginView;

#pragma mark - 配置属性
/// 代理
@property (nonatomic, weak) id<XCPersonalViewDelegate> delegate;
/// 当前视图模式
@property (nonatomic, assign, readonly) XCPlaylistViewMode currentViewMode;
/// 登录状态（影响UI展示）
@property (nonatomic, assign) XCLoginStatus loginStatus;

#pragma mark - 布局切换
/// 切换到网格视图
- (void)switchToGridLayoutAnimated:(BOOL)animated;
/// 切换到列表视图
- (void)switchToListLayoutAnimated:(BOOL)animated;
/// 切换视图模式（自动判断当前模式）
- (void)toggleViewModeAnimated:(BOOL)animated;

#pragma mark - 状态显示
/// 显示/隐藏空状态视图
- (void)showEmptyView:(BOOL)show;
/// 显示/隐藏登录提示视图（预留）
- (void)showLoginView:(BOOL)show;
/// 显示/隐藏加载中
- (void)showLoading:(BOOL)show;

#pragma mark - 刷新
/// 刷新集合视图
- (void)reloadData;
/// 刷新指定项目
- (void)reloadItemsAtIndexes:(NSArray<NSNumber*>*)indexes;

#pragma mark - 便捷方法
/// 获取当前布局的 Cell 大小
- (CGSize)currentCellSize;
/// 滚动到指定位置
- (void)scrollToItemAtIndex:(NSInteger)index animated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
