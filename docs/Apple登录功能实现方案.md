# Apple 登录功能实现方案

> 文档日期：2026-02-21
> 当前分支：自己写个人播放列表
> 目标：为 Spotify 克隆项目接入 Sign in with Apple

---

## 一、背景与目标

### 现状

- `XCUserInfoManager` 已有 `loginWithApple` 方法占位，但未实现
- `XCNetworkManager` 已有账号登录（用户名/密码）体系，包含 Token 管理和 KeyChain 存储
- `XCPersonalViewController` 当前使用写死的测试数据，未与用户账号绑定
- 后端 API 基址：`https://ding.liujiong.com/api`

### 目标

1. 实现标准的 Sign in with Apple 授权流程
2. 将 Apple Identity Token 发送给后端换取 App 自有 Token
3. 登录状态持久化（KeyChain）
4. 在「个人库」Tab 未登录时显示登录引导，登录后显示真实数据

---

## 二、Sign in with Apple 核心流程

```
用户点击按钮
    ↓
iOS 弹出系统授权面板（ASAuthorizationController）
    ↓
授权成功 → 获得 ASAuthorizationAppleIDCredential
    │   ├── userIdentifier  (唯一稳定的用户 ID)
    │   ├── identityToken   (JWT，Apple 签发，用于后端验证)
    │   ├── authorizationCode (单次使用，可刷新)
    │   ├── fullName        (仅首次授权时提供)
    │   └── email           (仅首次授权时提供，可能是 Apple 中转邮箱)
    ↓
将 identityToken 发送给后端 /v1/auth/apple
    ↓
后端向 Apple 验证 Token，返回 App accessToken + refreshToken
    ↓
存入 KeyChain（复用现有 UICKeyChainStore 体系）
    ↓
更新 XCUserInfoManager 状态，通知 UI 刷新
```

---

## 三、需要做的配置（Xcode & Apple Developer）

### 3.1 Apple Developer Portal

1. 登录 developer.apple.com → Certificates, Identifiers & Profiles
2. 选择对应的 App ID（Bundle ID）
3. 在 Capabilities 中勾选 **Sign In with Apple**
4. 保存并重新下载 Provisioning Profile

### 3.2 Xcode 项目配置

1. 在 Xcode 中打开项目 → 选择 Target
2. 进入 **Signing & Capabilities** 标签页
3. 点击 **+ Capability**，添加 **Sign In with Apple**
4. Xcode 会自动在 `.entitlements` 文件中添加：
   ```xml
   <key>com.apple.developer.applesignin</key>
   <array>
       <string>Default</string>
   </array>
   ```

### 3.3 引入框架

在需要使用的文件中引入：
```objc
#import <AuthenticationServices/AuthenticationServices.h>
```

不需要在 Podfile 中额外添加，`AuthenticationServices` 是系统框架（iOS 13+）。

---

## 四、后端 API 设计（需与后端确认）

需要后端新增一个接口，接收 Apple 的 `identityToken`（或 `authorizationCode`），验证后返回 App Token。

### 建议接口

```
POST /v1/auth/apple
Content-Type: application/json

{
    "identityToken": "<Apple 签发的 JWT>",
    "authorizationCode": "<Apple 授权码>",
    "fullName": {          // 首次登录时提供，后续为 null
        "givenName": "张",
        "familyName": "三"
    },
    "email": "user@example.com"  // 首次登录时提供
}
```

### 期望返回（与现有登录接口保持一致）

```json
{
    "code": 200,
    "message": "success",
    "data": {
        "accessToken": "...",
        "refreshToken": "...",
        "userInfo": {
            "userId": "...",
            "username": "...",
            "avatar": "..."
        }
    }
}
```

> **注意**：如果后端尚未支持，可以在方案验证阶段先用账号密码登录接口做替代，等后端就绪后再接入。

---

## 五、代码改动范围

### 5.1 XCNetworkManager（新增方法）

在现有的账号认证模块中，新增 Apple 登录接口调用方法：

**头文件新增**：
```objc
/// Apple 登录 - 将 identityToken 发给后端换取 App Token
- (void)loginWithAppleIdentityToken:(NSString *)identityToken
                  authorizationCode:(NSString *)authorizationCode
                           fullName:(nullable NSPersonNameComponents *)fullName
                              email:(nullable NSString *)email
                         completion:(void(^)(BOOL success,
                                             NSString * _Nullable accessToken,
                                             NSString * _Nullable refreshToken,
                                             NSDictionary * _Nullable userInfo,
                                             NSError * _Nullable error))completion;
```

