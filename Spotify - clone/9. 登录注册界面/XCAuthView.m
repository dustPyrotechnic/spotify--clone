//
//  XCAuthView.m
//  Spotify - clone
//

#import "XCAuthView.h"

// Spotify 配色
static UIColor *BackgroundColor(void) { return [UIColor colorWithRed:0.071 green:0.071 blue:0.071 alpha:1]; }
static UIColor *AccentColor(void)     { return [UIColor colorWithRed:0.114 green:0.725 blue:0.329 alpha:1]; }
static UIColor *FieldBgColor(void)    { return [UIColor colorWithRed:0.18  green:0.18  blue:0.18  alpha:1]; }

@interface XCAuthView ()
// 登录 / 注册
@property (nonatomic, strong) UISegmentedControl *segmentedControl;
@property (nonatomic, strong) UITextField        *usernameField;
@property (nonatomic, strong) UITextField        *passwordField;
@property (nonatomic, strong) UITextField        *confirmPasswordField;
@property (nonatomic, strong) UIButton           *actionButton;
@property (nonatomic, strong) UILabel            *errorLabel;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;

// 已登录区域
@property (nonatomic, strong) UIView  *loggedInView;
@property (nonatomic, strong) UILabel *loggedInUsernameLabel;
@property (nonatomic, strong) UILabel *loggedInUserIdLabel;
@property (nonatomic, strong) UILabel *loggedInRolesLabel;
@property (nonatomic, strong) UIButton *logoutButton;

// 登录 / 注册容器
@property (nonatomic, strong) UIView *authContainerView;

// 顶部标题（需要在已登录态隐藏）
@property (nonatomic, strong) UILabel *topTitleLabel;
@end

@implementation XCAuthView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = BackgroundColor();
        [self buildUI];
    }
    return self;
}

#pragma mark - UI 构建

