//
//  XCNetworkManager.m
//  Spotify - clone
//

#import "XCNetworkManager.h"
#import "XCAlbumSimpleData.h"
#import "XC-YYAlbumData.h"
#import "XC-YYSongData.h"
#import <AFNetworking/AFNetworking.h>
#import <UICKeyChainStore/UICKeyChainStore.h>

#pragma mark - 常量定义

// API 基础配置
NSString * const kAPIBaseURL = @"https://ding.liujiong.com/api";
NSString * const kAPIServiceName = @"com.spotify.clone.api";
NSString * const kAPIAccessTokenKey = @"api_access_token";
NSString * const kAPIRefreshTokenKey = @"api_refresh_token";

// 测试账号
NSString * const kAPITestAdminUsername = @"admin";
NSString * const kAPITestAdminPassword = @"admin123";
NSString * const kAPITestUserUsername = @"testuser";
NSString * const kAPITestUserPassword = @"user123";

@implementation XCNetworkManager

static XCNetworkManager *instance = nil;

#pragma mark - 单例实现

// 饿汉式单例，类加载时创建实例
+ (void)load {
    instance = [[super allocWithZone:NULL] init];
}

+ (instancetype)sharedInstance {
    return instance;
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    return [self sharedInstance];
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

- (id)mutableCopyWithZone:(NSZone *)zone {
    return self;
}

#pragma mark - Spotify API

// 使用静态局部变量实现递归重试计数，最多重试 3 次
- (void)getTokenWithCompletion:(void(^)(BOOL success))completion {
    static NSInteger tokenTimes = 0;
    NSString *url = @"https://accounts.spotify.com/api/token";
    NSDictionary *params = @{
        @"grant_type": @"client_credentials",
        @"client_id": @"183f5d912f4448519ba2d88416b3ddb1",
        @"client_secret": @"8e3f600ff28940a397b24bcc96faa5ae"
    };
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    [manager POST:url
       parameters:params
          headers:nil
         progress:nil
          success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        tokenTimes = 0;
        [UICKeyChainStore setString:responseObject[@"access_token"] forKey:@"token" service:@"com.spotify.clone"];
        if (completion) completion(YES);
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)task.response;
        NSInteger statusCode = httpResponse.statusCode;
        if (tokenTimes < 3) {
            tokenTimes += 1;
            [self getTokenWithCompletion:completion];
        } else {
            tokenTimes = 0;
            if (completion) completion(NO);
        }
    }];
}

// 使用静态局部变量实现失败重试，401 时自动刷新 Token，最多重试 10 次
- (void)getDataOfAllAlbums:(NSMutableArray *)array {
    static NSInteger dataTimes = 0;
    NSString *token = [UICKeyChainStore stringForKey:@"token" service:@"com.spotify.clone"];
    // Token 不存在时先获取 Token，成功后递归调用自身
    if (!token || token.length == 0) {
        [self getTokenWithCompletion:^(BOOL success) {
            if (success) {
                [self getDataOfAllAlbums:array];
            }
        }];
        return;
    }
    NSString *baseUrl = @"https://api.spotify.com/v1/browse/new-releases";
    NSString *header = [NSString stringWithFormat:@"Bearer %@", token];
    NSDictionary *params = @{
        @"limit" : @50,
        @"offset" : @0
    };
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    [manager.requestSerializer setValue:header forHTTPHeaderField:@"Authorization"];
    [manager GET:baseUrl
      parameters:params
         headers:nil
        progress:nil
         success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        dataTimes = 0;
        NSDictionary *rootDict = (NSDictionary *)responseObject;
        if (!rootDict) return;
        NSDictionary *albumsDict = rootDict[@"albums"];
        if (!albumsDict) return;
        NSArray *items = albumsDict[@"items"];
        if (!items || items.count == 0) return;
        [array removeAllObjects];
        NSMutableArray *currentGroup = nil;
        // 每 10 个专辑分为一组，最多 5 组
        for (int i = 0; i < items.count; i++) {
            if (i % 10 == 0) {
                if (array.count >= 5) break;
                currentGroup = [[NSMutableArray alloc] init];
                [array addObject:currentGroup];
            }
            NSDictionary *albumData = items[i];
            if (!albumData || ![albumData isKindOfClass:[NSDictionary class]]) continue;
            XCAlbumSimpleData *album = [[XCAlbumSimpleData alloc] init];
            NSArray *images = albumData[@"images"];
            if (images && images.count > 0 && [images[0] isKindOfClass:[NSDictionary class]]) {
                album.imageURL = images[0][@"url"];
            }
            album.nameAlbum = albumData[@"name"] ?: @"未知专辑";
            album.idOfAlbum = albumData[@"id"] ?: @"";
            [currentGroup addObject:album];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"HomePageDataLoaded" object:nil];
        });
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)task.response;
        NSInteger statusCode = httpResponse.statusCode;
        // 401 表示 Token 过期，刷新后重试
        if (statusCode == 401) {
            [self getTokenWithCompletion:^(BOOL success) {
                if (success) {
                    dataTimes = 0;
                    [self getDataOfAllAlbums:array];
                }
            }];
            return;
        }
        // 其他错误使用延时递归重试
        if (dataTimes < 10) {
            dataTimes += 1;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self getDataOfAllAlbums:array];
            });
        } else {
            dataTimes = 0;
        }
    }];
}

#pragma mark - 网易云 API

