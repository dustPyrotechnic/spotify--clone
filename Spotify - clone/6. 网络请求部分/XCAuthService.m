//
//  XCAuthService.m
//  Spotify - clone
//

#import "XCAuthService.h"
#import <AFNetworking/AFNetworking.h>

#pragma mark - 常量

NSString * const XCAuthLoginStatusDidChangeNotification = @"XCAuthLoginStatusDidChangeNotification";

static NSString * const kAuthBaseURL        = @"http://xiaochenstudio.com/api";
static NSString * const kRefreshTokenKey    = @"XCAuth_refreshToken";
static NSString * const kUsernameKey        = @"XCAuth_username";
static NSString * const kUserIdKey          = @"XCAuth_userId";

@interface XCAuthService ()
@property (nonatomic, strong) AFHTTPSessionManager *sessionManager;
@end

@implementation XCAuthService

#pragma mark - 单例

+ (instancetype)sharedInstance {
    static XCAuthService *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[super allocWithZone:NULL] initPrivate];
    });
    return instance;
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone { return [self sharedInstance]; }
- (id)copyWithZone:(NSZone *)zone { return self; }

- (instancetype)initPrivate {
    self = [super init];
    if (self) {
        _sessionManager = [AFHTTPSessionManager manager];
        _sessionManager.requestSerializer  = [AFJSONRequestSerializer serializer];
        _sessionManager.responseSerializer = [AFJSONResponseSerializer serializer];
        _sessionManager.responseSerializer.acceptableContentTypes =
            [NSSet setWithObjects:@"application/json", @"text/json", nil];
    }
    return self;
}

#pragma mark - 状态属性

- (BOOL)isLoggedIn {
    return (self.accessToken.length > 0);
}

- (NSString *)refreshToken {
    return [[NSUserDefaults standardUserDefaults] stringForKey:kRefreshTokenKey];
}

- (NSString *)username {
    return [[NSUserDefaults standardUserDefaults] stringForKey:kUsernameKey];
}

- (NSString *)userId {
    return [[NSUserDefaults standardUserDefaults] stringForKey:kUserIdKey];
}

#pragma mark - 内部：存储 / 清除 Token

- (void)saveRefreshToken:(NSString *)refreshToken username:(NSString *)username userId:(NSString *)userId {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    if (refreshToken) [ud setObject:refreshToken forKey:kRefreshTokenKey];
    if (username)     [ud setObject:username     forKey:kUsernameKey];
    if (userId)       [ud setObject:userId       forKey:kUserIdKey];
    [ud synchronize];
}

- (void)clearAllTokens {
    self.accessToken = nil;
    self.accessTokenExpiresAt = nil;
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud removeObjectForKey:kRefreshTokenKey];
    [ud removeObjectForKey:kUsernameKey];
    [ud removeObjectForKey:kUserIdKey];
    [ud synchronize];
}

#pragma mark - 内部：配置 Authorization Header

- (void)setAuthHeader:(NSString *)token {
    if (token.length > 0) {
        NSString *value = [NSString stringWithFormat:@"Bearer %@", token];
        [self.sessionManager.requestSerializer setValue:value forHTTPHeaderField:@"Authorization"];
    } else {
        [self.sessionManager.requestSerializer setValue:nil forHTTPHeaderField:@"Authorization"];
    }
}

#pragma mark - 内部：解析 Token 过期时间（服务端返回 expiresIn 秒数）

- (void)updateExpiresAt:(id)expiresIn {
    if (!expiresIn || [expiresIn isKindOfClass:[NSNull class]]) return;
    NSTimeInterval seconds = [expiresIn doubleValue];
    if (seconds > 0) {
        self.accessTokenExpiresAt = [NSDate dateWithTimeIntervalSinceNow:seconds];
    }
}

#pragma mark - 会话恢复

