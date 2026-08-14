//
//  XCAuthService.h
//  Spotify - clone
//
//  独立认证服务，不依赖 XCNetworkManager
//  双 Token：accessToken（内存）+ refreshToken（NSUserDefaults）
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 登录状态变更通知（登录成功 / 登出后发送）
extern NSString * const XCAuthLoginStatusDidChangeNotification;

@interface XCAuthService : NSObject

+ (instancetype)sharedInstance;

#pragma mark - 状态属性

/// 是否已登录（refreshToken 存在且 accessToken 有效）
@property (nonatomic, readonly) BOOL isLoggedIn;

/// 内存中的 accessToken（不持久化，App 重启后通过 restoreSession 恢复）
@property (nonatomic, strong, nullable) NSString *accessToken;

/// 持久化的 refreshToken（NSUserDefaults）
@property (nonatomic, readonly, nullable) NSString *refreshToken;

/// accessToken 过期时间
@property (nonatomic, strong, nullable) NSDate *accessTokenExpiresAt;

/// 当前登录用户名
@property (nonatomic, readonly, nullable) NSString *username;

/// 当前登录用户 ID
@property (nonatomic, readonly, nullable) NSString *userId;

#pragma mark - 会话恢复

/// App 启动时调用，用 refreshToken 恢复登录态
- (void)restoreSessionWithCompletion:(void(^)(BOOL restored))completion;

#pragma mark - 核心认证操作

- (void)registerWithUsername:(NSString *)username
                    password:(NSString *)password
             confirmPassword:(NSString *)confirmPassword
                  completion:(void(^)(BOOL success, NSString *message))completion;

- (void)loginWithUsername:(NSString *)username
                 password:(NSString *)password
               completion:(void(^)(BOOL success, NSDictionary * _Nullable userInfo, NSString *message))completion;

- (void)logoutWithCompletion:(void(^)(BOOL success))completion;

- (void)getProfileWithCompletion:(void(^)(BOOL success, NSDictionary * _Nullable userInfo))completion;

- (void)refreshTokenWithCompletion:(void(^)(BOOL success))completion;

@end

NS_ASSUME_NONNULL_END
