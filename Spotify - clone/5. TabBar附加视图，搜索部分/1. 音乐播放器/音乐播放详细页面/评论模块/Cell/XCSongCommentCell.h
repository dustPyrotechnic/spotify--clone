//
//  XCSongCommentCell.h
//  Spotify - clone
//
//  Created by Kimi on 2026/03/03.
//  评论单元格 - 支持长评论折叠/展开
//

#import <UIKit/UIKit.h>
#import "XCSongComment.h"

NS_ASSUME_NONNULL_BEGIN

@class XCSongCommentCell;

/// Cell 事件代理
@protocol XCSongCommentCellDelegate <NSObject>

@optional
/// 点击展开/收起按钮
- (void)commentCell:(XCSongCommentCell *)cell didTapExpand:(BOOL)expanded;
/// 点击查看回复
- (void)commentCell:(XCSongCommentCell *)cell didTapViewReplies:(XCSongComment *)comment;
/// 点击点赞
- (void)commentCell:(XCSongCommentCell *)cell didTapLike:(XCSongComment *)comment;

@end

#pragma mark - XCSongCommentCell

/// 评论单元格
@interface XCSongCommentCell : UITableViewCell

@property (nonatomic, strong) XCSongComment *comment;
@property (nonatomic, weak) id<XCSongCommentCellDelegate> delegate;

/// 获取复用标识
+ (NSString *)reuseIdentifier;

/// 根据当前 comment.isExpanded 状态刷新内容显示（行高动画前调用）
- (void)refreshContentDisplay;

@end

NS_ASSUME_NONNULL_END
