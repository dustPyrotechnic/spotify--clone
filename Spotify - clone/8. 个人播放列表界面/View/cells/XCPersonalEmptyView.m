//
//  XCPersonalEmptyView.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/20.
//

#import "XCPersonalEmptyView.h"
#import <Masonry/Masonry.h>

@interface XCPersonalEmptyView ()
@property (nonatomic, strong, readwrite) UIImageView* iconImageView;
@property (nonatomic, strong, readwrite) UILabel* titleLabel;
@property (nonatomic, strong, readwrite) UILabel* subtitleLabel;
@property (nonatomic, strong, readwrite) UIButton* createButton;
@end

@implementation XCPersonalEmptyView

#pragma mark - 初始化
- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupView];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupView];
    }
    return self;
}

#pragma mark - 视图设置
- (void)setupView {
    self.backgroundColor = [UIColor clearColor];
    
    // 图标
    self.iconImageView = [[UIImageView alloc] init];
    self.iconImageView.image = [UIImage systemImageNamed:@"music.note.list"];
    self.iconImageView.tintColor = [UIColor systemGray3Color];
    self.iconImageView.contentMode = UIViewContentModeScaleAspectFit;
    [self addSubview:self.iconImageView];
    
    // 标题
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = @"还没有播放列表";
    self.titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightSemibold];
    self.titleLabel.textColor = [UIColor labelColor];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    [self addSubview:self.titleLabel];
    
    // 副标题
    self.subtitleLabel = [[UILabel alloc] init];
    self.subtitleLabel.text = @"点击左上角 + 创建你的第一个播放列表";
    self.subtitleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
    self.subtitleLabel.textColor = [UIColor secondaryLabelColor];
    self.subtitleLabel.textAlignment = NSTextAlignmentCenter;
    self.subtitleLabel.numberOfLines = 0;
    [self addSubview:self.subtitleLabel];
    
    // 创建按钮
    self.createButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.createButton setTitle:@"+ 创建播放列表" forState:UIControlStateNormal];
    [self.createButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.createButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    self.createButton.backgroundColor = [UIColor systemGreenColor];
    self.createButton.layer.cornerRadius = 25;
    self.createButton.clipsToBounds = YES;
    [self.createButton addTarget:self action:@selector(createButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.createButton];
    
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
    
    // 创建按钮
    [self.createButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self);
        make.top.equalTo(self.subtitleLabel.mas_bottom).offset(32);
        make.width.mas_equalTo(160);
        make.height.mas_equalTo(50);
    }];
}

#pragma mark - 事件处理
- (void)createButtonTapped:(id)sender {
    if (self.createButtonTapHandler) {
        self.createButtonTapHandler();
    }
}

#pragma mark - 配置
- (void)showCreateButton:(BOOL)show {
    self.createButton.hidden = !show;
}

@end
