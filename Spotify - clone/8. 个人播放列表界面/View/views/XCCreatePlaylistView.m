//
//  XCCreatePlaylistView.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/20.
//

#import "XCCreatePlaylistView.h"
#import <Masonry/Masonry.h>

@interface XCCreatePlaylistView () <UITextFieldDelegate>
@property (nonatomic, strong, readwrite) UIView* backdropView;
@property (nonatomic, strong, readwrite) UIView* containerView;
@property (nonatomic, strong, readwrite) UILabel* titleLabel;
@property (nonatomic, strong, readwrite) UITextField* nameTextField;
@property (nonatomic, strong, readwrite) UIButton* cancelButton;
@property (nonatomic, strong, readwrite) UIButton* createButton;
@property (nonatomic, weak) UIView* parentView;
@end

@implementation XCCreatePlaylistView

#pragma mark - 初始化
- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupView];
    }
    return self;
}

#pragma mark - 视图设置
- (void)setupView {
    self.frame = [UIScreen mainScreen].bounds;
    self.backgroundColor = [UIColor clearColor];
    
    // 背景遮罩
    self.backdropView = [[UIView alloc] init];
    self.backdropView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
    self.backdropView.alpha = 0;
    [self addSubview:self.backdropView];
    
    // 点击背景关闭
    UITapGestureRecognizer* tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(backdropTapped:)];
    [self.backdropView addGestureRecognizer:tapGesture];
    
    // 内容容器
    self.containerView = [[UIView alloc] init];
    self.containerView.backgroundColor = [UIColor systemBackgroundColor];
    self.containerView.layer.cornerRadius = 16;
    self.containerView.clipsToBounds = YES;
    self.containerView.alpha = 0;
    self.containerView.transform = CGAffineTransformMakeScale(0.9, 0.9);
    [self addSubview:self.containerView];
    
    // 标题
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = @"新建播放列表";
    self.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    self.titleLabel.textColor = [UIColor labelColor];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.containerView addSubview:self.titleLabel];
    
    // 输入框
    self.nameTextField = [[UITextField alloc] init];
    self.nameTextField.placeholder = @"播放列表名称";
    self.nameTextField.font = [UIFont systemFontOfSize:16];
    self.nameTextField.textColor = [UIColor labelColor];
    self.nameTextField.borderStyle = UITextBorderStyleNone;
    self.nameTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.nameTextField.returnKeyType = UIReturnKeyDone;
    self.nameTextField.delegate = self;
    [self.containerView addSubview:self.nameTextField];
    
    // 输入框底部分割线
    UIView* textFieldLine = [[UIView alloc] init];
    textFieldLine.backgroundColor = [UIColor separatorColor];
    [self.containerView addSubview:textFieldLine];
    
    // 按钮容器
    UIView* buttonContainer = [[UIView alloc] init];
    [self.containerView addSubview:buttonContainer];
    
    // 取消按钮
    self.cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.cancelButton setTitle:@"取消" forState:UIControlStateNormal];
    [self.cancelButton setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
    self.cancelButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    [self.cancelButton addTarget:self action:@selector(cancelButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [buttonContainer addSubview:self.cancelButton];
    
    // 创建按钮
    self.createButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.createButton setTitle:@"创建" forState:UIControlStateNormal];
    [self.createButton setTitleColor:[UIColor systemGreenColor] forState:UIControlStateNormal];
    self.createButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    [self.createButton addTarget:self action:@selector(createButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [buttonContainer addSubview:self.createButton];
    
    // 设置约束
    [self.backdropView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self);
    }];
    
    [self.containerView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self);
        make.left.equalTo(self).offset(40);
        make.right.equalTo(self).offset(-40);
    }];
    
    [self.titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.containerView).offset(20);
        make.left.right.equalTo(self.containerView);
    }];
    
    [self.nameTextField mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.titleLabel.mas_bottom).offset(20);
        make.left.equalTo(self.containerView).offset(20);
        make.right.equalTo(self.containerView).offset(-20);
        make.height.mas_equalTo(44);
    }];
    
    [textFieldLine mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.nameTextField.mas_bottom);
        make.left.right.equalTo(self.nameTextField);
        make.height.mas_equalTo(0.5);
    }];
    
    [buttonContainer mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(textFieldLine.mas_bottom).offset(20);
        make.left.right.bottom.equalTo(self.containerView);
        make.height.mas_equalTo(50);
    }];
    
    [self.cancelButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.top.bottom.equalTo(buttonContainer);
        make.width.equalTo(buttonContainer).multipliedBy(0.5);
    }];
    
    [self.createButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.top.bottom.equalTo(buttonContainer);
        make.width.equalTo(buttonContainer).multipliedBy(0.5);
    }];
}

#pragma mark - 显示/隐藏
- (void)showInView:(UIView*)view {
    self.parentView = view;
    [view addSubview:self];
    
    // 聚焦输入框
    [self.nameTextField becomeFirstResponder];
    
    // 动画显示
    [UIView animateWithDuration:0.25 animations:^{
        self.backdropView.alpha = 1.0;
        self.containerView.alpha = 1.0;
        self.containerView.transform = CGAffineTransformIdentity;
    }];
}

- (void)dismiss {
    [self.nameTextField resignFirstResponder];
    
    [UIView animateWithDuration:0.2 animations:^{
        self.backdropView.alpha = 0;
        self.containerView.alpha = 0;
        self.containerView.transform = CGAffineTransformMakeScale(0.9, 0.9);
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

#pragma mark - 事件处理
- (void)backdropTapped:(UITapGestureRecognizer*)gesture {
    [self cancelButtonTapped:nil];
}

- (void)cancelButtonTapped:(id)sender {
    if (self.cancelHandler) {
        self.cancelHandler();
    }
    [self dismiss];
}

- (void)createButtonTapped:(id)sender {
    NSString* name = self.nameTextField.text ?: @"";
    name = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if (name.length == 0) {
        // 震动提示
        UIImpactFeedbackGenerator* feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [feedback impactOccurred];
        return;
    }
    
    if (self.createHandler) {
        self.createHandler(name);
    }
    [self dismiss];
}

#pragma mark - UITextFieldDelegate
- (BOOL)textFieldShouldReturn:(UITextField*)textField {
    [self createButtonTapped:nil];
    return YES;
}

@end