- (void)buildUI {
    // 顶部标题（已登录时隐藏）
    _topTitleLabel = [[UILabel alloc] init];
    _topTitleLabel.text = @"账号";
    _topTitleLabel.font = [UIFont boldSystemFontOfSize:28];
    _topTitleLabel.textColor = [UIColor whiteColor];
    _topTitleLabel.textAlignment = NSTextAlignmentCenter;
    _topTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_topTitleLabel];

    // 分段控制
    _segmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"登录", @"注册"]];
    _segmentedControl.selectedSegmentIndex = 0;
    _segmentedControl.tintColor = AccentColor();
    if (@available(iOS 13.0, *)) {
        _segmentedControl.selectedSegmentTintColor = AccentColor();
        NSDictionary *normalAttr = @{NSForegroundColorAttributeName: [UIColor lightGrayColor]};
        NSDictionary *selectedAttr = @{NSForegroundColorAttributeName: [UIColor whiteColor]};
        [_segmentedControl setTitleTextAttributes:normalAttr forState:UIControlStateNormal];
        [_segmentedControl setTitleTextAttributes:selectedAttr forState:UIControlStateSelected];
    }
    [_segmentedControl addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
    _segmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_segmentedControl];

    // 登录 / 注册容器
    _authContainerView = [[UIView alloc] init];
    _authContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_authContainerView];

    // 输入框
    _usernameField      = [self makeTextField:@"用户名" secure:NO];
    _passwordField      = [self makeTextField:@"密码" secure:YES];
    _confirmPasswordField = [self makeTextField:@"确认密码" secure:YES];

    [_authContainerView addSubview:_usernameField];
    [_authContainerView addSubview:_passwordField];
    [_authContainerView addSubview:_confirmPasswordField];
    _confirmPasswordField.hidden = YES;

    // 操作按钮（Custom 类型避免 system tintColor 干扰标题颜色）
    _actionButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_actionButton setTitle:@"登录" forState:UIControlStateNormal];
    [_actionButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [_actionButton setTitleColor:[[UIColor whiteColor] colorWithAlphaComponent:0.6] forState:UIControlStateHighlighted];
    _actionButton.backgroundColor = AccentColor();
    _actionButton.layer.cornerRadius = 24;
    _actionButton.clipsToBounds = YES;
    _actionButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [_actionButton addTarget:self action:@selector(actionButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    _actionButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_authContainerView addSubview:_actionButton];

    // 错误标签
    _errorLabel = [[UILabel alloc] init];
    _errorLabel.textColor = [UIColor systemRedColor];
    _errorLabel.font = [UIFont systemFontOfSize:13];
    _errorLabel.textAlignment = NSTextAlignmentCenter;
    _errorLabel.numberOfLines = 0;
    _errorLabel.hidden = YES;
    _errorLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [_authContainerView addSubview:_errorLabel];

    // Spinner
    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    _spinner.color = AccentColor();
    _spinner.hidesWhenStopped = YES;
    _spinner.translatesAutoresizingMaskIntoConstraints = NO;
    [_authContainerView addSubview:_spinner];

    // 已登录视图
    [self buildLoggedInView];

    // 约束
    [NSLayoutConstraint activateConstraints:@[
        [_topTitleLabel.topAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.topAnchor constant:32],
        [_topTitleLabel.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],

        [_segmentedControl.topAnchor constraintEqualToAnchor:_topTitleLabel.bottomAnchor constant:24],
        [_segmentedControl.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:32],
        [_segmentedControl.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-32],
        [_segmentedControl.heightAnchor constraintEqualToConstant:36],

        [_authContainerView.topAnchor constraintEqualToAnchor:_segmentedControl.bottomAnchor constant:32],
        [_authContainerView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:32],
        [_authContainerView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-32],

        [_usernameField.topAnchor constraintEqualToAnchor:_authContainerView.topAnchor],
        [_usernameField.leadingAnchor constraintEqualToAnchor:_authContainerView.leadingAnchor],
        [_usernameField.trailingAnchor constraintEqualToAnchor:_authContainerView.trailingAnchor],
        [_usernameField.heightAnchor constraintEqualToConstant:48],

        [_passwordField.topAnchor constraintEqualToAnchor:_usernameField.bottomAnchor constant:12],
        [_passwordField.leadingAnchor constraintEqualToAnchor:_authContainerView.leadingAnchor],
        [_passwordField.trailingAnchor constraintEqualToAnchor:_authContainerView.trailingAnchor],
        [_passwordField.heightAnchor constraintEqualToConstant:48],

        [_confirmPasswordField.topAnchor constraintEqualToAnchor:_passwordField.bottomAnchor constant:12],
        [_confirmPasswordField.leadingAnchor constraintEqualToAnchor:_authContainerView.leadingAnchor],
        [_confirmPasswordField.trailingAnchor constraintEqualToAnchor:_authContainerView.trailingAnchor],
        [_confirmPasswordField.heightAnchor constraintEqualToConstant:48],

        [_actionButton.topAnchor constraintEqualToAnchor:_confirmPasswordField.bottomAnchor constant:24],
        [_actionButton.leadingAnchor constraintEqualToAnchor:_authContainerView.leadingAnchor],
        [_actionButton.trailingAnchor constraintEqualToAnchor:_authContainerView.trailingAnchor],
        [_actionButton.heightAnchor constraintEqualToConstant:48],

        [_errorLabel.topAnchor constraintEqualToAnchor:_actionButton.bottomAnchor constant:12],
        [_errorLabel.leadingAnchor constraintEqualToAnchor:_authContainerView.leadingAnchor],
        [_errorLabel.trailingAnchor constraintEqualToAnchor:_authContainerView.trailingAnchor],
        [_errorLabel.bottomAnchor constraintEqualToAnchor:_authContainerView.bottomAnchor],

        [_spinner.centerXAnchor constraintEqualToAnchor:_actionButton.centerXAnchor],
        [_spinner.centerYAnchor constraintEqualToAnchor:_actionButton.centerYAnchor],

        [_loggedInView.topAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.topAnchor constant:32],
        [_loggedInView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:32],
        [_loggedInView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-32],
    ]];
}

- (void)buildLoggedInView {
    _loggedInView = [[UIView alloc] init];
    _loggedInView.hidden = YES;
    _loggedInView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_loggedInView];

    UIImageView *avatarView = [[UIImageView alloc] init];
    avatarView.image = [UIImage systemImageNamed:@"person.circle.fill"];
    avatarView.tintColor = AccentColor();
    avatarView.contentMode = UIViewContentModeScaleAspectFit;
    avatarView.translatesAutoresizingMaskIntoConstraints = NO;

    _loggedInUsernameLabel = [self makeInfoLabel:@"用户名：-"];
    _loggedInUserIdLabel   = [self makeInfoLabel:@"ID：-"];
    _loggedInRolesLabel    = [self makeInfoLabel:@"角色：-"];

    _logoutButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_logoutButton setTitle:@"退出登录" forState:UIControlStateNormal];
    [_logoutButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [_logoutButton setTitleColor:[[UIColor whiteColor] colorWithAlphaComponent:0.6] forState:UIControlStateHighlighted];
    _logoutButton.backgroundColor = [UIColor colorWithRed:0.85 green:0.2 blue:0.2 alpha:1];
    _logoutButton.layer.cornerRadius = 24;
    _logoutButton.clipsToBounds = YES;
    _logoutButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [_logoutButton addTarget:self action:@selector(logoutTapped) forControlEvents:UIControlEventTouchUpInside];
    _logoutButton.translatesAutoresizingMaskIntoConstraints = NO;

    [_loggedInView addSubview:avatarView];
    [_loggedInView addSubview:_loggedInUsernameLabel];
    [_loggedInView addSubview:_loggedInUserIdLabel];
    [_loggedInView addSubview:_loggedInRolesLabel];
    [_loggedInView addSubview:_logoutButton];

    [NSLayoutConstraint activateConstraints:@[
        [avatarView.topAnchor constraintEqualToAnchor:_loggedInView.topAnchor],
        [avatarView.centerXAnchor constraintEqualToAnchor:_loggedInView.centerXAnchor],
        [avatarView.widthAnchor constraintEqualToConstant:80],
        [avatarView.heightAnchor constraintEqualToConstant:80],

        [_loggedInUsernameLabel.topAnchor constraintEqualToAnchor:avatarView.bottomAnchor constant:24],
        [_loggedInUsernameLabel.leadingAnchor constraintEqualToAnchor:_loggedInView.leadingAnchor],
        [_loggedInUsernameLabel.trailingAnchor constraintEqualToAnchor:_loggedInView.trailingAnchor],

        [_loggedInUserIdLabel.topAnchor constraintEqualToAnchor:_loggedInUsernameLabel.bottomAnchor constant:12],
        [_loggedInUserIdLabel.leadingAnchor constraintEqualToAnchor:_loggedInView.leadingAnchor],
        [_loggedInUserIdLabel.trailingAnchor constraintEqualToAnchor:_loggedInView.trailingAnchor],

        [_loggedInRolesLabel.topAnchor constraintEqualToAnchor:_loggedInUserIdLabel.bottomAnchor constant:12],
        [_loggedInRolesLabel.leadingAnchor constraintEqualToAnchor:_loggedInView.leadingAnchor],
        [_loggedInRolesLabel.trailingAnchor constraintEqualToAnchor:_loggedInView.trailingAnchor],

        [_logoutButton.topAnchor constraintEqualToAnchor:_loggedInRolesLabel.bottomAnchor constant:36],
        [_logoutButton.leadingAnchor constraintEqualToAnchor:_loggedInView.leadingAnchor],
        [_logoutButton.trailingAnchor constraintEqualToAnchor:_loggedInView.trailingAnchor],
        [_logoutButton.heightAnchor constraintEqualToConstant:48],
        [_logoutButton.bottomAnchor constraintEqualToAnchor:_loggedInView.bottomAnchor],
    ]];
}