// 使用 AFNetworking GET 请求，YYModel 自动解析 JSON 到模型数组
- (void)getDataOfPlaylistsFromWY:(NSMutableArray *)array offset:(NSInteger)offset limit:(NSInteger)limit withCompletion:(void(^)(BOOL success))completion {
    NSString *baseUrl = @"https://1390963969-2g6ivueiij.ap-guangzhou.tencentscf.com";
    NSString *requestUrl = [NSString stringWithFormat:@"%@/top/playlist", baseUrl];
    NSDictionary *params = @{
        @"limit" : @(limit),
        @"offset" : @(offset)
    };
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript", @"text/html", @"text/plain", nil];
    [manager GET:requestUrl
      parameters:params
         headers:nil
        progress:nil
         success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        if (![responseObject isKindOfClass:[NSDictionary class]]) {
            if (completion) completion(NO);
            return;
        }
        NSArray *playlistsJSON = responseObject[@"playlists"];
        if (playlistsJSON) {
            NSArray<XC_YYAlbumData *> *newAlbums = [NSArray yy_modelArrayWithClass:[XC_YYAlbumData class] json:playlistsJSON];
            [array removeAllObjects];
            [array addObjectsFromArray:newAlbums];
            if (completion) completion(YES);
        } else {
            if (completion) completion(NO);
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        if (completion) completion(NO);
    }];
}

- (void)getAlbumsFromWY:(NSMutableArray *)array offset:(NSInteger)offset limit:(NSInteger)limit withCompletion:(void(^)(BOOL success))completion {
    NSString *baseUrl = @"https://1390963969-2g6ivueiij.ap-guangzhou.tencentscf.com";
    NSString *requestUrl = [NSString stringWithFormat:@"%@/album/list", baseUrl];
    NSDictionary *params = @{
        @"limit" : @(limit),
        @"offset" : @(offset)
    };
    AFHTTPSessionManager* manager = [AFHTTPSessionManager manager];
    manager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript", @"text/html", @"text/plain", nil];
    [manager GET:requestUrl
      parameters:params
         headers:nil
        progress:nil
         success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        if (![responseObject isKindOfClass:[NSDictionary class]]) {
            completion(NO);
            return;
        }
        NSArray* playlistsJSON = responseObject[@"products"];
        if (playlistsJSON) {
            NSArray<XC_YYAlbumData *> *newAlbums = [NSArray yy_modelArrayWithClass:[XC_YYAlbumData class] json:playlistsJSON];
            [array removeAllObjects];
            [array addObjectsFromArray:newAlbums];
            if (completion) completion(YES);
        } else {
            if (completion) completion(NO);
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        if (completion) completion(NO);
    }];
}

- (void)getDetailOfAlbumFromWY:(NSMutableArray *)array ofAlbumId:(NSString*) albumId withCompletion:(void(^)(BOOL success))completion {
    NSString *baseUrl = @"https://1390963969-2g6ivueiij.ap-guangzhou.tencentscf.com";
    NSString *requestUrl = [NSString stringWithFormat:@"%@/album", baseUrl];
    NSDictionary *params = @{@"id" : albumId};
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript", @"text/html", @"text/plain", nil];
    [manager GET:requestUrl parameters:params headers:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        if (![responseObject isKindOfClass:[NSDictionary class]]) {
            if (completion) completion(NO);
            return;
        }
        NSArray *songsJSON = responseObject[@"songs"];
        if (songsJSON) {
            NSArray<XC_YYSongData *> *newSongs = [NSArray yy_modelArrayWithClass:[XC_YYSongData class] json:songsJSON];
            [array removeAllObjects];
            [array addObjectsFromArray:newSongs];
            if (completion) completion(YES);
        } else {
            if (completion) completion(NO);
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        if (completion) completion(NO);
    }];
}

#pragma mark - 歌曲操作

// 请求歌曲播放 URL，处理 URL 为空的情况（版权或付费限制）
- (void)findUrlOfSongWithId:(NSString *)songId completion:(void(^)(NSURL * _Nullable songUrl))completion {
    NSString *baseUrl = @"https://1390963969-2g6ivueiij.ap-guangzhou.tencentscf.com";
    NSString *requestUrl = [NSString stringWithFormat:@"%@/song/url/v1", baseUrl];
    NSDictionary *params = @{
        @"id" : songId,
        @"level": @"standard"
    };
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript", @"text/html", @"text/plain", nil];
    [manager GET:requestUrl parameters:params headers:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id _Nullable responseObject) {
        NSArray *data = responseObject[@"data"];
        if (data && data.count > 0) {
            NSDictionary *songInfo = data.firstObject;
            NSString *urlString = songInfo[@"url"];
            if (urlString && ![urlString isKindOfClass:[NSNull class]]) {
                NSURL *finalUrl = [NSURL URLWithString:urlString];
                if (completion) completion(finalUrl);
            } else {
                if (completion) completion(nil);
            }
        } else {
            if (completion) completion(nil);
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        if (completion) completion(nil);
    }];
}

#pragma mark - Token 属性实现

- (NSString *)accountAccessToken {
    return [UICKeyChainStore stringForKey:kAPIAccessTokenKey service:kAPIServiceName];
}

- (NSString *)accountRefreshToken {
    return [UICKeyChainStore stringForKey:kAPIRefreshTokenKey service:kAPIServiceName];
}

- (BOOL)hasAccountToken {
    NSString *token = [self accountAccessToken];
    return (token && token.length > 0);
}

#pragma mark - 账号密码登录

