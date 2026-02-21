//
//  XCPersonalLoginProtocol.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/20.
//
//  登录相关协议和接口定义
//  预留接口，方便日后登录功能拓展
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - 登录状态枚举
typedef NS_ENUM(NSInteger, XCLoginStatus) {
    XCLoginStatusUnknown = 0,       // 未知状态（正在检查）
    XCLoginStatusNotLoggedIn,       // 未登录
    XCLoginStatusLoggingIn,         // 正在登录
    XCLoginStatusLoggedIn,          // 已登录
    XCLoginStatusLoginExpired       // 登录过期
};

#pragma mark - 用户信息模型（预留）
/// 用户信息模型
@interface XCUserInfo : NSObject <NSSecureCoding>
/// 用户ID
@property (nonatomic, copy) NSString* userId;
/// 用户名
@property (nonatomic, copy) NSString* userName;
/// 用户昵称
@property (nonatomic, copy) NSString* nickName;
/// 头像URL
@property (nonatomic, copy, nullable) NSString* avatarUrl;
/// 本地头像路径
@property (nonatomic, copy, nullable) NSString* localAvatarPath;
/// 邮箱
@property (nonatomic, copy, nullable) NSString* email;
/// 手机号
@property (nonatomic, copy, nullable) NSString* phoneNumber;
/// 注册时间
@property (nonatomic, strong) NSDate* registerDate;
/// 会员类型：0=普通, 1=VIP
@property (nonatomic, assign) NSInteger memberType;
/// 会员到期时间
@property (nonatomic, strong, nullable) NSDate* memberExpireDate;

#pragma mark - 便捷属性
/// 是否VIP
@property (nonatomic, assign, readonly) BOOL isVIP;
/// 格式化会员信息
@property (nonatomic, copy, readonly) NSString* memberInfoText;
/// 显示名称（优先使用昵称）
@property (nonatomic, copy, readonly) NSString* displayName;

#pragma mark - 单例当前用户
+ (instancetype)currentUser;
+ (void)setCurrentUser:(XCUserInfo*)userInfo;
+ (void)clearCurrentUser;

@end

#pragma mark - 登录管理器协议
/// 登录管理器协议
@protocol XCLoginManagerProtocol <NSObject>

@required
/// 当前登录状态
@property (nonatomic, assign, readonly) XCLoginStatus loginStatus;
/// 当前用户信息（未登录时为 nil）
@property (nonatomic, strong, readonly, nullable) XCUserInfo* currentUser;

/// 检查登录状态
- (void)checkLoginStatusWithCompletion:(void(^)(XCLoginStatus status))completion;

/// 登录（预留接口，具体实现日后添加）
/// @param account 账号
/// @param password 密码
/// @param completion 完成回调
- (void)loginWithAccount:(NSString*)account
                password:(NSString*)password
              completion:(void(^)(BOOL success, NSError* _Nullable error))completion;

/// 退出登录
- (void)logoutWithCompletion:(void(^)(BOOL success))completion;

@optional
/// 第三方登录（预留）
- (void)loginWithThirdParty:(NSString*)platform
                     token:(NSString*)token
                completion:(void(^)(BOOL success, NSError* _Nullable error))completion;

/// 刷新登录状态（Token 续期）
- (void)refreshLoginStatusWithCompletion:(void(^)(BOOL success))completion;

/// 发送验证码（预留）
- (void)sendVerificationCodeToPhone:(NSString*)phoneNumber
                         completion:(void(^)(BOOL success, NSError* _Nullable error))completion;

@end

#pragma mark - 登录状态监听协议
/// 登录状态监听协议
@protocol XCLoginStatusObserver <NSObject>

@optional
/// 登录状态改变
- (void)loginStatusDidChange:(XCLoginStatus)status;
/// 用户信息更新
- (void)userInfoDidUpdate:(XCUserInfo*)userInfo;
/// 登录过期
- (void)loginDidExpire;

@end

#pragma mark - 登录管理器（占位实现）
/// 登录管理器（占位实现，日后完善）
@interface XCLoginManager : NSObject <XCLoginManagerProtocol>

+ (instancetype)sharedManager;

#pragma mark - 观察者管理
- (void)addObserver:(id<XCLoginStatusObserver>)observer;
- (void)removeObserver:(id<XCLoginStatusObserver>)observer;

#pragma mark - 登录状态持久化（预留）
/// 保存登录状态到本地
- (void)saveLoginState;
/// 恢复登录状态
- (void)restoreLoginState;

@end

NS_ASSUME_NONNULL_END
