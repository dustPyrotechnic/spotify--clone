//
//  XCPlaylistSortMenu.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/20.
//
//  播放列表排序菜单
//

#import <UIKit/UIKit.h>
#import "XCLocalPlaylistInfo.h"

NS_ASSUME_NONNULL_BEGIN

/// 排序菜单完成回调
typedef void (^XCPlaylistSortMenuHandler)(XCPlaylistSortType sortType);

/// 播放列表排序菜单
@interface XCPlaylistSortMenu : UIView

#pragma mark - 属性
/// 当前选中的排序类型
@property (nonatomic, assign) XCPlaylistSortType currentSortType;

#pragma mark - 显示/隐藏
/// 从指定视图底部弹出
/// @param view 父视图
/// @param currentSortType 当前排序类型
/// @param handler 选择回调
+ (void)showInView:(UIView*)view
   currentSortType:(XCPlaylistSortType)currentSortType
           handler:(XCPlaylistSortMenuHandler)handler;

/// 隐藏菜单
- (void)dismiss;

@end

NS_ASSUME_NONNULL_END