**实现逻辑**：
- POST 到 `/v1/auth/apple`
- 参数包含 identityToken（NSString，Base64 编码的 JWT）
- 成功后将 accessToken / refreshToken 存入 KeyChain（复用 `kAPIAccessTokenKey` / `kAPIRefreshTokenKey`）

### 5.2 XCUserInfoManager（实现 loginWithApple）

当前 `loginWithApple` 方法为空，需要完整实现：

**主要职责**：
1. 触发 Apple 授权（`ASAuthorizationController`）
2. 处理授权成功回调
3. 调用 `XCNetworkManager` 发送给后端
4. 更新自身状态（`isLogin`、`userInfo` 等）
5. 首次登录时在本地存储用户姓名（Apple 只在首次提供）
6. 发出登录成功通知（`NSNotificationCenter`）

**需要新增**：
- `loginType` 值定义为 `@"apple"`
- `NSUserDefaults` 存储 `appleUserIdentifier`（用于下次快速登录检查）
- 在 `init` 方法中检查 `ASAuthorizationAppleIDProvider` 的凭证状态，判断是否已有有效的 Apple 登录

**凭证状态检查**（app 启动时）：
```objc
// 检查之前是否已用 Apple 登录过
ASAuthorizationAppleIDProvider *appleIDProvider = [[ASAuthorizationAppleIDProvider alloc] init];
NSString *savedUserID = [[NSUserDefaults standardUserDefaults] stringForKey:@"appleUserIdentifier"];
if (savedUserID) {
    [appleIDProvider getCredentialStateForUserID:savedUserID
                                     completion:^(ASAuthorizationAppleIDProviderCredentialState state, NSError *error) {
        if (state == ASAuthorizationAppleIDProviderCredentialAuthorized) {
            // 凭证有效，直接尝试用已有 KeyChain Token 恢复登录
        } else {
            // 凭证失效，需要重新登录
        }
    }];
}
```

### 5.3 XCPersonalViewController（未登录状态 UI）

当前 `XCPersonalViewController` 直接展示播放列表。需要根据登录状态区分：

**未登录状态**：
- 隐藏 TableView
- 显示登录引导视图，包含：
  - 提示文字（"登录后查看你的个人收藏"）
  - Sign in with Apple 按钮（`ASAuthorizationAppleIDButton`）
  - 可选：账号密码登录入口

**已登录状态**：
- 正常显示播放列表 TableView
- 导航栏右上角显示用户头像

**状态切换时机**：
- `viewDidLoad` 时检查 `[XCUserInfoManager sharedInstance].isLogin`
- 监听登录成功通知（`NSNotificationCenter`），收到后刷新 UI

**Apple 官方按钮**（推荐使用，规避审核风险）：
```objc
ASAuthorizationAppleIDButton *appleButton =
    [[ASAuthorizationAppleIDButton alloc] initWithAuthorizationButtonType:ASAuthorizationAppleIDButtonTypeSignIn
                                                    authorizationButtonStyle:ASAuthorizationAppleIDButtonStyleBlack];
```
> Apple 审核要求：如果应用提供第三方登录，必须同时提供 Sign in with Apple，且按钮样式需符合 Apple HIG 规范，建议直接使用官方 `ASAuthorizationAppleIDButton`。

### 5.4 AppDelegate 或 SceneDelegate（启动时恢复会话）

在 app 启动时调用 `XCUserInfoManager` 的会话恢复逻辑，判断是否已登录，避免每次冷启动都要重新登录。

---

## 六、数据持久化策略

| 数据 | 存储位置 | 说明 |
|------|----------|------|
| App accessToken | KeyChain（`kAPIAccessTokenKey`） | 复用现有体系 |
| App refreshToken | KeyChain（`kAPIRefreshTokenKey`） | 复用现有体系 |
| Apple userIdentifier | NSUserDefaults | 用于凭证状态检查，非敏感数据 |
| 用户姓名（首次） | NSUserDefaults | Apple 只在首次授权时提供 |
| 用户头像 URL | NSUserDefaults 或内存 | 随 userInfo 一起存储 |
| 登录类型 | NSUserDefaults（`loginType: "apple"`） | 区分登录方式 |