- (void)loginWithAccount:(NSString *)account
                password:(NSString *)password
              completion:(void(^)(BOOL success,
                                   NSString * _Nullable accessToken,
                                   NSString * _Nullable refreshToken,
                                   NSDictionary * _Nullable userInfo,
                                   NSError * _Nullable error))completion {
    NSString *url = [NSString stringWithFormat:@"%@/v1/auth/login", kAPIBaseURL];
    NSDictionary *params = @{
        @"username": account,
        @"password": password
    };
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.requestSerializer = [AFJSONRequestSerializer serializer];
    manager.responseSerializer = [AFJSONResponseSerializer serializer];
    [manager.requestSerializer setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    [manager POST:url
       parameters:params
          headers:nil
         progress:nil
          success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        if (![responseObject isKindOfClass:[NSDictionary class]]) {
            NSError *error = [NSError errorWithDomain:@"APIError" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"响应格式错误"}];
            if (completion) completion(NO, nil, nil, nil, error);
            return;
        }
        
        NSInteger code = [responseObject[@"code"] integerValue];
        NSString *message = responseObject[@"message"] ?: @"unknown";
        
        if (code == 0) {
            NSDictionary *data = responseObject[@"data"];
            NSString *accessToken = data[@"accessToken"];
            NSString *refreshToken = data[@"refreshToken"];
            
            // 存储到 KeyChain
            [UICKeyChainStore setString:accessToken forKey:kAPIAccessTokenKey service:kAPIServiceName];
            [UICKeyChainStore setString:refreshToken forKey:kAPIRefreshTokenKey service:kAPIServiceName];
            
            if (completion) completion(YES, accessToken, refreshToken, data, nil);
        } else {
            NSError *error = [NSError errorWithDomain:@"APIError" code:code userInfo:@{NSLocalizedDescriptionKey: message}];
            if (completion) completion(NO, nil, nil, nil, error);
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        if (completion) completion(NO, nil, nil, nil, error);
    }];
}

- (void)authLogoutAccount {
    [UICKeyChainStore removeItemForKey:kAPIAccessTokenKey service:kAPIServiceName];
    [UICKeyChainStore removeItemForKey:kAPIRefreshTokenKey service:kAPIServiceName];
}

#pragma mark - Token 管理

