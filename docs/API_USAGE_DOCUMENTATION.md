# API 使用文档

## 📋 概述

本 API 提供用户认证、Token 管理和基础测试功能，采用 RESTful 设计风格，所有响应均以 JSON 格式返回。

**基础地址：** `https://ding.liujiong.com/api`

---

## 🔐 认证方式

### Bearer Token 认证

受保护的接口需要在请求头中携带访问令牌：

```
Authorization: Bearer {access_token}
```

Token 有效期为 60 分钟，过期后需使用 Refresh Token 获取新的 Token 对。

---

## 📍 接口分类

### 一、公开接口（无需认证）

#### 1. 服务信息
- **路径：** `GET /`
- **说明：** 获取 API 服务基本信息和可用端点列表

#### 2. 健康检查
- **路径：** `GET /test` 或 `POST /test`
- **说明：** 服务健康状态检测
- **POST 请求体：**
  - `action`: `health`（默认）| `ping` | `echo`
  - `ping`: 当 action 为 `ping` 时传入的测试字符串

#### 3. Hello 接口
- **路径：** `GET /hello` 或 `POST /hello`
- **说明：** 简单的问候接口
- **POST 请求体：**
  - `name`: 用户名（默认 "World"）
  - `message`: 问候语（默认 "Hello"）

#### 4. 用户登录
- **路径：** `POST /v1/auth/login`
- **说明：** 用户认证并获取 Token 对
- **请求体：**
  - `username`: 用户名
  - `password`: 密码
- **响应：** 包含 accessToken、refreshToken、用户信息及过期时间

**测试账号：**
- 管理员：admin / admin123（拥有 admin、user 角色）
- 普通用户：testuser / user123（拥有 user 角色）

#### 5. 刷新 Token
- **路径：** `POST /v1/auth/refresh`
- **说明：** 使用 Refresh Token 获取新的 Access Token
- **请求体：**
  - `refreshToken`: 刷新令牌

---

### 二、受保护接口（需要认证）

#### 1. 获取用户信息
- **路径：** `GET /v1/user/profile`
- **说明：** 获取当前登录用户的详细信息
- **认证：** Bearer Token

#### 2. 验证 Token
- **路径：** `GET /v1/auth/validate`
- **说明：** 验证当前 Token 是否有效，返回解析后的 Token 信息
- **认证：** Bearer Token

#### 3. 管理员面板
- **路径：** `GET /v1/admin/dashboard`
- **说明：** 仅管理员角色可访问的接口
- **认证：** Bearer Token（需包含 admin 角色）

---

## 📝 响应格式

### 标准响应结构

```json
{
  "code": 0,
  "message": "success",
  "timestamp": "2026-02-12 12:00:00",
  "requestId": "xxx",
  "data": { ... }
}
```

### 状态码说明

| Code | 含义 |
|------|------|
| 0 | 成功 |
| 401 | 未授权（Token 无效或过期）|
| 404 | 接口不存在 |
| 405 | 请求方法不允许 |
| 1001 | 用户名或密码错误 |
| 1003 | Refresh Token 无效或过期 |

---

## 🔄 使用流程

### 首次登录流程

1. 调用 `POST /v1/auth/login` 获取 Token 对
2. 保存返回的 `accessToken` 和 `refreshToken`
3. 在后续请求头中添加 `Authorization: Bearer {accessToken}`
4. 根据 `expiresAt` 判断 Token 过期时间

### Token 刷新流程

1. 当 Access Token 即将过期或已过期时
2. 调用 `POST /v1/auth/refresh` 传入 `refreshToken`
3. 获取新的 Token 对并更新本地存储
4. 使用新的 Access Token 继续请求

---

## 💡 Objective-C (AFNetworking) 使用示例

以下是使用 AFNetworking 框架调用本 API 的完整示例：

### 基础配置

```objc
// 定义基础 URL
static NSString * const kBaseURL = @"https://ding.liujiong.com/api";

// 创建 AFHTTPSessionManager 实例
AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
manager.requestSerializer = [AFJSONRequestSerializer serializer];
manager.responseSerializer = [AFJSONResponseSerializer serializer];

// 设置通用请求头（Content-Type）
[manager.requestSerializer setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
```

### 1. 用户登录

