//
//  XCSongCommentDragHandle.h
//  Spotify - clone
//
//  Created by Kimi on 2026/03/03.
//  评论面板顶部拖拽指示条
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 评论面板顶部拖拽指示条
@interface XCSongCommentDragHandle : UIView

/// 指示条颜色（默认灰色）
@property (nonatomic, strong) UIColor *indicatorColor;

/// 设置拖拽状态（是否被拖拽中）
- (void)setDragging:(BOOL)dragging;

@end

NS_ASSUME_NONNULL_END
