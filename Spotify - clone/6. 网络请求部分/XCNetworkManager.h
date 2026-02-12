//
//  XCNetworkManager.h
//  Spotify - clone
//
//  网络管理单例 - 基于 AFNetworking 实现 Spotify 和网易云 API 的请求封装
//  支持 Token 自动刷新、失败重试机制，使用 KeyChain 安全存储 Token
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface XCNetworkManager : NSObject
+ (instancetype)sharedInstance;

// 使用 Client Credentials 流程获取 Spotify Token，存储到 KeyChain
- (void)getTokenWithCompletion:(void(^)(BOOL success))completion;

// 请求 Spotify 新专辑数据，使用静态变量实现失败重试计数
- (void) getDataOfAllAlbums:(NSMutableArray*) array;

// 网易云 API - 请求歌单列表，使用 YYModel 解析 JSON 到数据模型
- (void)getDataOfPlaylistsFromWY:(NSMutableArray *)array offset:(NSInteger)offset limit:(NSInteger)limit withCompletion:(void(^)(BOOL success))completion;

// 网易云 API - 请求专辑列表
- (void)getAlbumsFromWY:(NSMutableArray *)array offset:(NSInteger)offset limit:(NSInteger)limit withCompletion:(void(^)(BOOL success))completion;

// 网易云 API - 请求专辑详情，返回歌曲列表
- (void)getDetailOfAlbumFromWY:(NSMutableArray *)array ofAlbumId:(NSString*) albumId withCompletion:(void(^)(BOOL success))completion;

// 网易云 API - 获取歌曲播放 URL
- (void)findUrlOfSongWithId:(NSString *)songId completion:(void(^)(NSURL * _Nullable songUrl))completion;

#pragma mark - API Token 测试方法 (基于 docs/API_USAGE_DOCUMENTATION.md)


/// 测试1: 健康检查 (GET /test)
- (void)testAPIHealthCheckWithCompletion:(void(^)(BOOL success, NSDictionary *response, NSError *error))completion;

/// 测试2: 用户登录获取 Token (POST /v1/auth/login)
/// @param username 用户名
/// @param password 密码
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

@end

NS_ASSUME_NONNULL_END