- (void)restoreSessionWithCompletion:(void(^)(BOOL restored))completion {
    NSString *savedRefreshToken = self.refreshToken;
    if (!savedRefreshToken || savedRefreshToken.length == 0) {
        if (completion) completion(NO);
        return;
    }
    [self refreshTokenWithCompletion:^(BOOL success) {
        if (completion) completion(success);
    }];
}

#pragma mark - 注册

- (void)registerWithUsername:(NSString *)username
                    password:(NSString *)password
             confirmPassword:(NSString *)confirmPassword
                  completion:(void(^)(BOOL success, NSString *message))completion {
    if (!username.length || !password.length || !confirmPassword.length) {
        if (completion) completion(NO, @"请填写所有字段");
        return;
    }
    if (![password isEqualToString:confirmPassword]) {
        if (completion) completion(NO, @"两次密码不一致");
        return;
    }

    NSString *url = [NSString stringWithFormat:@"%@/v1/auth/register", kAuthBaseURL];
    NSDictionary *params = @{@"username": username, @"password": password};

    [self setAuthHeader:nil];
    [self.sessionManager POST:url parameters:params headers:nil progress:nil
        success:^(NSURLSessionDataTask *task, id responseObject) {
            NSInteger code = [responseObject[@"code"] integerValue];
            NSString *msg  = responseObject[@"message"] ?: @"注册成功";
            if (completion) completion(code == 0, msg);
        }
        failure:^(NSURLSessionDataTask *task, NSError *error) {
            NSString *msg = [self errorMessageFromTask:task error:error];
            if (completion) completion(NO, msg);
        }];
}

#pragma mark - 登录

- (void)loginWithUsername:(NSString *)username
                 password:(NSString *)password
               completion:(void(^)(BOOL success, NSDictionary * _Nullable userInfo, NSString *message))completion {
    if (!username.length || !password.length) {
        if (completion) completion(NO, nil, @"请输入用户名和密码");
        return;
    }

    NSString *url = [NSString stringWithFormat:@"%@/v1/auth/login", kAuthBaseURL];
    NSDictionary *params = @{@"username": username, @"password": password};

    [self setAuthHeader:nil];
    [self.sessionManager POST:url parameters:params headers:nil progress:nil
        success:^(NSURLSessionDataTask *task, id responseObject) {
            NSInteger code = [responseObject[@"code"] integerValue];
            NSString *msg  = responseObject[@"message"] ?: @"";
            if (code == 0) {
                NSDictionary *data        = responseObject[@"data"];
                NSString *accessToken     = data[@"accessToken"];
                NSString *refreshToken    = data[@"refreshToken"];
                NSString *uid             = data[@"userId"];
                NSString *uname           = data[@"username"];

                self.accessToken = accessToken;
                [self updateExpiresAt:data[@"expiresIn"]];
                [self saveRefreshToken:refreshToken username:uname userId:uid];

                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter]
                        postNotificationName:XCAuthLoginStatusDidChangeNotification object:nil];
                });
                if (completion) completion(YES, data, msg.length ? msg : @"登录成功");
            } else {
                if (completion) completion(NO, nil, msg.length ? msg : @"登录失败");
            }
        }
        failure:^(NSURLSessionDataTask *task, NSError *error) {
            NSString *msg = [self errorMessageFromTask:task error:error];
            if (completion) completion(NO, nil, msg);
        }];
}

#pragma mark - 登出

- (void)logoutWithCompletion:(void(^)(BOOL success))completion {
    NSString *token = self.accessToken;
    [self clearAllTokens];

    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter]
            postNotificationName:XCAuthLoginStatusDidChangeNotification object:nil];
    });

    if (!token.length) {
        if (completion) completion(YES);
        return;
    }

    NSString *url = [NSString stringWithFormat:@"%@/v1/auth/logout", kAuthBaseURL];
    [self setAuthHeader:token];
    [self.sessionManager POST:url parameters:nil headers:nil progress:nil
        success:^(NSURLSessionDataTask *task, id responseObject) {
            if (completion) completion(YES);
        }
        failure:^(NSURLSessionDataTask *task, NSError *error) {
            // 本地已清除，忽略服务端失败
            if (completion) completion(YES);
        }];
}