- (void)authRefreshAccountTokenWithCompletion:(void(^)(BOOL success,
                                                        NSString * _Nullable newAccessToken,
                                                        NSError * _Nullable error))completion {
    NSString *refreshToken = [self accountRefreshToken];
    
    if (!refreshToken || refreshToken.length == 0) {
        NSError *error = [NSError errorWithDomain:@"APIError" code:401 userInfo:@{NSLocalizedDescriptionKey: @"无刷新令牌"}];
        if (completion) completion(NO, nil, error);
        return;
    }
    
    NSString *url = [NSString stringWithFormat:@"%@/v1/auth/refresh", kAPIBaseURL];
    NSDictionary *params = @{@"refreshToken": refreshToken};
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.requestSerializer = [AFJSONRequestSerializer serializer];
    manager.responseSerializer = [AFJSONResponseSerializer serializer];
    [manager.requestSerializer setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    [manager POST:url
       parameters:params
          headers:nil
         progress:nil
          success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        NSInteger code = [responseObject[@"code"] integerValue];
        
        if (code == 0) {
            NSDictionary *data = responseObject[@"data"];
            NSString *newAccessToken = data[@"accessToken"];
            NSString *newRefreshToken = data[@"refreshToken"];
            
            // 更新存储
            [UICKeyChainStore setString:newAccessToken forKey:kAPIAccessTokenKey service:kAPIServiceName];
            [UICKeyChainStore setString:newRefreshToken forKey:kAPIRefreshTokenKey service:kAPIServiceName];
            
            if (completion) completion(YES, newAccessToken, nil);
        } else {
            // 刷新失败，清除 Token
            [self authLogoutAccount];
            NSString *message = responseObject[@"message"] ?: @"刷新失败";
            NSError *error = [NSError errorWithDomain:@"APIError" code:code userInfo:@{NSLocalizedDescriptionKey: message}];
            if (completion) completion(NO, nil, error);
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        if (completion) completion(NO, nil, error);
    }];
}

- (void)authValidateAccountTokenWithCompletion:(void(^)(BOOL isValid,
                                                         NSDictionary * _Nullable tokenInfo,
                                                         NSError * _Nullable error))completion {
    NSString *accessToken = [self accountAccessToken];
    
    if (!accessToken || accessToken.length == 0) {
        NSError *error = [NSError errorWithDomain:@"APIError" code:401 userInfo:@{NSLocalizedDescriptionKey: @"未登录"}];
        if (completion) completion(NO, nil, error);
        return;
    }
    
    NSString *url = [NSString stringWithFormat:@"%@/v1/auth/validate", kAPIBaseURL];
    NSString *authHeader = [NSString stringWithFormat:@"Bearer %@", accessToken];
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.requestSerializer = [AFJSONRequestSerializer serializer];
    manager.responseSerializer = [AFJSONResponseSerializer serializer];
    [manager.requestSerializer setValue:authHeader forHTTPHeaderField:@"Authorization"];
    
    [manager GET:url
      parameters:nil
         headers:nil
        progress:nil
         success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        NSInteger code = [responseObject[@"code"] integerValue];
        
        if (code == 0) {
            NSDictionary *data = responseObject[@"data"];
            if (completion) completion(YES, data, nil);
        } else {
            NSString *message = responseObject[@"message"] ?: @"Token 无效";
            NSError *error = [NSError errorWithDomain:@"APIError" code:code userInfo:@{NSLocalizedDescriptionKey: message}];
            if (completion) completion(NO, nil, error);
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        if (completion) completion(NO, nil, error);
    }];
}

#pragma mark - 用户信息

- (void)userGetProfileWithCompletion:(void(^)(BOOL success,
                                               NSDictionary * _Nullable userInfo,
                                               NSError * _Nullable error))completion {
    NSString *url = [NSString stringWithFormat:@"%@/v1/user/profile", kAPIBaseURL];
    
    [self apiGetWithAccountAuth:url parameters:nil completion:^(BOOL success, id _Nullable response, NSError * _Nullable error) {
        if (success && [response isKindOfClass:[NSDictionary class]]) {
            NSInteger code = [response[@"code"] integerValue];
            if (code == 0) {
                if (completion) completion(YES, response[@"data"], nil);
            } else {
                NSString *message = response[@"message"] ?: @"获取失败";
                NSError *err = [NSError errorWithDomain:@"APIError" code:code userInfo:@{NSLocalizedDescriptionKey: message}];
                if (completion) completion(NO, nil, err);
            }
        } else {
            if (completion) completion(NO, nil, error);
        }
    }];
}

#pragma mark - 管理员接口

- (void)adminGetDashboardWithCompletion:(void(^)(BOOL success,
                                                  NSDictionary * _Nullable data,
                                                  NSError * _Nullable error))completion {
    NSString *url = [NSString stringWithFormat:@"%@/v1/admin/dashboard", kAPIBaseURL];
    
    [self apiGetWithAccountAuth:url parameters:nil completion:^(BOOL success, id _Nullable response, NSError * _Nullable error) {
        if (success && [response isKindOfClass:[NSDictionary class]]) {
            NSInteger code = [response[@"code"] integerValue];
            if (code == 0) {
                if (completion) completion(YES, response[@"data"], nil);
            } else {
                NSString *message = response[@"message"] ?: @"获取失败";
                NSError *err = [NSError errorWithDomain:@"APIError" code:code userInfo:@{NSLocalizedDescriptionKey: message}];
                if (completion) completion(NO, nil, err);
            }
        } else {
            if (completion) completion(NO, nil, error);
        }
    }];
}

#pragma mark - API 通用请求

- (void)apiRequestWithPath:(NSString *)path
                    method:(NSString *)method
                parameters:(nullable NSDictionary *)parameters
                  authType:(NSInteger)authType
                completion:(void(^)(BOOL success,
                                    id _Nullable responseObject,
                                    NSError * _Nullable error))completion {
    NSString *url = [NSString stringWithFormat:@"%@%@", kAPIBaseURL, path];
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.requestSerializer = [AFJSONRequestSerializer serializer];
    manager.responseSerializer = [AFJSONResponseSerializer serializer];
    
    // 添加认证头
    if (authType == 1) { // 账号 Token 认证
        NSString *accessToken = [self accountAccessToken];
        if (accessToken) {
            NSString *authHeader = [NSString stringWithFormat:@"Bearer %@", accessToken];
            [manager.requestSerializer setValue:authHeader forHTTPHeaderField:@"Authorization"];
        }
    }
    
    void (^successBlock)(NSURLSessionDataTask *, id) = ^(NSURLSessionDataTask *task, id responseObject) {
        if (completion) completion(YES, responseObject, nil);
    };
    
    void (^failureBlock)(NSURLSessionDataTask *, NSError *) = ^(NSURLSessionDataTask *task, NSError *error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)task.response;
        NSInteger statusCode = httpResponse.statusCode;
        
        // 401 且是账号认证，尝试刷新 Token
        if (statusCode == 401 && authType == 1) {
            // 这里可以实现自动刷新逻辑
            // 简单起见，直接返回错误
        }
        
        if (completion) completion(NO, nil, error);
    };
    
    if ([method.uppercaseString isEqualToString:@"GET"]) {
        [manager GET:url parameters:parameters headers:nil progress:nil success:successBlock failure:failureBlock];
    } else if ([method.uppercaseString isEqualToString:@"POST"]) {
        [manager POST:url parameters:parameters headers:nil progress:nil success:successBlock failure:failureBlock];
    } else if ([method.uppercaseString isEqualToString:@"PUT"]) {
        [manager PUT:url parameters:parameters headers:nil success:successBlock failure:failureBlock];
    } else if ([method.uppercaseString isEqualToString:@"DELETE"]) {
        [manager DELETE:url parameters:parameters headers:nil success:successBlock failure:failureBlock];
    } else {
        NSError *error = [NSError errorWithDomain:@"APIError" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"不支持的 HTTP 方法"}];
        if (completion) completion(NO, nil, error);
    }
}

- (void)apiGet:(NSString *)path
    parameters:(nullable NSDictionary *)parameters
    completion:(void(^)(BOOL success, id _Nullable response, NSError * _Nullable error))completion {
    [self apiRequestWithPath:path method:@"GET" parameters:parameters authType:0 completion:completion];
}

- (void)apiGetWithAccountAuth:(NSString *)path
                   parameters:(nullable NSDictionary *)parameters
                   completion:(void(^)(BOOL success, id _Nullable response, NSError * _Nullable error))completion {
    [self apiRequestWithPath:path method:@"GET" parameters:parameters authType:1 completion:completion];
}

