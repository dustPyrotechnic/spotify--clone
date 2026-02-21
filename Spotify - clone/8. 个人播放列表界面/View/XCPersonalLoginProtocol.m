//
//  XCPersonalLoginProtocol.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/20.
//

#import "XCPersonalLoginProtocol.h"

#pragma mark - XCUserInfo 实现

static XCUserInfo* currentUserInstance = nil;
static NSString* const kCurrentUserKey = @"XCUserInfo_CurrentUser";

@implementation XCUserInfo

#pragma mark - 单例当前用户
+ (instancetype)currentUser {
    if (!currentUserInstance) {
        // 尝试从本地恢复
        NSData* data = [[NSUserDefaults standardUserDefaults] objectForKey:kCurrentUserKey];
        if (data) {
            currentUserInstance = [NSKeyedUnarchiver unarchivedObjectOfClass:[XCUserInfo class] 
                                                                    fromData:data 
                                                                       error:nil];
        }
    }
    return currentUserInstance;
}

+ (void)setCurrentUser:(XCUserInfo*)userInfo {
    currentUserInstance = userInfo;
    
    // 保存到本地
    if (userInfo) {
        NSData* data = [NSKeyedArchiver archivedDataWithRootObject:userInfo 
                                             requiringSecureCoding:YES 
                                                             error:nil];
        if (data) {
            [[NSUserDefaults standardUserDefaults] setObject:data forKey:kCurrentUserKey];
        }
    } else {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kCurrentUserKey];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (void)clearCurrentUser {
    currentUserInstance = nil;
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kCurrentUserKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - NSSecureCoding
+ (BOOL)supportsSecureCoding {
    return YES;
}

- (void)encodeWithCoder:(NSCoder*)coder {
    [coder encodeObject:self.userId forKey:@"userId"];
    [coder encodeObject:self.userName forKey:@"userName"];
    [coder encodeObject:self.nickName forKey:@"nickName"];
    [coder encodeObject:self.avatarUrl forKey:@"avatarUrl"];
    [coder encodeObject:self.localAvatarPath forKey:@"localAvatarPath"];
    [coder encodeObject:self.email forKey:@"email"];
    [coder encodeObject:self.phoneNumber forKey:@"phoneNumber"];
    [coder encodeObject:self.registerDate forKey:@"registerDate"];
    [coder encodeInteger:self.memberType forKey:@"memberType"];
    [coder encodeObject:self.memberExpireDate forKey:@"memberExpireDate"];
}

- (instancetype)initWithCoder:(NSCoder*)coder {
    self = [super init];
    if (self) {
        _userId = [coder decodeObjectOfClass:[NSString class] forKey:@"userId"];
        _userName = [coder decodeObjectOfClass:[NSString class] forKey:@"userName"];
        _nickName = [coder decodeObjectOfClass:[NSString class] forKey:@"nickName"];
        _avatarUrl = [coder decodeObjectOfClass:[NSString class] forKey:@"avatarUrl"];
        _localAvatarPath = [coder decodeObjectOfClass:[NSString class] forKey:@"localAvatarPath"];
        _email = [coder decodeObjectOfClass:[NSString class] forKey:@"email"];
        _phoneNumber = [coder decodeObjectOfClass:[NSString class] forKey:@"phoneNumber"];
        _registerDate = [coder decodeObjectOfClass:[NSDate class] forKey:@"registerDate"];
        _memberType = [coder decodeIntegerForKey:@"memberType"];
        _memberExpireDate = [coder decodeObjectOfClass:[NSDate class] forKey:@"memberExpireDate"];
    }
    return self;
}

#pragma mark - 便捷属性
- (BOOL)isVIP {
    if (self.memberType != 1) return NO;
    if (!self.memberExpireDate) return NO;
    return [self.memberExpireDate compare:[NSDate date]] == NSOrderedDescending;
}

- (NSString*)memberInfoText {
    if (!self.isVIP) return @"普通用户";
    
    NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd";
    return [NSString stringWithFormat:@"VIP 至 %@", [formatter stringFromDate:self.memberExpireDate]];
}

- (NSString*)displayName {
    if (self.nickName && self.nickName.length > 0) {
        return self.nickName;
    }
    return self.userName ?: @"未命名用户";
}

@end

#pragma mark - XCLoginManager 实现

@interface XCLoginManager ()
@property (nonatomic, assign, readwrite) XCLoginStatus loginStatus;
@property (nonatomic, strong, readwrite, nullable) XCUserInfo* currentUser;
@property (nonatomic, strong) NSMutableArray<id<XCLoginStatusObserver>>* observers;
@property (nonatomic, strong) dispatch_queue_t observerQueue;
@end

@implementation XCLoginManager

+ (instancetype)sharedManager {
    static XCLoginManager* instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[super allocWithZone:NULL] init];
    });
    return instance;
}