---

## 七、错误处理

| 场景 | 处理方式 |
|------|----------|
| 用户取消授权 | 静默处理，不弹错误 |
| 网络请求失败 | Toast 提示"登录失败，请重试" |
| Apple 凭证撤销 | 监听 `ASAuthorizationAppleIDProviderCredentialRevokedNotification`，收到后清除登录状态，跳转登录页 |
| accessToken 过期 | 复用现有 `authRefreshAccountTokenWithCompletion:` 自动刷新 |
| 后端验证失败 | 提示"账号验证失败"，建议联系客服 |

**凭证撤销监听**（在 AppDelegate 中注册）：
```objc
[[NSNotificationCenter defaultCenter] addObserver:self
                                         selector:@selector(handleAppleIDCredentialRevoked:)
                                             name:ASAuthorizationAppleIDProviderCredentialRevokedNotification
                                           object:nil];
```

---

## 八、隐私与合规

1. **首次登录时收集的数据**：仅 userIdentifier（哈希值）、email（可能是 Apple 中转邮箱）、姓名，这些只在首次授权时提供，需在首次收到后立即保存到后端
2. **Apple 中转邮箱**：用户可以选择隐藏真实邮箱，Apple 会提供一个 `@privaterelay.appleid.com` 格式的中转邮箱，后端需要能够发送邮件到这个地址
3. **隐私政策**：需在 App Store Connect 和隐私政策中声明使用 Sign in with Apple

---

## 九、实施顺序建议

```
阶段 1：配置（不写代码）
├── Apple Developer Portal 开启 Sign in with Apple Capability
├── 重新下载 Provisioning Profile
└── Xcode 中添加 Capability

阶段 2：后端接口（配合后端）
└── 确认 POST /v1/auth/apple 接口协议

阶段 3：核心登录流程
├── XCNetworkManager 新增 loginWithAppleIdentityToken:... 方法
└── XCUserInfoManager 实现 loginWithApple 方法

阶段 4：UI 改造
├── XCPersonalViewController 添加未登录引导 UI
├── 接入 ASAuthorizationAppleIDButton
└── 监听登录状态通知更新 UI

阶段 5：会话持久化
├── AppDelegate 启动时恢复会话
└── 监听凭证撤销通知

阶段 6：测试
├── 首次登录（获取姓名和邮箱）
├── 再次登录（不再获取姓名和邮箱）
├── 凭证撤销场景
└── Token 过期自动刷新
```

---

## 十、文件改动清单

| 文件 | 改动类型 | 内容 |
|------|----------|------|
| `XCNetworkManager.h` | 新增声明 | `loginWithAppleIdentityToken:...` |
| `XCNetworkManager.m` | 新增实现 | Apple 登录网络请求 |
| `XCUserInfoManager.h` | 补充声明 | 登录状态通知名、`loginType` 枚举或常量 |
| `XCUserInfoManager.m` | 主要改动 | 实现 `loginWithApple`，启动时恢复会话 |
| `XCPersonalViewController.m` | 主要改动 | 未登录 UI、监听通知 |
| `AppDelegate.m` | 少量改动 | 注册凭证撤销通知监听 |
| `Spotify - clone.entitlements` | 自动生成 | Xcode 添加 Capability 后自动写入 |

---

## 十一、注意事项

1. **测试账号**：Sign in with Apple 在模拟器上可以正常测试（Xcode 13+ 支持在模拟器上使用 Sign in with Apple）
2. **真机需 Apple ID 已开启双重认证**：Sign in with Apple 要求开发者的设备绑定启用双重认证的 Apple ID
3. **App Store 审核要求**：若应用提供任何第三方登录（Google、微信等），Apple 要求必须同时提供 Sign in with Apple 选项
4. **首次 vs. 后续授权**：`fullName` 和 `email` 仅在用户首次授权时提供，后续授权这两个字段为 nil，后端收到 nil 时不要覆盖已存储的数据
5. **`ASAuthorizationAppleIDButton` 样式限制**：Apple 对按钮的尺寸、外观有最低要求，不能完全自定义，建议直接使用官方按钮避免审核问题
