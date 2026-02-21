//
//  XCPersonalLoginView.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/20.
//
//  登录提示视图（预留登录功能）
//

#import <UIKit/UIKit.h>
#import "XCPersonalLoginProtocol.h"

NS_ASSUME_NONNULL_BEGIN

/// 登录提示视图
@interface XCPersonalLoginView : UIView

#pragma mark - UI 元素
/// 图标
@property (nonatomic, strong, readonly) UIImageView* iconImageView;
/// 标题
@property (nonatomic, strong, readonly) UILabel* titleLabel;
/// 副标题
@property (nonatomic, strong, readonly) UILabel* subtitleLabel;
/// 登录按钮
@property (nonatomic, strong, readonly) UIButton* loginButton;

#pragma mark - 状态
/// 当前登录状态
@property (nonatomic, assign) XCLoginStatus loginStatus;

#pragma mark - 回调
/// 登录按钮点击回调
@property (nonatomic, copy, nullable) void (^loginButtonTapHandler)(void);

@end

NS_ASSUME_NONNULL_END
