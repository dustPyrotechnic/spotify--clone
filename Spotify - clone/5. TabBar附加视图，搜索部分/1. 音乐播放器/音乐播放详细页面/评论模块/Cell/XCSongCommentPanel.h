//
//  XCSongCommentPanel.h
//  Spotify - clone
//
//  Created by Kimi on 2026/03/03.
//  评论面板容器
//

#import <UIKit/UIKit.h>
#import "XCSongCommentList.h"
#import "XCSongComment.h"
#import "XCSongCommentService.h"

NS_ASSUME_NONNULL_BEGIN

@class XCSongCommentPanel;

@protocol XCSongCommentPanelDelegate <NSObject>

@optional
/// 点击关闭按钮
- (void)commentPanelDidTapClose:(XCSongCommentPanel *)panel;
/// 切换排序方式
- (void)commentPanel:(XCSongCommentPanel *)panel didChangeSortType:(XCCommentSortType)sortType;
/// 加载更多评论
- (void)commentPanelDidRequestLoadMore:(XCSongCommentPanel *)panel;
/// 点击评论的回复
- (void)commentPanel:(XCSongCommentPanel *)panel didTapViewReplies:(XCSongComment *)comment;
/// 点击展开/收起长评论
- (void)commentPanel:(XCSongCommentPanel *)panel didToggleExpandForComment:(XCSongComment *)comment atIndexPath:(NSIndexPath *)indexPath;

@end

#pragma mark - XCSongCommentPanel

/// 评论面板容器
@interface XCSongCommentPanel : UIView

@property (nonatomic, weak) id<XCSongCommentPanelDelegate> delegate;
@property (nonatomic, strong, nullable) XCSongCommentList *commentList;

/// 应用播放页主题色（darken ~10%，比播放页背景稍亮）
- (void)applyThemeColor:(UIColor *)baseColor;

/// 显示加载中
- (void)showLoading;
/// 隐藏加载中
- (void)hideLoading;
/// 显示空状态
- (void)showEmptyState;
/// 刷新数据
- (void)reloadData;
/// 结束刷新
- (void)endRefreshing;
/// 结束加载更多
- (void)endLoadMore:(BOOL)hasMore;

@end

NS_ASSUME_NONNULL_END