#pragma mark - 获取用户信息

- (void)getProfileWithCompletion:(void(^)(BOOL success, NSDictionary * _Nullable userInfo))completion {
    if (!self.accessToken.length) {
        if (completion) completion(NO, nil);
        return;
    }

    NSString *url = [NSString stringWithFormat:@"%@/v1/user/profile", kAuthBaseURL];
    [self setAuthHeader:self.accessToken];
    [self.sessionManager GET:url parameters:nil headers:nil progress:nil
        success:^(NSURLSessionDataTask *task, id responseObject) {
            NSInteger code = [responseObject[@"code"] integerValue];
            if (code == 0) {
                if (completion) completion(YES, responseObject[@"data"]);
            } else {
                // 可能 Token 过期，尝试刷新后重试
                [self refreshTokenWithCompletion:^(BOOL refreshed) {
                    if (refreshed) {
                        [self getProfileWithCompletion:completion];
                    } else {
                        if (completion) completion(NO, nil);
                    }
                }];
            }
        }
        failure:^(NSURLSessionDataTask *task, NSError *error) {
            NSHTTPURLResponse *resp = (NSHTTPURLResponse *)task.response;
            if (resp.statusCode == 401) {
                [self refreshTokenWithCompletion:^(BOOL refreshed) {
                    if (refreshed) {
                        [self getProfileWithCompletion:completion];
                    } else {
                        if (completion) completion(NO, nil);
                    }
                }];
            } else {
                if (completion) completion(NO, nil);
            }
        }];
}

#pragma mark - 刷新 Token

- (void)refreshTokenWithCompletion:(void(^)(BOOL success))completion {
    NSString *rt = self.refreshToken;
    if (!rt.length) {
        [self clearAllTokens];
        if (completion) completion(NO);
        return;
    }

    NSString *url = [NSString stringWithFormat:@"%@/v1/auth/refresh", kAuthBaseURL];
    NSDictionary *params = @{@"refreshToken": rt};

    [self setAuthHeader:nil];
    [self.sessionManager POST:url parameters:params headers:nil progress:nil
        success:^(NSURLSessionDataTask *task, id responseObject) {
            NSInteger code = [responseObject[@"code"] integerValue];
            if (code == 0) {
                NSDictionary *data     = responseObject[@"data"];
                NSString *newAccess    = data[@"accessToken"];
                NSString *newRefresh   = data[@"refreshToken"];
                NSString *uid          = data[@"userId"]   ?: self.userId;
                NSString *uname        = data[@"username"] ?: self.username;

                self.accessToken = newAccess;
                [self updateExpiresAt:data[@"expiresIn"]];
                [self saveRefreshToken:newRefresh username:uname userId:uid];
                if (completion) completion(YES);
            } else {
                [self clearAllTokens];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter]
                        postNotificationName:XCAuthLoginStatusDidChangeNotification object:nil];
                });
                if (completion) completion(NO);
            }
        }
        failure:^(NSURLSessionDataTask *task, NSError *error) {
            [self clearAllTokens];
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter]
                    postNotificationName:XCAuthLoginStatusDidChangeNotification object:nil];
            });
            if (completion) completion(NO);
        }];
}

#pragma mark - 内部工具

- (NSString *)errorMessageFromTask:(NSURLSessionDataTask *)task error:(NSError *)error {
    // 尝试从响应 Body 解析错误信息
    NSData *data = error.userInfo[AFNetworkingOperationFailingURLResponseDataErrorKey];
    if (data) {
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSString *msg = json[@"message"];
        if (msg.length) return msg;
    }
    return error.localizedDescription ?: @"网络请求失败";
}

@end