+ (instancetype)allocWithZone:(struct _NSZone*)zone {
    return [self sharedManager];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _loginStatus = XCLoginStatusUnknown;
        _observers = [NSMutableArray array];
        _observerQueue = dispatch_queue_create("com.spotifyclone.login.observers", DISPATCH_QUEUE_CONCURRENT);
        
        // 尝试恢复登录状态
        [self restoreLoginState];
    }
    return self;
}

#pragma mark - 登录状态检查
- (void)checkLoginStatusWithCompletion:(void(^)(XCLoginStatus status))completion {
    // 占位实现，日后完善
    // 这里应该检查 Token 是否有效
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 模拟检查过程
        [NSThread sleepForTimeInterval:0.1];
        
        // 如果有本地用户信息，认为已登录（实际应该检查 Token）
        XCUserInfo* user = [XCUserInfo currentUser];
        XCLoginStatus status = user ? XCLoginStatusLoggedIn : XCLoginStatusNotLoggedIn;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.loginStatus = status;
            self.currentUser = user;
            if (completion) {
                completion(status);
            }
        });
    });
}

#pragma mark - 登录/登出（占位实现）
- (void)loginWithAccount:(NSString*)account
                password:(NSString*)password
              completion:(void(^)(BOOL success, NSError* _Nullable error))completion {
    // 占位实现，日后完善
    // 这里应该调用实际的登录 API
    
    NSLog(@"[XCLoginManager] 登录接口被调用（占位实现）account: %@", account);
    
    // 模拟登录成功
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [NSThread sleepForTimeInterval:1.0];
        
        // 创建测试用户（日后替换为真实数据）
        XCUserInfo* user = [[XCUserInfo alloc] init];
        user.userId = @"test_user_001";
        user.userName = account;
        user.nickName = @"测试用户";
        user.registerDate = [NSDate date];
        user.memberType = 0;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.currentUser = user;
            self.loginStatus = XCLoginStatusLoggedIn;
            [XCUserInfo setCurrentUser:user];
            
            [self notifyObserversStatusChanged:XCLoginStatusLoggedIn];
            
            if (completion) {
                completion(YES, nil);
            }
        });
    });
}

- (void)logoutWithCompletion:(void(^)(BOOL success))completion {
    // 占位实现
    NSLog(@"[XCLoginManager] 登出接口被调用（占位实现）");
    
    self.currentUser = nil;
    self.loginStatus = XCLoginStatusNotLoggedIn;
    [XCUserInfo clearCurrentUser];
    
    [self notifyObserversStatusChanged:XCLoginStatusNotLoggedIn];
    
    if (completion) {
        completion(YES);
    }
}

#pragma mark - 观察者管理
- (void)addObserver:(id<XCLoginStatusObserver>)observer {
    dispatch_barrier_async(self.observerQueue, ^{
        if (![self.observers containsObject:observer]) {
            [self.observers addObject:observer];
        }
    });
}

- (void)removeObserver:(id<XCLoginStatusObserver>)observer {
    dispatch_barrier_async(self.observerQueue, ^{
        [self.observers removeObject:observer];
    });
}

- (void)notifyObserversStatusChanged:(XCLoginStatus)status {
    dispatch_async(self.observerQueue, ^{
        NSArray* observers = [self.observers copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            for (id<XCLoginStatusObserver> observer in observers) {
                if ([observer respondsToSelector:@selector(loginStatusDidChange:)]) {
                    [observer loginStatusDidChange:status];
                }
            }
        });
    });
}

- (void)notifyObserversUserInfoUpdated:(XCUserInfo*)userInfo {
    dispatch_async(self.observerQueue, ^{
        NSArray* observers = [self.observers copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            for (id<XCLoginStatusObserver> observer in observers) {
                if ([observer respondsToSelector:@selector(userInfoDidUpdate:)]) {
                    [observer userInfoDidUpdate:userInfo];
                }
            }
        });
    });
}

#pragma mark - 状态持久化
- (void)saveLoginState {
    // 已通过在 XCUserInfo 中实现
}

- (void)restoreLoginState {
    XCUserInfo* user = [XCUserInfo currentUser];
    if (user) {
        self.currentUser = user;
        self.loginStatus = XCLoginStatusLoggedIn;
    } else {
        self.loginStatus = XCLoginStatusNotLoggedIn;
    }
}

@end