#pragma mark - 工厂方法

- (UITextField *)makeTextField:(NSString *)placeholder secure:(BOOL)secure {
    UITextField *field = [[UITextField alloc] init];
    field.placeholder = placeholder;
    field.secureTextEntry = secure;
    field.textColor = [UIColor whiteColor];
    field.backgroundColor = FieldBgColor();
    field.layer.cornerRadius = 8;
    field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.returnKeyType = UIReturnKeyDone;
    // Padding
    UIView *paddingView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 48)];
    field.leftView = paddingView;
    field.leftViewMode = UITextFieldViewModeAlways;
    field.translatesAutoresizingMaskIntoConstraints = NO;
    // Placeholder 颜色
    field.attributedPlaceholder = [[NSAttributedString alloc]
        initWithString:placeholder
            attributes:@{NSForegroundColorAttributeName: [UIColor colorWithWhite:0.6 alpha:1]}];
    return field;
}

- (UILabel *)makeInfoLabel:(NSString *)text {
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.textColor = [UIColor colorWithWhite:0.85 alpha:1];
    label.font = [UIFont systemFontOfSize:16];
    label.textAlignment = NSTextAlignmentCenter;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    return label;
}

#pragma mark - 公开方法

- (void)showLoginMode {
    _loggedInView.hidden = YES;
    _authContainerView.hidden = NO;
    _segmentedControl.hidden = NO;
    _topTitleLabel.hidden = NO;
    _segmentedControl.selectedSegmentIndex = 0;
    _confirmPasswordField.hidden = YES;
    [_actionButton setTitle:@"登录" forState:UIControlStateNormal];
    [self clearError];
    [_usernameField becomeFirstResponder];
}

