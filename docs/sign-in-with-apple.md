# Sign in with Apple 实现方案

## 概览

本文档描述如何在现有项目上叠加 Apple ID 登录功能。
项目已有账号密码登录体系（`loginWithAccount:password:`）和 KeyChain Token 存储（UICKeyChainStore）。

---

## 准备工作（必须手动完成）

### 1. Apple Developer 后台

1. 登录 [developer.apple.com](https://developer.apple.com) → **Identifiers** → 找到当前 App ID
2. 勾选 **Sign In with Apple** → 保存

### 2. Xcode Capabilities

**Target → Signing & Capabilities → "+" → Sign in with Apple**

这会自动写入 `.entitlements` 文件：

```xml
<key>com.apple.developer.applesignin</key>
<array>
    <string>Default</string>
</array>
```

`Info.plist` 无需任何改动。

---

## 涉及文件清单

| 操作 | 文件 | 说明 |
|------|------|------|
| **新建** | `6. 网络请求部分/XCAppleAuthManager.h` | Apple 授权流程声明 |
| **新建** | `6. 网络请求部分/XCAppleAuthManager.mm` | Apple 授权流程实现 |
| **新增方法** | `6. 网络请求部分/XCNetworkManager.h` | 声明 `loginWithAppleIDToken:` |
| **新增方法** | `6. 网络请求部分/XCNetworkManager.mm` | 实现 `loginWithAppleIDToken:` |
| **新增调用** | `SceneDelegate.mm` | App 启动时检查 credential state |
| **新增 UI** | `8. 个人播放列表界面/XCPersonalViewController.mm` | 添加 Apple 登录按钮 |

> 新建的 `.h/.mm` 文件写到磁盘后，还需要在 Xcode 中右键 → **Add Files to "Spotify - clone"** 手动加入项目，否则编译器找不到。

---

## 一、新建 XCAppleAuthManager.h

```objc
//  XCAppleAuthManager.h
//  Apple ID 登录流程封装

#import <Foundation/Foundation.h>
#import <AuthenticationServices/AuthenticationServices.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// UserDefaults key，存储 Apple User ID（用于后续 credential state 检查）
extern NSString * const kAppleUserIDKey;

/// Apple 登录成功通知（userInfo 是后端返回的用户数据 NSDictionary）
extern NSString * const XCAppleSignInDidSucceedNotification;

/// Apple 登录失败通知（userInfo[@"error"] 为 NSError）
extern NSString * const XCAppleSignInDidFailNotification;

@interface XCAppleAuthManager : NSObject

+ (instancetype)sharedInstance;

/// 当前是否通过 Apple ID 登录（本地 UserID 存在 且 KeyChain Token 有效）
@property (nonatomic, readonly) BOOL isAppleSignedIn;

/// 发起 Apple 授权请求，弹出系统授权界面
- (void)requestAppleSignInFromViewController:(UIViewController *)viewController;

/// 检查存储的 Apple ID 凭证状态（App 启动时调用）
/// 若状态为 Revoked，自动清除本地 Token
- (void)checkCredentialStateWithCompletion:(void(^)(ASAuthorizationAppleIDProviderCredentialState state))completion;

@end

NS_ASSUME_NONNULL_END
```

---

## 二、新建 XCAppleAuthManager.mm

```objc
//  XCAppleAuthManager.mm

#import "XCAppleAuthManager.h"
#import "XCNetworkManager.h"

NSString * const kAppleUserIDKey = @"com.spotify.clone.appleUserID";
NSString * const XCAppleSignInDidSucceedNotification = @"XCAppleSignInDidSucceed";
NSString * const XCAppleSignInDidFailNotification    = @"XCAppleSignInDidFail";

@interface XCAppleAuthManager () <ASAuthorizationControllerDelegate,
                                   ASAuthorizationControllerPresentationContextProviding>
@property (nonatomic, weak) UIViewController *presentingViewController;
@end

@implementation XCAppleAuthManager

#pragma mark - 单例

+ (instancetype)sharedInstance {
    static XCAppleAuthManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

#pragma mark - 状态查询

- (BOOL)isAppleSignedIn {
    NSString *uid = [[NSUserDefaults standardUserDefaults] stringForKey:kAppleUserIDKey];
    return uid.length > 0 && [[XCNetworkManager sharedInstance] hasAccountToken];
}

#pragma mark - 发起授权

- (void)requestAppleSignInFromViewController:(UIViewController *)viewController {
    self.presentingViewController = viewController;

    ASAuthorizationAppleIDProvider *provider = [[ASAuthorizationAppleIDProvider alloc] init];
    ASAuthorizationAppleIDRequest *request = [provider createRequest];
    request.requestedScopes = @[ASAuthorizationScopeFullName, ASAuthorizationScopeEmail];

    ASAuthorizationController *ctrl =
        [[ASAuthorizationController alloc] initWithAuthorizationRequests:@[request]];
    ctrl.delegate = self;
    ctrl.presentationContextProvider = self;
    [ctrl performRequests];
}

#pragma mark - 检查凭证状态

- (void)checkCredentialStateWithCompletion:(void(^)(ASAuthorizationAppleIDProviderCredentialState))completion {
    NSString *uid = [[NSUserDefaults standardUserDefaults] stringForKey:kAppleUserIDKey];
    if (!uid || uid.length == 0) {
        if (completion) completion(ASAuthorizationAppleIDProviderCredentialNotFound);
        return;
    }

    ASAuthorizationAppleIDProvider *provider = [[ASAuthorizationAppleIDProvider alloc] init];
    [provider getCredentialStateForUserID:uid
                               completion:^(ASAuthorizationAppleIDProviderCredentialState state,
                                            NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (state == ASAuthorizationAppleIDProviderCredentialRevoked) {
                NSLog(@"[AppleAuth] Apple ID 授权已撤销，清除登录状态");
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:kAppleUserIDKey];
                [[XCNetworkManager sharedInstance] authLogoutAccount];
            }
            if (completion) completion(state);
        });
    }];
}

#pragma mark - ASAuthorizationControllerDelegate

- (void)authorizationController:(ASAuthorizationController *)controller
    didCompleteWithAuthorization:(ASAuthorization *)authorization {

    if (![authorization.credential isKindOfClass:[ASAuthorizationAppleIDCredential class]]) return;
    ASAuthorizationAppleIDCredential *cred = (ASAuthorizationAppleIDCredential *)authorization.credential;

    // NSData → UTF-8 字符串
    NSString *identityToken     = [[NSString alloc] initWithData:cred.identityToken encoding:NSUTF8StringEncoding];
    NSString *authorizationCode = [[NSString alloc] initWithData:cred.authorizationCode encoding:NSUTF8StringEncoding];

    // email / fullName 仅首次授权时有值
    NSString *email    = cred.email;
    NSString *fullName = nil;
    if (cred.fullName) {
        NSPersonNameComponentsFormatter *fmt = [[NSPersonNameComponentsFormatter alloc] init];
        NSString *s = [fmt stringFromPersonNameComponents:cred.fullName];
        if (s.length > 0) fullName = s;
    }

    // 先本地记录 Apple User ID
    [[NSUserDefaults standardUserDefaults] setObject:cred.user forKey:kAppleUserIDKey];

    // 发给后端验证
    [[XCNetworkManager sharedInstance]
        loginWithAppleIDToken:identityToken
           authorizationCode:authorizationCode
                       email:email
                    fullName:fullName
                  completion:^(BOOL success, NSString *at, NSString *rt, NSDictionary *info, NSError *err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                [[NSNotificationCenter defaultCenter]
                    postNotificationName:XCAppleSignInDidSucceedNotification object:nil userInfo:info];
            } else {
                // 后端验证失败，回滚本地 Apple User ID
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:kAppleUserIDKey];
                [[NSNotificationCenter defaultCenter]
                    postNotificationName:XCAppleSignInDidFailNotification object:nil
                                userInfo:err ? @{@"error": err} : @{}];
            }
        });
    }];
}

- (void)authorizationController:(ASAuthorizationController *)controller
             didCompleteWithError:(NSError *)error {
    if (error.code == ASAuthorizationErrorCanceled) return;  // 用户主动取消，静默处理
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter]
            postNotificationName:XCAppleSignInDidFailNotification object:nil
                        userInfo:@{@"error": error}];
    });
}

#pragma mark - ASAuthorizationControllerPresentationContextProviding

- (ASPresentationAnchor)presentationAnchorForAuthorizationController:(ASAuthorizationController *)controller {
    return self.presentingViewController.view.window;
}

@end
```

---

## 三、XCNetworkManager.h — 新增声明

在 `#pragma mark - 预留：其他登录方式 (Future)` 注释块**替换**为：

```objc
#pragma mark - Apple ID 登录

/**
 * 将 Apple 凭证发送给自建后端进行验证，成功后自动存储 Token 到 KeyChain
 * @param identityToken     Apple 返回的 JWT 字符串（用于后端验证）
 * @param authorizationCode Apple 授权码
 * @param email             用户邮箱（仅首次授权时有值，可为 nil）
 * @param fullName          用户全名（仅首次授权时有值，可为 nil）
 * @param completion        回调：success, accessToken, refreshToken, userInfo, error
 */
- (void)loginWithAppleIDToken:(NSString *)identityToken
            authorizationCode:(NSString *)authorizationCode
                        email:(nullable NSString *)email
                     fullName:(nullable NSString *)fullName
                   completion:(void(^)(BOOL success,
                                       NSString * _Nullable accessToken,
                                       NSString * _Nullable refreshToken,
                                       NSDictionary * _Nullable userInfo,
                                       NSError * _Nullable error))completion;
```

---

## 四、XCNetworkManager.mm — 新增实现

紧接在 `- (void)authLogoutAccount { ... }` 之后、`#pragma mark - Token 管理` 之前插入：

```objc
#pragma mark - Apple ID 登录

- (void)loginWithAppleIDToken:(NSString *)identityToken
            authorizationCode:(NSString *)authorizationCode
                        email:(nullable NSString *)email
                     fullName:(nullable NSString *)fullName
                   completion:(void(^)(BOOL success,
                                       NSString * _Nullable accessToken,
                                       NSString * _Nullable refreshToken,
                                       NSDictionary * _Nullable userInfo,
                                       NSError * _Nullable error))completion {
    NSString *url = [NSString stringWithFormat:@"%@/v1/auth/apple", kAPIBaseURL];

    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[@"identity_token"]     = identityToken ?: @"";
    params[@"authorization_code"] = authorizationCode ?: @"";
    if (email)    params[@"email"]     = email;
    if (fullName) params[@"full_name"] = fullName;

    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.requestSerializer = [AFJSONRequestSerializer serializer];
    manager.responseSerializer = [AFJSONResponseSerializer serializer];
    [manager.requestSerializer setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    [manager POST:url parameters:params headers:nil progress:nil
          success:^(NSURLSessionDataTask *task, id responseObject) {
        if (![responseObject isKindOfClass:[NSDictionary class]]) {
            NSError *err = [NSError errorWithDomain:@"APIError" code:-1
                                          userInfo:@{NSLocalizedDescriptionKey: @"响应格式错误"}];
            if (completion) completion(NO, nil, nil, nil, err);
            return;
        }
        NSInteger code    = [responseObject[@"code"] integerValue];
        NSString  *msg    = responseObject[@"message"] ?: @"unknown";
        if (code == 0) {
            NSDictionary *data         = responseObject[@"data"];
            NSString     *accessToken  = data[@"accessToken"];
            NSString     *refreshToken = data[@"refreshToken"];
            [UICKeyChainStore setString:accessToken  forKey:kAPIAccessTokenKey  service:kAPIServiceName];
            [UICKeyChainStore setString:refreshToken forKey:kAPIRefreshTokenKey service:kAPIServiceName];
            if (completion) completion(YES, accessToken, refreshToken, data, nil);
        } else {
            NSError *err = [NSError errorWithDomain:@"APIError" code:code
                                          userInfo:@{NSLocalizedDescriptionKey: msg}];
            if (completion) completion(NO, nil, nil, nil, err);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        if (completion) completion(NO, nil, nil, nil, error);
    }];
}
```

---

## 五、SceneDelegate.mm — 启动时检查凭证状态

### 新增 import（在现有 import 之后）

```objc
#import "XCAppleAuthManager.h"
```

### 在 `[self.window makeKeyAndVisible]` 之后插入

```objc
// 检查 Apple ID 授权状态（若已撤销则自动清除 Token）
[[XCAppleAuthManager sharedInstance] checkCredentialStateWithCompletion:^(ASAuthorizationAppleIDProviderCredentialState state) {
    if (state == ASAuthorizationAppleIDProviderCredentialRevoked) {
        NSLog(@"[SceneDelegate] Apple ID 授权已撤销，登录状态已清除");
    }
}];
```

---

## 六、XCPersonalViewController.mm — 添加 Apple 登录按钮 UI

### 新增 import

```objc
#import "XCAppleAuthManager.h"
#import <AuthenticationServices/AuthenticationServices.h>
```

### viewDidLoad 末尾追加

```objc
[self updateLoginHeader];

[[NSNotificationCenter defaultCenter] addObserver:self
                                         selector:@selector(handleAppleSignInSucceeded:)
                                             name:XCAppleSignInDidSucceedNotification
                                           object:nil];
[[NSNotificationCenter defaultCenter] addObserver:self
                                         selector:@selector(handleAppleSignInFailed:)
                                             name:XCAppleSignInDidFailNotification
                                           object:nil];
```

### viewWillAppear 末尾追加

```objc
[self updateLoginHeader];
```

### dealloc 新增

```objc
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
```

### 新增方法组

在 `#pragma mark - Setup` **之前**插入：

```objc
#pragma mark - Apple Sign In

/// 根据登录状态显示/隐藏 Apple 登录 Header
- (void)updateLoginHeader {
    if ([XCAppleAuthManager sharedInstance].isAppleSignedIn) {
        self.mainView.tableView.tableHeaderView = nil;
    } else {
        self.mainView.tableView.tableHeaderView = [self buildLoginHeaderView];
    }
}

/// 构建包含 Apple 登录按钮的 Header View（高度 140 pt）
- (UIView *)buildLoginHeaderView {
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0,
                                                                  self.view.bounds.size.width, 140)];
    UILabel *hintLabel = [[UILabel alloc] init];
    hintLabel.text          = @"登录以查看你的播放列表";
    hintLabel.font          = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    hintLabel.textColor     = [UIColor secondaryLabelColor];
    hintLabel.textAlignment = NSTextAlignmentCenter;
    [container addSubview:hintLabel];
    [hintLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(container).offset(24);
        make.centerX.equalTo(container);
    }];

    ASAuthorizationAppleIDButton *appleButton =
        [[ASAuthorizationAppleIDButton alloc]
            initWithAuthorizationButtonType:ASAuthorizationAppleIDButtonTypeSignIn
                    authorizationButtonStyle:ASAuthorizationAppleIDButtonStyleBlack];
    [appleButton addTarget:self action:@selector(appleSignInButtonTapped)
          forControlEvents:UIControlEventTouchUpInside];
    appleButton.cornerRadius = 12;
    [container addSubview:appleButton];
    [appleButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(hintLabel.mas_bottom).offset(16);
        make.centerX.equalTo(container);
        make.width.equalTo(@280);
        make.height.equalTo(@50);
    }];

    return container;
}

- (void)appleSignInButtonTapped {
    [[XCAppleAuthManager sharedInstance] requestAppleSignInFromViewController:self];
}

- (void)handleAppleSignInSucceeded:(NSNotification *)notification {
    [self.model loadPlaylists];
    [self.mainView.tableView reloadData];
    [self.mainView.collectionView reloadData];
    [self updateLoginHeader];
}

- (void)handleAppleSignInFailed:(NSNotification *)notification {
    NSError *error    = notification.userInfo[@"error"];
    NSString *message = error.localizedDescription ?: @"登录失败，请稍后重试";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"登录失败"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定"
                                             style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
```

---

## 七、后端接口说明

### `POST /v1/auth/apple`

**请求 body（JSON）：**

```json
{
  "identity_token":     "eyJraWQiOiJX...",
  "authorization_code": "c6d7890...",
  "email":              "user@privaterelay.appleid.com",
  "full_name":          "张三"
}
```

> `email` / `full_name` 仅首次登录时有值，后续登录为 null，后端需能处理。

**后端处理步骤：**

1. 请求 `https://appleid.apple.com/auth/keys` 获取公钥（建议缓存 1 小时）
2. 验证 `identity_token` JWT：
   - `iss == "https://appleid.apple.com"`
   - `aud == 你的 Bundle ID`
   - `exp > 当前时间`
3. 提取 JWT payload 中的 `sub`（Apple 唯一用户 ID）
4. `SELECT * FROM users WHERE apple_user_id = sub`：找到则更新 `last_login_at`，否则新建用户
5. 生成 `accessToken` / `refreshToken`（与 password 登录共用同一套逻辑）
6. 返回与 `/v1/auth/login` 相同格式的响应

**数据库变更：**

```sql
ALTER TABLE users ADD COLUMN apple_user_id VARCHAR(64) UNIQUE;
ALTER TABLE users ADD COLUMN apple_email   VARCHAR(255);
```

---

## 八、注意事项

| 事项 | 说明 |
|------|------|
| **真机测试** | Sign in with Apple 无法在模拟器完整测试，必须用真实设备和 Apple ID |
| **App Review** | 若 App 提供第三方登录（微信、Google 等），Apple 要求**必须同时提供** Sign in with Apple |
| **官方按钮** | 必须使用 `ASAuthorizationAppleIDButton`，不可自定义样式替代 |
| **首次 vs 再次登录** | `email` / `fullName` 仅首次授权时由 Apple 填充，后端要在首次时落库 |
| **授权撤销** | 用户在 系统设置 → Apple ID → 密码与安全性 中可撤销授权，App 启动时需检查 |
