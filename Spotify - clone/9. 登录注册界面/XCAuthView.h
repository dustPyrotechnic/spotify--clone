//
//  XCAuthView.h
//  Spotify - clone
//
//  深色主题登录/注册视图
//  - 分段控制器切换登录 / 注册
//  - 已登录时显示用户信息 + 登出按钮
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 视图事件回调（由 ViewController 实现）
@protocol XCAuthViewDelegate <NSObject>
- (void)authViewDidTapLogin:(NSString *)username password:(NSString *)password;
- (void)authViewDidTapRegister:(NSString *)username password:(NSString *)password confirmPassword:(NSString *)confirmPassword;
- (void)authViewDidTapLogout;
@end

@interface XCAuthView : UIView

@property (nonatomic, weak) id<XCAuthViewDelegate> delegate;

// 登录 / 注册区域
@property (nonatomic, strong, readonly) UISegmentedControl *segmentedControl;
@property (nonatomic, strong, readonly) UITextField *usernameField;
@property (nonatomic, strong, readonly) UITextField *passwordField;
@property (nonatomic, strong, readonly) UITextField *confirmPasswordField;
@property (nonatomic, strong, readonly) UIButton    *actionButton;
@property (nonatomic, strong, readonly) UILabel     *errorLabel;

// 已登录区域
@property (nonatomic, strong, readonly) UIView  *loggedInView;

/// 切换到登录模式（隐藏确认密码框）
- (void)showLoginMode;

/// 切换到注册模式（显示确认密码框）
- (void)showRegisterMode;

/// 显示已登录状态，传入登录响应 data 字典
- (void)showLoggedInWithUserInfo:(NSDictionary *)userInfo;

/// 显示错误信息（主线程调用）
- (void)showError:(NSString *)message;

/// 清除错误信息
- (void)clearError;

/// 显示 / 隐藏加载状态
- (void)setLoading:(BOOL)loading;

@end

NS_ASSUME_NONNULL_END
