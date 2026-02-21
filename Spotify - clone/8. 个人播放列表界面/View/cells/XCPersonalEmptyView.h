//
//  XCPersonalEmptyView.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/20.
//
//  空状态视图
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 空状态视图
@interface XCPersonalEmptyView : UIView

#pragma mark - UI 元素
/// 图标
@property (nonatomic, strong, readonly) UIImageView* iconImageView;
/// 标题
@property (nonatomic, strong, readonly) UILabel* titleLabel;
/// 副标题
@property (nonatomic, strong, readonly) UILabel* subtitleLabel;
/// 创建按钮
@property (nonatomic, strong, readonly) UIButton* createButton;

#pragma mark - 回调
/// 创建按钮点击回调
@property (nonatomic, copy, nullable) void (^createButtonTapHandler)(void);

#pragma mark - 配置
/// 设置是否显示创建按钮
- (void)showCreateButton:(BOOL)show;

@end

NS_ASSUME_NONNULL_END