```objc
- (void)loginWithUsername:(NSString *)username 
                 password:(NSString *)password 
                  success:(void (^)(NSString *accessToken, NSString *refreshToken, NSDictionary *userInfo))success 
                  failure:(void (^)(NSError *error))failure {
    
    NSDictionary *params = @{
        @"username": username,
        @"password": password
    };
    
    NSString *url = [NSString stringWithFormat:@"%@/v1/auth/login", kBaseURL];
    
    [manager POST:url
       parameters:params
         progress:nil
          success:^(NSURLSessionDataTask *task, id responseObject) {
              NSInteger code = [responseObject[@"code"] integerValue];
              if (code == 0) {
                  NSDictionary *data = responseObject[@"data"];
                  NSString *accessToken = data[@"accessToken"];
                  NSString *refreshToken = data[@"refreshToken"];
                  
                  // 保存 Token 到本地（建议使用 Keychain）
                  [[NSUserDefaults standardUserDefaults] setObject:accessToken forKey:@"AccessToken"];
                  [[NSUserDefaults standardUserDefaults] setObject:refreshToken forKey:@"RefreshToken"];
                  [[NSUserDefaults standardUserDefaults] synchronize];
                  
                  if (success) {
                      success(accessToken, refreshToken, data);
                  }
              } else {
                  NSString *message = responseObject[@"message"];
                  NSError *error = [NSError errorWithDomain:@"APIError" 
                                                       code:code 
                                                   userInfo:@{NSLocalizedDescriptionKey: message}];
                  if (failure) {
                      failure(error);
                  }
              }
          }
          failure:^(NSURLSessionDataTask *task, NSError *error) {
              if (failure) {
                  failure(error);
              }
          }];
}
```

### 2. 获取用户信息（带认证）

```objc
- (void)getUserProfileWithSuccess:(void (^)(NSDictionary *userInfo))success 
                          failure:(void (^)(NSError *error))failure {
    
    NSString *accessToken = [[NSUserDefaults standardUserDefaults] objectForKey:@"AccessToken"];
    if (!accessToken) {
        NSError *error = [NSError errorWithDomain:@"AuthError" 
                                             code:401 
                                         userInfo:@{NSLocalizedDescriptionKey: @"未登录"}];
        if (failure) {
            failure(error);
        }
        return;
    }
    
    NSString *url = [NSString stringWithFormat:@"%@/v1/user/profile", kBaseURL];
    
    // 设置认证头
    NSString *authHeader = [NSString stringWithFormat:@"Bearer %@", accessToken];
    [manager.requestSerializer setValue:authHeader forHTTPHeaderField:@"Authorization"];
    
    [manager GET:url
      parameters:nil
        progress:nil
         success:^(NSURLSessionDataTask *task, id responseObject) {
             NSInteger code = [responseObject[@"code"] integerValue];
             if (code == 0) {
                 if (success) {
                     success(responseObject[@"data"]);
                 }
             } else if (code == 401) {
                 // Token 过期，需要刷新
                 [self refreshTokenWithSuccess:^{
                     // 重试原请求
                     [self getUserProfileWithSuccess:success failure:failure];
                 } failure:failure];
             } else {
                 NSError *error = [NSError errorWithDomain:@"APIError" 
                                                      code:code 
                                                  userInfo:@{NSLocalizedDescriptionKey: responseObject[@"message"]}];
                 if (failure) {
                     failure(error);
                 }
             }
         }
         failure:^(NSURLSessionDataTask *task, NSError *error) {
             if (failure) {
                 failure(error);
             }
         }];
}
```

### 3. 刷新 Token

```objc
- (void)refreshTokenWithSuccess:(void (^)(void))success 
                        failure:(void (^)(NSError *error))failure {
    
    NSString *refreshToken = [[NSUserDefaults standardUserDefaults] objectForKey:@"RefreshToken"];
    if (!refreshToken) {
        NSError *error = [NSError errorWithDomain:@"AuthError" 
                                             code:401 
                                         userInfo:@{NSLocalizedDescriptionKey: @"无刷新令牌"}];
        if (failure) {
            failure(error);
        }
        return;
    }
    
    NSDictionary *params = @{
        @"refreshToken": refreshToken
    };
    
    NSString *url = [NSString stringWithFormat:@"%@/v1/auth/refresh", kBaseURL];
    
    [manager POST:url
       parameters:params
         progress:nil
          success:^(NSURLSessionDataTask *task, id responseObject) {
              NSInteger code = [responseObject[@"code"] integerValue];
              if (code == 0) {
                  NSDictionary *data = responseObject[@"data"];
                  NSString *newAccessToken = data[@"accessToken"];
                  NSString *newRefreshToken = data[@"refreshToken"];
                  
                  // 更新本地 Token
                  [[NSUserDefaults standardUserDefaults] setObject:newAccessToken forKey:@"AccessToken"];
                  [[NSUserDefaults standardUserDefaults] setObject:newRefreshToken forKey:@"RefreshToken"];
                  [[NSUserDefaults standardUserDefaults] synchronize];
                  
                  // 更新请求头的认证信息
                  NSString *authHeader = [NSString stringWithFormat:@"Bearer %@", newAccessToken];
                  [manager.requestSerializer setValue:authHeader forHTTPHeaderField:@"Authorization"];
                  
                  if (success) {
                      success();
                  }
              } else {
                  // 刷新失败，需要重新登录
                  [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"AccessToken"];
                  [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"RefreshToken"];
                  [[NSUserDefaults standardUserDefaults] synchronize];
                  
                  NSError *error = [NSError errorWithDomain:@"AuthError" 
                                                       code:1003 
                                                   userInfo:@{NSLocalizedDescriptionKey: @"登录已过期，请重新登录"}];
                  if (failure) {
                      failure(error);
                  }
              }
          }
          failure:^(NSURLSessionDataTask *task, NSError *error) {
              if (failure) {
                  failure(error);
              }
          }];
}
```

