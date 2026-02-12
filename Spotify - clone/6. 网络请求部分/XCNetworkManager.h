//
//  XCNetworkManager.h
//  Spotify - clone
//
//  网络管理单例 - 基于 AFNetworking 实现 Spotify 和网易云 API 的请求封装
//  支持 Token 自动刷新、失败重试机制，使用 KeyChain 安全存储 Token
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - API 基础配置常量

/// API 基础 URL
extern NSString * const kAPIBaseURL;

/// KeyChain 服务名
extern NSString * const kAPIServiceName;

/// Token 存储 Key
extern NSString * const kAPIAccessTokenKey;
extern NSString * const kAPIRefreshTokenKey;

/// 测试账号
extern NSString * const kAPITestAdminUsername;
extern NSString * const kAPITestAdminPassword;
extern NSString * const kAPITestUserUsername;
extern NSString * const kAPITestUserPassword;

@interface XCNetworkManager : NSObject

+ (instancetype)sharedInstance;

#pragma mark - Spotify API

// 使用 Client Credentials 流程获取 Spotify Token，存储到 KeyChain
- (void)getTokenWithCompletion:(void(^)(BOOL success))completion;

// 请求 Spotify 新专辑数据，使用静态变量实现失败重试计数
- (void) getDataOfAllAlbums:(NSMutableArray*) array;

#pragma mark - 网易云 API

// 网易云 API - 请求歌单列表，使用 YYModel 解析 JSON 到数据模型
- (void)getDataOfPlaylistsFromWY:(NSMutableArray *)array offset:(NSInteger)offset limit:(NSInteger)limit withCompletion:(void(^)(BOOL success))completion;

// 网易云 API - 请求专辑列表
- (void)getAlbumsFromWY:(NSMutableArray *)array offset:(NSInteger)offset limit:(NSInteger)limit withCompletion:(void(^)(BOOL success))completion;

// 网易云 API - 请求专辑详情，返回歌曲列表
- (void)getDetailOfAlbumFromWY:(NSMutableArray *)array ofAlbumId:(NSString*) albumId withCompletion:(void(^)(BOOL success))completion;

// 网易云 API - 获取歌曲播放 URL
- (void)findUrlOfSongWithId:(NSString *)songId completion:(void(^)(NSURL * _Nullable songUrl))completion;

#pragma mark - API 账号认证模块 (Account Auth)

#pragma mark - Token 属性

/// 当前 API Access Token（账号登录方式）
@property (nonatomic, readonly, nullable) NSString *accountAccessToken;

/// 当前 API Refresh Token（账号登录方式）
@property (nonatomic, readonly, nullable) NSString *accountRefreshToken;

/// Token 是否有效（简单检查是否存在，不检查过期时间）
@property (nonatomic, readonly) BOOL hasAccountToken;

#pragma mark - 账号密码登录

/**
 * 使用账号密码登录
 * @param account  用户名
 * @param password 密码
 * @param completion 回调：success, accessToken, refreshToken, userInfo, error
 */
- (void)loginWithAccount:(NSString *)account
                password:(NSString *)password
              completion:(void(^)(BOOL success,
                                   NSString * _Nullable accessToken,
                                   NSString * _Nullable refreshToken,
                                   NSDictionary * _Nullable userInfo,
                                   NSError * _Nullable error))completion;

/// 退出账号登录（清除所有 Token）
- (void)authLogoutAccount;

#pragma mark - Token 管理

/// 刷新账号登录的 Access Token
- (void)authRefreshAccountTokenWithCompletion:(void(^)(BOOL success,
                                                        NSString * _Nullable newAccessToken,
                                                        NSError * _Nullable error))completion;

/// 验证当前账号 Token 是否有效
- (void)authValidateAccountTokenWithCompletion:(void(^)(BOOL isValid,
                                                         NSDictionary * _Nullable tokenInfo,
                                                         NSError * _Nullable error))completion;

#pragma mark - 用户信息

/// 获取当前登录账号的用户信息
- (void)userGetProfileWithCompletion:(void(^)(BOOL success,
                                               NSDictionary * _Nullable userInfo,
                                               NSError * _Nullable error))completion;

#pragma mark - 管理员接口

/// 获取管理员面板数据（需要 admin 角色）
- (void)adminGetDashboardWithCompletion:(void(^)(BOOL success,
                                                  NSDictionary * _Nullable data,
                                                  NSError * _Nullable error))completion;

#pragma mark - API 通用请求 (General Request)