- (void)apiPost:(NSString *)path
     parameters:(nullable NSDictionary *)parameters
     completion:(void(^)(BOOL success, id _Nullable response, NSError * _Nullable error))completion {
    [self apiRequestWithPath:path method:@"POST" parameters:parameters authType:0 completion:completion];
}

- (void)apiPostWithAccountAuth:(NSString *)path
                    parameters:(nullable NSDictionary *)parameters
                    completion:(void(^)(BOOL success, id _Nullable response, NSError * _Nullable error))completion {
    [self apiRequestWithPath:path method:@"POST" parameters:parameters authType:1 completion:completion];
}

#pragma mark - 工具方法

- (void)utilCheckAPIHealthWithCompletion:(void(^)(BOOL success,
                                                   NSDictionary * _Nullable response,
                                                   NSError * _Nullable error))completion {
    [self apiGet:@"/test" parameters:nil completion:completion];
}

- (void)utilPrintAccountAuthStatus {
    NSLog(@"========== 账号认证状态 ==========");
    NSLog(@"Access Token: %@", self.accountAccessToken ? @"✅ 存在" : @"❌ 不存在");
    if (self.accountAccessToken) {
        NSLog(@"Token 预览: %@...", [self.accountAccessToken substringToIndex:MIN(20, self.accountAccessToken.length)]);
    }
    NSLog(@"Refresh Token: %@", self.accountRefreshToken ? @"✅ 存在" : @"❌ 不存在");
    NSLog(@"================================");
}

#pragma mark - API 测试方法 (保留)

- (void)testAPIHealthCheckWithCompletion:(void(^)(BOOL success, NSDictionary *response, NSError *error))completion {
    NSLog(@"\n========== [APITest] 开始健康检查测试 ==========");
    NSLog(@"[APITest] 请求: GET %@/test", kAPIBaseURL);
    
    NSString *url = [NSString stringWithFormat:@"%@/test", kAPIBaseURL];
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.requestSerializer = [AFJSONRequestSerializer serializer];
    manager.responseSerializer = [AFJSONResponseSerializer serializer];
    
    NSDate *startTime = [NSDate date];
    
    [manager GET:url
      parameters:nil
         headers:nil
        progress:nil
         success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:startTime];
        NSLog(@"[APITest] ✅ 健康检查成功！耗时: %.3f秒", elapsed);
        
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            NSLog(@"[APITest] 响应数据: %@", responseObject);
            if (completion) completion(YES, responseObject, nil);
        } else {
            if (completion) completion(YES, nil, nil);
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:startTime];
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)task.response;
        NSLog(@"[APITest] ❌ 健康检查失败！耗时: %.3f秒, HTTP %ld", elapsed, (long)httpResponse.statusCode);
        if (completion) completion(NO, nil, error);
    }];
}

- (void)testAPILoginWithUsername:(NSString *)username
                        password:(NSString *)password
                      completion:(void(^)(BOOL success, NSString *accessToken, NSString *refreshToken, NSDictionary *userInfo, NSError *error))completion {
    NSLog(@"\n========== [APITest] 开始登录测试 ==========");
    NSLog(@"[APITest] 请求: POST %@/v1/auth/login", kAPIBaseURL);
    NSLog(@"[APITest] 用户名: %@", username);
    
    NSString *url = [NSString stringWithFormat:@"%@/v1/auth/login", kAPIBaseURL];
    NSDictionary *params = @{
        @"username": username,
        @"password": password
    };
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.requestSerializer = [AFJSONRequestSerializer serializer];
    manager.responseSerializer = [AFJSONResponseSerializer serializer];
    [manager.requestSerializer setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    NSDate *startTime = [NSDate date];
    
    [manager POST:url
       parameters:params
          headers:nil
         progress:nil
          success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:startTime];
        
        if (![responseObject isKindOfClass:[NSDictionary class]]) {
            NSLog(@"[APITest] ❌ 响应格式错误");
            NSError *error = [NSError errorWithDomain:@"APITestError" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"响应格式错误"}];
            if (completion) completion(NO, nil, nil, nil, error);
            return;
        }
        
        NSInteger code = [responseObject[@"code"] integerValue];
        NSString *message = responseObject[@"message"] ?: @"unknown";
        
        if (code == 0) {
            NSDictionary *data = responseObject[@"data"];
            NSString *accessToken = data[@"accessToken"];
            NSString *refreshToken = data[@"refreshToken"];
            NSNumber *expiresAt = data[@"expiresAt"];
            
            NSLog(@"[APITest] ✅ 登录成功！耗时: %.3f秒", elapsed);
            NSLog(@"[APITest] Access Token: %@...", [accessToken substringToIndex:MIN(20, accessToken.length)]);
            NSLog(@"[APITest] Refresh Token: %@...", [refreshToken substringToIndex:MIN(20, refreshToken.length)]);
            NSLog(@"[APITest] 过期时间戳: %@", expiresAt);
            
            // 存储到 KeyChain
            [UICKeyChainStore setString:accessToken forKey:kAPIAccessTokenKey service:kAPIServiceName];
            [UICKeyChainStore setString:refreshToken forKey:kAPIRefreshTokenKey service:kAPIServiceName];
            NSLog(@"[APITest] Token 已存储到 KeyChain");
            
            if (completion) completion(YES, accessToken, refreshToken, data, nil);
        } else {
            NSLog(@"[APITest] ❌ 登录失败！Code: %ld, Message: %@", (long)code, message);
            NSError *error = [NSError errorWithDomain:@"APITestError" code:code userInfo:@{NSLocalizedDescriptionKey: message}];
            if (completion) completion(NO, nil, nil, nil, error);
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:startTime];
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)task.response;
        NSLog(@"[APITest] ❌ 网络请求失败！耗时: %.3f秒, HTTP %ld", elapsed, (long)httpResponse.statusCode);
        NSLog(@"[APITest] 错误: %@", error.localizedDescription);
        if (completion) completion(NO, nil, nil, nil, error);
    }];
}

