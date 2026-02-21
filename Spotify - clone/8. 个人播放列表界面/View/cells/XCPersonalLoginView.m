//
//  XCPersonalLoginView.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/20.
//

#import "XCPersonalLoginView.h"
#import <Masonry/Masonry.h>

@interface XCPersonalLoginView ()
@property (nonatomic, strong, readwrite) UIImageView* iconImageView;
@property (nonatomic, strong, readwrite) UILabel* titleLabel;
@property (nonatomic, strong, readwrite) UILabel* subtitleLabel;
@property (nonatomic, strong, readwrite) UIButton* loginButton;
@property (nonatomic, strong) UIActivityIndicatorView* loadingIndicator;
@end

@implementation XCPersonalLoginView

#pragma mark - 初始化
- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupView];
        _loginStatus = XCLoginStatusUnknown;
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupView];
        _loginStatus = XCLoginStatusUnknown;
    }
    return self;
}

#pragma mark - 视图设置
- (void)setupView {
    self.backgroundColor = [UIColor clearColor];
    
    // 图标
    self.iconImageView = [[UIImageView alloc] init];
    self.iconImageView.image = [UIImage systemImageNamed:@"person.crop.circle"];
    self.iconImageView.tintColor = [UIColor systemGray3Color];
    self.iconImageView.contentMode = UIViewContentModeScaleAspectFit;
    [self addSubview:self.iconImageView];
    
    // 标题
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = @"登录以查看您的播放列表";
    self.titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightSemibold];
    self.titleLabel.textColor = [UIColor labelColor];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    [self addSubview:self.titleLabel];
    
    // 副标题
    self.subtitleLabel = [[UILabel alloc] init];
    self.subtitleLabel.text = @"登录后可以创建和管理您的个人播放列表，同步您的音乐收藏";
    self.subtitleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
    self.subtitleLabel.textColor = [UIColor secondaryLabelColor];
    self.subtitleLabel.textAlignment = NSTextAlignmentCenter;
    self.subtitleLabel.numberOfLines = 0;
    [self addSubview:self.subtitleLabel];
    
    // 登录按钮
    self.loginButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.loginButton setTitle:@"登录" forState:UIControlStateNormal];
    [self.loginButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.loginButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    self.loginButton.backgroundColor = [UIColor systemGreenColor];
    self.loginButton.layer.cornerRadius = 25;
    self.loginButton.clipsToBounds = YES;
    [self.loginButton addTarget:self action:@selector(loginButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.loginButton];
    
    // 加载指示器
    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.loadingIndicator.color = [UIColor whiteColor];
    self.loadingIndicator.hidesWhenStopped = YES;
    [self.loginButton addSubview:self.loadingIndicator];
    
    // 设置约束
    [self setupConstraints];
}

- (void)setupConstraints {
    // 图标
    [self.iconImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self);
        make.top.equalTo(self).offset(60);
        make.width.height.mas_equalTo(80);
    }];
    
    // 标题
    [self.titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self);
        make.top.equalTo(self.iconImageView.mas_bottom).offset(24);
        make.left.equalTo(self).offset(20);
        make.right.equalTo(self).offset(-20);
    }];
    
    // 副标题
    [self.subtitleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self);
        make.top.equalTo(self.titleLabel.mas_bottom).offset(12);
        make.left.right.equalTo(self.titleLabel);
    }];
    
    // 登录按钮
    [self.loginButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self);
        make.top.equalTo(self.subtitleLabel.mas_bottom).offset(32);
        make.width.mas_equalTo(160);
        make.height.mas_equalTo(50);
    }];
    
    // 加载指示器
    [self.loadingIndicator mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self.loginButton);
    }];
}

#pragma mark - 事件处理
- (void)loginButtonTapped:(id)sender {
    if (self.loginButtonTapHandler) {
        self.loginButtonTapHandler();
    }
}

#pragma mark - Setter
- (void)setLoginStatus:(XCLoginStatus)loginStatus {
    _loginStatus = loginStatus;
    
    switch (loginStatus) {
        case XCLoginStatusUnknown:
            self.titleLabel.text = @"正在检查登录状态...";
            self.subtitleLabel.text = @"";
            self.loginButton.hidden = YES;
            break;
            
        case XCLoginStatusNotLoggedIn:
        case XCLoginStatusLoginExpired:
            self.titleLabel.text = @"登录以查看您的播放列表";
            self.subtitleLabel.text = @"登录后可以创建和管理您的个人播放列表，同步您的音乐收藏";
            self.loginButton.hidden = NO;
            [self.loginButton setTitle:@"登录" forState:UIControlStateNormal];
            self.loginButton.enabled = YES;
            [self.loadingIndicator stopAnimating];
            break;
            
        case XCLoginStatusLoggingIn:
            self.titleLabel.text = @"正在登录...";
            self.subtitleLabel.text = @"请稍候";
            self.loginButton.hidden = NO;
            [self.loginButton setTitle:@"" forState:UIControlStateNormal];
            self.loginButton.enabled = NO;
            [self.loadingIndicator startAnimating];
            break;
            
        case XCLoginStatusLoggedIn:
            self.titleLabel.text = @"已登录";
            self.subtitleLabel.text = @"正在加载您的播放列表";
            self.loginButton.hidden = YES;
            [self.loadingIndicator stopAnimating];
            break;
    }
}

@end