### 4. 测试接口（健康检查）

```objc
- (void)healthCheckWithSuccess:(void (^)(NSDictionary *healthInfo))success 
                       failure:(void (^)(NSError *error))failure {
    
    NSString *url = [NSString stringWithFormat:@"%@/test", kBaseURL];
    
    [manager GET:url
      parameters:nil
        progress:nil
         success:^(NSURLSessionDataTask *task, id responseObject) {
             if (success) {
                 success(responseObject);
             }
         }
         failure:^(NSURLSessionDataTask *task, NSError *error) {
             if (failure) {
                 failure(error);
             }
         }];
}
```

### 5. 验证当前 Token

```objc
- (void)validateTokenWithSuccess:(void (^)(NSDictionary *tokenInfo))success 
                         failure:(void (^)(NSError *error))failure {
    
    NSString *accessToken = [[NSUserDefaults standardUserDefaults] objectForKey:@"AccessToken"];
    if (!accessToken) {
        NSError *error = [NSError errorWithDomain:@"AuthError" 
                                             code:401 
                                         userInfo:@{NSLocalizedDescriptionKey: @"未登录"}];
        if (failure) {
            failure(error);
        }
        return;
    }
    
    NSString *url = [NSString stringWithFormat:@"%@/v1/auth/validate", kBaseURL];
    NSString *authHeader = [NSString stringWithFormat:@"Bearer %@", accessToken];
    [manager.requestSerializer setValue:authHeader forHTTPHeaderField:@"Authorization"];
    
    [manager GET:url
      parameters:nil
        progress:nil
         success:^(NSURLSessionDataTask *task, id responseObject) {
             NSInteger code = [responseObject[@"code"] integerValue];
             if (code == 0) {
                 if (success) {
                     success(responseObject[@"data"]);
                 }
             } else {
                 NSError *error = [NSError errorWithDomain:@"APIError" 
                                                      code:code 
                                                  userInfo:@{NSLocalizedDescriptionKey: responseObject[@"message"]}];
                 if (failure) {
                     failure(error);
                 }
             }
         }
         failure:^(NSURLSessionDataTask *task, NSError *error) {
             if (failure) {
                 failure(error);
             }
         }];
}
```

### 6. 通用请求方法（支持自动 Token 刷新）

```objc
- (void)requestWithMethod:(NSString *)method
                      path:(NSString *)path
                parameters:(NSDictionary *)parameters
               requiresAuth:(BOOL)requiresAuth
                   success:(void (^)(id responseObject))success
                   failure:(void (^)(NSError *error))failure {
    
    NSString *url = [NSString stringWithFormat:@"%@%@", kBaseURL, path];
    
    // 如果需要认证，添加 Token
    if (requiresAuth) {
        NSString *accessToken = [[NSUserDefaults standardUserDefaults] objectForKey:@"AccessToken"];
        if (accessToken) {
            NSString *authHeader = [NSString stringWithFormat:@"Bearer %@", accessToken];
            [manager.requestSerializer setValue:authHeader forHTTPHeaderField:@"Authorization"];
        }
    }
    
    // 执行请求
    void (^requestBlock)(void) = ^{
        if ([method isEqualToString:@"GET"]) {
            [manager GET:url parameters:parameters progress:nil success:success failure:failure];
        } else if ([method isEqualToString:@"POST"]) {
            [manager POST:url parameters:parameters progress:nil success:success failure:failure];
        }
    };
    
    requestBlock();
}
```

---

## ⚠️ 注意事项

1. **Token 安全**：Access Token 和 Refresh Token 应使用 Keychain 安全存储，而不是 NSUserDefaults
2. **自动刷新**：建议在收到 401 状态码时自动触发 Token 刷新流程
3. **并发控制**：Token 刷新请求应避免并发，防止多个请求同时触发刷新
4. **Base URL**：确保基础 URL 末尾不包含斜杠，与路径拼接时注意格式
5. **错误处理**：所有接口调用都应处理网络错误和业务错误（通过 code 字段判断）

---

## 📚 相关文档

- 后端基于 Go + SCF 云函数实现
- JWT Token 采用 HS256 签名算法
- Access Token 有效期：60 分钟
- Refresh Token 有效期：7 天