- (void)testAPIValidateTokenWithCompletion:(void(^)(BOOL isValid, NSDictionary *tokenInfo, NSInteger code, NSError *error))completion {
    NSLog(@"\n========== [APITest] 开始 Token 验证测试 ==========");
    NSLog(@"[APITest] 请求: GET %@/v1/auth/validate", kAPIBaseURL);
    
    NSString *accessToken = [UICKeyChainStore stringForKey:kAPIAccessTokenKey service:kAPIServiceName];
    
    if (!accessToken || accessToken.length == 0) {
        NSLog(@"[APITest] ⚠️ 未找到 Access Token，请先登录");
        NSError *error = [NSError errorWithDomain:@"APITestError" code:401 userInfo:@{NSLocalizedDescriptionKey: @"未登录"}];
        if (completion) completion(NO, nil, 401, error);
        return;
    }
    
    NSLog(@"[APITest] 使用 Token: %@...", [accessToken substringToIndex:MIN(20, accessToken.length)]);
    
    NSString *url = [NSString stringWithFormat:@"%@/v1/auth/validate", kAPIBaseURL];
    NSString *authHeader = [NSString stringWithFormat:@"Bearer %@", accessToken];
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.requestSerializer = [AFJSONRequestSerializer serializer];
    manager.responseSerializer = [AFJSONResponseSerializer serializer];
    [manager.requestSerializer setValue:authHeader forHTTPHeaderField:@"Authorization"];
    
    NSDate *startTime = [NSDate date];
    
    [manager GET:url
      parameters:nil
         headers:nil
        progress:nil
         success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:startTime];
        
        NSInteger code = [responseObject[@"code"] integerValue];
        
        if (code == 0) {
            NSDictionary *data = responseObject[@"data"];
            NSLog(@"[APITest] ✅ Token 验证成功！耗时: %.3f秒", elapsed);
            NSLog(@"[APITest] Token 信息: %@", data);
            if (completion) completion(YES, data, code, nil);
        } else {
            NSString *message = responseObject[@"message"] ?: @"Token 无效";
            NSLog(@"[APITest] ❌ Token 验证失败！Code: %ld, Message: %@", (long)code, message);
            NSError *error = [NSError errorWithDomain:@"APITestError" code:code userInfo:@{NSLocalizedDescriptionKey: message}];
            if (completion) completion(NO, nil, code, error);
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:startTime];
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)task.response;
        NSInteger statusCode = httpResponse.statusCode;
        
        NSLog(@"[APITest] ❌ Token 验证请求失败！耗时: %.3f秒, HTTP %ld", elapsed, (long)statusCode);
        
        if (statusCode == 401) {
            NSLog(@"[APITest] ⚠️ Token 已过期或无效 (401)");
        }
        
        if (completion) completion(NO, nil, statusCode, error);
    }];
}

- (void)testAPIGetUserProfileWithCompletion:(void(^)(BOOL success, NSDictionary *userInfo, NSError *error))completion {
    NSLog(@"\n========== [APITest] 开始获取用户信息测试 ==========");
    NSLog(@"[APITest] 请求: GET %@/v1/user/profile", kAPIBaseURL);
    
    NSString *accessToken = [UICKeyChainStore stringForKey:kAPIAccessTokenKey service:kAPIServiceName];
    
    if (!accessToken || accessToken.length == 0) {
        NSLog(@"[APITest] ⚠️ 未找到 Access Token，请先登录");
        NSError *error = [NSError errorWithDomain:@"APITestError" code:401 userInfo:@{NSLocalizedDescriptionKey: @"未登录"}];
        if (completion) completion(NO, nil, error);
        return;
    }
    
    NSString *url = [NSString stringWithFormat:@"%@/v1/user/profile", kAPIBaseURL];
    NSString *authHeader = [NSString stringWithFormat:@"Bearer %@", accessToken];
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.requestSerializer = [AFJSONRequestSerializer serializer];
    manager.responseSerializer = [AFJSONResponseSerializer serializer];
    [manager.requestSerializer setValue:authHeader forHTTPHeaderField:@"Authorization"];
    
    NSDate *startTime = [NSDate date];
    
    [manager GET:url
      parameters:nil
         headers:nil
        progress:nil
         success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:startTime];
        
        NSInteger code = [responseObject[@"code"] integerValue];
        
        if (code == 0) {
            NSDictionary *data = responseObject[@"data"];
            NSLog(@"[APITest] ✅ 获取用户信息成功！耗时: %.3f秒", elapsed);
            NSLog(@"[APITest] 用户信息: %@", data);
            if (completion) completion(YES, data, nil);
        } else {
            NSString *message = responseObject[@"message"] ?: @"获取失败";
            NSLog(@"[APITest] ❌ 获取用户信息失败！Code: %ld, Message: %@", (long)code, message);
            NSError *error = [NSError errorWithDomain:@"APITestError" code:code userInfo:@{NSLocalizedDescriptionKey: message}];
            if (completion) completion(NO, nil, error);
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:startTime];
        NSLog(@"[APITest] ❌ 获取用户信息请求失败！耗时: %.3f秒", elapsed);
        if (completion) completion(NO, nil, error);
    }];
}