/**
 * 通用 API 请求（自动处理账号 Token 刷新）
 * @param path         API 路径（如 /v1/user/profile）
 * @param method       HTTP 方法（GET/POST/PUT/DELETE）
 * @param parameters   请求参数
 * @param authType     认证类型：0=无需认证, 1=账号Token
 * @param completion   回调
 */
- (void)apiRequestWithPath:(NSString *)path
                    method:(NSString *)method
                parameters:(nullable NSDictionary *)parameters
                  authType:(NSInteger)authType
                completion:(void(^)(BOOL success,
                                    id _Nullable responseObject,
                                    NSError * _Nullable error))completion;

/// 快速 GET 请求（无需认证）
- (void)apiGet:(NSString *)path
    parameters:(nullable NSDictionary *)parameters
    completion:(void(^)(BOOL success, id _Nullable response, NSError * _Nullable error))completion;

/// 快速 GET 请求（需要账号认证）
- (void)apiGetWithAccountAuth:(NSString *)path
                   parameters:(nullable NSDictionary *)parameters
                   completion:(void(^)(BOOL success, id _Nullable response, NSError * _Nullable error))completion;

/// 快速 POST 请求（无需认证）
- (void)apiPost:(NSString *)path
     parameters:(nullable NSDictionary *)parameters
     completion:(void(^)(BOOL success, id _Nullable response, NSError * _Nullable error))completion;

/// 快速 POST 请求（需要账号认证）
- (void)apiPostWithAccountAuth:(NSString *)path
                    parameters:(nullable NSDictionary *)parameters
                    completion:(void(^)(BOOL success, id _Nullable response, NSError * _Nullable error))completion;

#pragma mark - 工具方法 (Utilities)

/// API 服务健康检查
- (void)utilCheckAPIHealthWithCompletion:(void(^)(BOOL success,
                                                   NSDictionary * _Nullable response,
                                                   NSError * _Nullable error))completion;

/// 打印当前存储的账号认证状态（调试用）
- (void)utilPrintAccountAuthStatus;

#pragma mark - 测试方法 (保留)

/// 测试1: 健康检查 (GET /test)
- (void)testAPIHealthCheckWithCompletion:(void(^)(BOOL success, NSDictionary *response, NSError *error))completion;

/// 测试2: 用户登录获取 Token (POST /v1/auth/login)
- (void)testAPILoginWithUsername:(NSString *)username
                        password:(NSString *)password
                      completion:(void(^)(BOOL success, NSString *accessToken, NSString *refreshToken, NSDictionary *userInfo, NSError *error))completion;

/// 测试3: 验证当前 Token 是否有效 (GET /v1/auth/validate)
- (void)testAPIValidateTokenWithCompletion:(void(^)(BOOL isValid, NSDictionary *tokenInfo, NSInteger code, NSError *error))completion;

/// 测试4: 获取用户信息 (GET /v1/user/profile)
- (void)testAPIGetUserProfileWithCompletion:(void(^)(BOOL success, NSDictionary *userInfo, NSError *error))completion;

/// 测试5: 刷新 Token (POST /v1/auth/refresh)
- (void)testAPIRefreshTokenWithCompletion:(void(^)(BOOL success, NSString *newAccessToken, NSString *newRefreshToken, NSError *error))completion;

/// 测试6: 管理员面板访问测试 (GET /v1/admin/dashboard)
- (void)testAPIAdminDashboardWithCompletion:(void(^)(BOOL success, NSDictionary *data, NSError *error))completion;

/// 测试7: 完整流程测试 (登录 -> 验证 -> 获取用户信息)
- (void)testAPIFullFlowWithCompletion:(void(^)(BOOL success, NSString *message))completion;

/// 测试8: 清除存储的 Token
- (void)testAPIClearStoredTokens;

/// 测试9: 获取当前存储的 Access Token
- (NSString *)testAPIGetStoredAccessToken;

/// 测试10: 获取当前存储的 Refresh Token
- (NSString *)testAPIGetStoredRefreshToken;

#pragma mark - 预留：其他登录方式 (Future)

/*
 * 后续可添加的登录方式：
 *
 * 手机号登录
 * - (void)loginWithPhone:(NSString *)phone
 *          verifyCode:(NSString *)code
 *          completion:(void(^)(...))completion;
 *
 * 微信登录
 * - (void)loginWithWeChatAuthCode:(NSString *)authCode
 *                    completion:(void(^)(...))completion;
 *
 * Apple ID 登录
 * - (void)loginWithAppleIdentityToken:(NSString *)identityToken
 *                        completion:(void(^)(...))completion;
 */

@end

NS_ASSUME_NONNULL_END