- (void)showRegisterMode {
    _loggedInView.hidden = YES;
    _authContainerView.hidden = NO;
    _segmentedControl.hidden = NO;
    _topTitleLabel.hidden = NO;
    _segmentedControl.selectedSegmentIndex = 1;
    _confirmPasswordField.hidden = NO;
    [_actionButton setTitle:@"注册" forState:UIControlStateNormal];
    [self clearError];
}

- (void)showLoggedInWithUserInfo:(NSDictionary *)userInfo {
    _authContainerView.hidden = YES;
    _segmentedControl.hidden = YES;
    _topTitleLabel.hidden = YES;
    _loggedInView.hidden = NO;

    NSString *uname  = userInfo[@"username"] ?: @"-";
    NSString *uid    = userInfo[@"userId"]   ?: @"-";
    id rolesRaw      = userInfo[@"roles"];
    NSString *roles  = @"user";
    if ([rolesRaw isKindOfClass:[NSArray class]]) {
        roles = [rolesRaw componentsJoinedByString:@", "];
    }

    _loggedInUsernameLabel.text = [NSString stringWithFormat:@"用户名：%@", uname];
    _loggedInUserIdLabel.text   = [NSString stringWithFormat:@"ID：%@", uid];
    _loggedInRolesLabel.text    = [NSString stringWithFormat:@"角色：%@", roles];
}

- (void)showError:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.errorLabel.text = message;
        self.errorLabel.hidden = (message.length == 0);
    });
}

- (void)clearError {
    _errorLabel.text = @"";
    _errorLabel.hidden = YES;
}

- (void)setLoading:(BOOL)loading {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (loading) {
            [self.spinner startAnimating];
            self.actionButton.hidden = YES;
        } else {
            [self.spinner stopAnimating];
            self.actionButton.hidden = NO;
        }
    });
}

#pragma mark - 事件

- (void)segmentChanged:(UISegmentedControl *)sender {
    [self clearError];
    if (sender.selectedSegmentIndex == 0) {
        [self showLoginMode];
    } else {
        [self showRegisterMode];
    }
}

- (void)actionButtonTapped {
    [self endEditing:YES];
    [self clearError];
    if (_segmentedControl.selectedSegmentIndex == 0) {
        [self.delegate authViewDidTapLogin:_usernameField.text
                                  password:_passwordField.text];
    } else {
        [self.delegate authViewDidTapRegister:_usernameField.text
                                     password:_passwordField.text
                              confirmPassword:_confirmPasswordField.text];
    }
}

- (void)logoutTapped {
    [self.delegate authViewDidTapLogout];
}

@end