- (void)testAPIRefreshTokenWithCompletion:(void(^)(BOOL success, NSString *newAccessToken, NSString *newRefreshToken, NSError *error))completion {
    NSLog(@"\n========== [APITest] 开始刷新 Token 测试 ==========");
    NSLog(@"[APITest] 请求: POST %@/v1/auth/refresh", kAPIBaseURL);
    
    NSString *refreshToken = [UICKeyChainStore stringForKey:kAPIRefreshTokenKey service:kAPIServiceName];
    
    if (!refreshToken || refreshToken.length == 0) {
        NSLog(@"[APITest] ⚠️ 未找到 Refresh Token，无法刷新");
        NSError *error = [NSError errorWithDomain:@"APITestError" code:401 userInfo:@{NSLocalizedDescriptionKey: @"无刷新令牌"}];
        if (completion) completion(NO, nil, nil, error);
        return;
    }
    
    NSLog(@"[APITest] 使用 Refresh Token: %@...", [refreshToken substringToIndex:MIN(20, refreshToken.length)]);
    
    NSString *url = [NSString stringWithFormat:@"%@/v1/auth/refresh", kAPIBaseURL];
    NSDictionary *params = @{@"refreshToken": refreshToken};
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.requestSerializer = [AFJSONRequestSerializer serializer];
    manager.responseSerializer = [AFJSONResponseSerializer serializer];
    [manager.requestSerializer setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    NSDate *startTime = [NSDate date];
    
    [manager POST:url
       parameters:params
          headers:nil
         progress:nil
          success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:startTime];
        
        NSInteger code = [responseObject[@"code"] integerValue];
        
        if (code == 0) {
            NSDictionary *data = responseObject[@"data"];
            NSString *newAccessToken = data[@"accessToken"];
            NSString *newRefreshToken = data[@"refreshToken"];
            
            NSLog(@"[APITest] ✅ 刷新 Token 成功！耗时: %.3f秒", elapsed);
            NSLog(@"[APITest] 新 Access Token: %@...", [newAccessToken substringToIndex:MIN(20, newAccessToken.length)]);
            NSLog(@"[APITest] 新 Refresh Token: %@...", [newRefreshToken substringToIndex:MIN(20, newRefreshToken.length)]);
            
            // 更新存储
            [UICKeyChainStore setString:newAccessToken forKey:kAPIAccessTokenKey service:kAPIServiceName];
            [UICKeyChainStore setString:newRefreshToken forKey:kAPIRefreshTokenKey service:kAPIServiceName];
            NSLog(@"[APITest] 新 Token 已更新到 KeyChain");
            
            if (completion) completion(YES, newAccessToken, newRefreshToken, nil);
        } else {
            NSString *message = responseObject[@"message"] ?: @"刷新失败";
            NSLog(@"[APITest] ❌ 刷新 Token 失败！Code: %ld, Message: %@", (long)code, message);
            
            // 清除失效的 Token
            [UICKeyChainStore removeItemForKey:kAPIAccessTokenKey service:kAPIServiceName];
            [UICKeyChainStore removeItemForKey:kAPIRefreshTokenKey service:kAPIServiceName];
            
            NSError *error = [NSError errorWithDomain:@"APITestError" code:code userInfo:@{NSLocalizedDescriptionKey: message}];
            if (completion) completion(NO, nil, nil, error);
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:startTime];
        NSLog(@"[APITest] ❌ 刷新 Token 请求失败！耗时: %.3f秒", elapsed);
        if (completion) completion(NO, nil, nil, error);
    }];
}

- (void)testAPIAdminDashboardWithCompletion:(void(^)(BOOL success, NSDictionary *data, NSError *error))completion {
    NSLog(@"\n========== [APITest] 开始管理员面板测试 ==========");
    NSLog(@"[APITest] 请求: GET %@/v1/admin/dashboard", kAPIBaseURL);
    
    NSString *accessToken = [UICKeyChainStore stringForKey:kAPIAccessTokenKey service:kAPIServiceName];
    
    if (!accessToken || accessToken.length == 0) {
        NSLog(@"[APITest] ⚠️ 未找到 Access Token，请先登录");
        NSError *error = [NSError errorWithDomain:@"APITestError" code:401 userInfo:@{NSLocalizedDescriptionKey: @"未登录"}];
        if (completion) completion(NO, nil, error);
        return;
    }
    
    NSString *url = [NSString stringWithFormat:@"%@/v1/admin/dashboard", kAPIBaseURL];
    NSString *authHeader = [NSString stringWithFormat:@"Bearer %@", accessToken];
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.requestSerializer = [AFJSONRequestSerializer serializer];
    manager.responseSerializer = [AFJSONResponseSerializer serializer];
    [manager.requestSerializer setValue:authHeader forHTTPHeaderField:@"Authorization"];
    
    NSDate *startTime = [NSDate date];
    
    [manager GET:url
      parameters:nil
         headers:nil
        progress:nil
         success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:startTime];
        
        NSInteger code = [responseObject[@"code"] integerValue];
        
        if (code == 0) {
            NSDictionary *data = responseObject[@"data"];
            NSLog(@"[APITest] ✅ 管理员面板访问成功！耗时: %.3f秒", elapsed);
            NSLog(@"[APITest] 数据: %@", data);
            if (completion) completion(YES, data, nil);
        } else {
            NSString *message = responseObject[@"message"] ?: @"访问失败";
            NSLog(@"[APITest] ❌ 管理员面板访问失败！Code: %ld, Message: %@", (long)code, message);
            NSError *error = [NSError errorWithDomain:@"APITestError" code:code userInfo:@{NSLocalizedDescriptionKey: message}];
            if (completion) completion(NO, nil, error);
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:startTime];
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)task.response;
        NSInteger statusCode = httpResponse.statusCode;
        
        NSLog(@"[APITest] ❌ 管理员面板请求失败！耗时: %.3f秒, HTTP %ld", elapsed, (long)statusCode);
        
        if (statusCode == 403) {
            NSLog(@"[APITest] ⚠️ 当前用户无管理员权限 (403 Forbidden)");
        }
        
        if (completion) completion(NO, nil, error);
    }];
}

