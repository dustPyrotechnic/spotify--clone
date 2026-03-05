//
//  XCAuthViewController.m
//  Spotify - clone
//

#import "XCAuthViewController.h"
#import "XCAuthView.h"
#import "XCAuthService.h"

@interface XCAuthViewController () <XCAuthViewDelegate>
@property (nonatomic, strong) XCAuthView *authView;
@end

@implementation XCAuthViewController

#pragma mark - 生命周期

- (void)loadView {
    self.authView = [[XCAuthView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.authView.delegate = self;
    self.view = self.authView;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // 关闭按钮
    UIBarButtonItem *closeBtn = [[UIBarButtonItem alloc]
        initWithImage:[UIImage systemImageNamed:@"xmark"]
                style:UIBarButtonItemStylePlain
               target:self
               action:@selector(closeTapped)];
    closeBtn.tintColor = [UIColor whiteColor];
    self.navigationItem.rightBarButtonItem = closeBtn;

    // 根据当前登录状态决定初始界面
    if ([XCAuthService sharedInstance].isLoggedIn) {
        self.title = @"已登录";
        [self loadAndShowProfile];
    } else {
        self.title = @"账号";
        [self.authView showLoginMode];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:animated];

    UIColor *darkBg = [UIColor colorWithRed:0.071 green:0.071 blue:0.071 alpha:1];
    UINavigationBar *bar = self.navigationController.navigationBar;

    if (@available(iOS 15.0, *)) {
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        [appearance configureWithOpaqueBackground];
        appearance.backgroundColor = darkBg;
        appearance.titleTextAttributes = @{NSForegroundColorAttributeName: [UIColor whiteColor]};
        bar.standardAppearance   = appearance;
        bar.scrollEdgeAppearance = appearance;
        bar.compactAppearance    = appearance;
    } else {
        bar.barStyle      = UIBarStyleBlack;
        bar.translucent   = NO;
        bar.barTintColor  = darkBg;
    }
    bar.tintColor = [UIColor whiteColor];
}

#pragma mark - 关闭

- (void)closeTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - 加载已登录用户信息

- (void)loadAndShowProfile {
    XCAuthService *auth = [XCAuthService sharedInstance];
    // 先用本地缓存构造基础信息展示
    NSDictionary *localInfo = @{
        @"username": auth.username ?: @"-",
        @"userId":   auth.userId   ?: @"-",
        @"roles":    @[@"user"]
    };
    [self.authView showLoggedInWithUserInfo:localInfo];

    // 再从服务端拉取最新 profile
    [auth getProfileWithCompletion:^(BOOL success, NSDictionary *userInfo) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success && userInfo) {
                [self.authView showLoggedInWithUserInfo:userInfo];
            }
        });
    }];
}

#pragma mark - XCAuthViewDelegate

- (void)authViewDidTapLogin:(NSString *)username password:(NSString *)password {
    [self.authView setLoading:YES];

    [[XCAuthService sharedInstance] loginWithUsername:username
                                             password:password
                                           completion:^(BOOL success, NSDictionary *userInfo, NSString *message) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.authView setLoading:NO];
            if (success) {
                self.title = @"已登录";
                [self.authView showLoggedInWithUserInfo:userInfo ?: @{}];
            } else {
                [self.authView showError:message ?: @"登录失败"];
            }
        });
    }];
}

- (void)authViewDidTapRegister:(NSString *)username
                      password:(NSString *)password
               confirmPassword:(NSString *)confirmPassword {
    [self.authView setLoading:YES];

    [[XCAuthService sharedInstance] registerWithUsername:username
                                               password:password
                                        confirmPassword:confirmPassword
                                             completion:^(BOOL success, NSString *message) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.authView setLoading:NO];
            if (success) {
                // 注册成功后自动登录
                [self.authView showLoginMode];
                [self.authView showError:[NSString stringWithFormat:@"注册成功，请登录"]];
                self.authView.errorLabel.textColor = [UIColor systemGreenColor];
            } else {
                [self.authView showError:message ?: @"注册失败"];
            }
        });
    }];
}

- (void)authViewDidTapLogout {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"退出登录"
                         message:@"确认退出当前账号？"
                  preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"退出" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [[XCAuthService sharedInstance] logoutWithCompletion:^(BOOL success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.title = @"账号";
                [self.authView showLoginMode];
            });
        }];
    }]];

    [self presentViewController:alert animated:YES completion:nil];
}

@end
