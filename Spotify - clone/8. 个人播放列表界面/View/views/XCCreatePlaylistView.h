//
//  XCCreatePlaylistView.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/20.
//
//  创建播放列表弹窗视图
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 创建播放列表弹窗
@interface XCCreatePlaylistView : UIView

#pragma mark - UI 元素
/// 背景遮罩
@property (nonatomic, strong, readonly) UIView* backdropView;
/// 内容容器
@property (nonatomic, strong, readonly) UIView* containerView;
/// 标题
@property (nonatomic, strong, readonly) UILabel* titleLabel;
/// 输入框
@property (nonatomic, strong, readonly) UITextField* nameTextField;
/// 取消按钮
@property (nonatomic, strong, readonly) UIButton* cancelButton;
/// 创建按钮
@property (nonatomic, strong, readonly) UIButton* createButton;

#pragma mark - 回调
/// 创建回调（返回输入的名称）
@property (nonatomic, copy, nullable) void (^createHandler)(NSString* name);
/// 取消回调
@property (nonatomic, copy, nullable) void (^cancelHandler)(void);

#pragma mark - 显示/隐藏
/// 在指定视图中显示
- (void)showInView:(UIView*)view;
/// 隐藏
- (void)dismiss;

@end

NS_ASSUME_NONNULL_END