- (void)testAPIFullFlowWithCompletion:(void(^)(BOOL success, NSString *message))completion {
    NSLog(@"\n🚀 ========== [APITest] 开始完整流程测试 ==========");
    NSLog(@"[APITest] 测试流程: 登录 -> 验证Token -> 获取用户信息");
    NSLog(@"[APITest] 使用测试账号: %@ / %@", kAPITestAdminUsername, kAPITestAdminPassword);
    
    __weak typeof(self) weakSelf = self;
    
    // 第一步：登录
    [self testAPILoginWithUsername:kAPITestAdminUsername
                          password:kAPITestAdminPassword
                        completion:^(BOOL success, NSString *accessToken, NSString *refreshToken, NSDictionary *userInfo, NSError *error) {
        
        if (!success) {
            NSString *msg = [NSString stringWithFormat:@"登录失败: %@", error.localizedDescription];
            NSLog(@"[APITest] ❌ %@", msg);
            if (completion) completion(NO, msg);
            return;
        }
        
        NSLog(@"\n----- 步骤 1/3: 登录成功，开始验证 Token -----");
        
        // 第二步：验证 Token
        [weakSelf testAPIValidateTokenWithCompletion:^(BOOL isValid, NSDictionary *tokenInfo, NSInteger code, NSError *error) {
            
            if (!isValid) {
                NSString *msg = [NSString stringWithFormat:@"Token 验证失败 (Code: %ld): %@", (long)code, error.localizedDescription];
                NSLog(@"[APITest] ❌ %@", msg);
                if (completion) completion(NO, msg);
                return;
            }
            
            NSLog(@"\n----- 步骤 2/3: Token 验证成功，开始获取用户信息 -----");
            
            // 第三步：获取用户信息
            [weakSelf testAPIGetUserProfileWithCompletion:^(BOOL success, NSDictionary *userInfo, NSError *error) {
                
                if (!success) {
                    NSString *msg = [NSString stringWithFormat:@"获取用户信息失败: %@", error.localizedDescription];
                    NSLog(@"[APITest] ❌ %@", msg);
                    if (completion) completion(NO, msg);
                    return;
                }
                
                NSString *username = userInfo[@"username"] ?: @"unknown";
                NSString *role = userInfo[@"role"] ?: @"unknown";
                
                NSString *msg = [NSString stringWithFormat:@"完整流程测试通过！用户: %@, 角色: %@", username, role];
                NSLog(@"[APITest] ✅ %@", msg);
                NSLog(@"🚀 ========== [APITest] 完整流程测试结束 ==========\n");
                
                if (completion) completion(YES, msg);
            }];
        }];
    }];
}

- (void)testAPIClearStoredTokens {
    NSLog(@"\n========== [APITest] 清除存储的 Token ==========");
    
    NSString *accessToken = [UICKeyChainStore stringForKey:kAPIAccessTokenKey service:kAPIServiceName];
    NSString *refreshToken = [UICKeyChainStore stringForKey:kAPIRefreshTokenKey service:kAPIServiceName];
    
    if (accessToken) {
        NSLog(@"[APITest] 清除前的 Access Token: %@...", [accessToken substringToIndex:MIN(20, accessToken.length)]);
    }
    if (refreshToken) {
        NSLog(@"[APITest] 清除前的 Refresh Token: %@...", [refreshToken substringToIndex:MIN(20, refreshToken.length)]);
    }
    
    [UICKeyChainStore removeItemForKey:kAPIAccessTokenKey service:kAPIServiceName];
    [UICKeyChainStore removeItemForKey:kAPIRefreshTokenKey service:kAPIServiceName];
    
    NSString *checkAccess = [UICKeyChainStore stringForKey:kAPIAccessTokenKey service:kAPIServiceName];
    NSString *checkRefresh = [UICKeyChainStore stringForKey:kAPIRefreshTokenKey service:kAPIServiceName];
    
    if (!checkAccess && !checkRefresh) {
        NSLog(@"[APITest] ✅ 所有 Token 已清除成功");
    } else {
        NSLog(@"[APITest] ⚠️ Token 清除不完全");
    }
}

- (NSString *)testAPIGetStoredAccessToken {
    return [UICKeyChainStore stringForKey:kAPIAccessTokenKey service:kAPIServiceName];
}

- (NSString *)testAPIGetStoredRefreshToken {
    return [UICKeyChainStore stringForKey:kAPIRefreshTokenKey service:kAPIServiceName];
}

@end
