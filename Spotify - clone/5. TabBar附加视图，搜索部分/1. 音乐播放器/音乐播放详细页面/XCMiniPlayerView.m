//
//  XCMiniPlayerView.m
//  Spotify - clone
//

#import "XCMiniPlayerView.h"
#import <Masonry/Masonry.h>

@implementation XCMiniPlayerView

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    [self setupUI];
  }
  return self;
}

- (void)setupUI {
  self.albumImageView = [[UIImageView alloc] init];
  self.albumImageView.contentMode = UIViewContentModeScaleAspectFill;
  self.albumImageView.clipsToBounds = YES;
  self.albumImageView.layer.cornerRadius = 10;
  self.albumImageView.backgroundColor = [UIColor systemGray5Color];
  // 添加柔和阴影
  self.albumImageView.layer.shadowColor = [UIColor blackColor].CGColor;
  self.albumImageView.layer.shadowOffset = CGSizeMake(0, 4);
  self.albumImageView.layer.shadowRadius = 8;
  self.albumImageView.layer.shadowOpacity = 0.25;
  [self addSubview:self.albumImageView];

  // ========== 右上区域：歌曲信息 ==========
  // 歌曲名 - 增大字号，加粗
  self.songNameLabel = [[UILabel alloc] init];
  self.songNameLabel.font = [UIFont boldSystemFontOfSize:17];
  self.songNameLabel.textColor = [UIColor whiteColor];
  self.songNameLabel.numberOfLines = 1;
  self.songNameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
  [self addSubview:self.songNameLabel];

  // 艺术家 - 使用更柔和的颜色
  self.artistLabel = [[UILabel alloc] init];
  self.artistLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
  self.artistLabel.textColor = [UIColor colorWithWhite:0.75 alpha:0.9];
  self.artistLabel.numberOfLines = 1;
  self.artistLabel.lineBreakMode = NSLineBreakByTruncatingTail;
  [self addSubview:self.artistLabel];

  // ========== 中间：播放控制按钮组 ==========
  // 播放控制按钮配置 - 统一大小
  UIImageSymbolConfiguration *ctrlCfg = [UIImageSymbolConfiguration
    configurationWithPointSize:20 weight:UIImageSymbolWeightMedium];
  
  // 上一首按钮
  self.prevButton = [[UIButton alloc] init];
  [self.prevButton setImage:[UIImage systemImageNamed:@"backward.fill"
                                    withConfiguration:ctrlCfg]
                   forState:UIControlStateNormal];
  self.prevButton.tintColor = [UIColor whiteColor];
  [self addButtonPressEffect:self.prevButton];
  [self addSubview:self.prevButton];

  // 播放/暂停按钮 - 突出显示，圆形背景
  self.playPauseButton = [[UIButton alloc] init];
  self.playPauseButton.backgroundColor = [UIColor whiteColor];
  self.playPauseButton.layer.cornerRadius = 26;
  // 阴影效果
  self.playPauseButton.layer.shadowColor = [UIColor blackColor].CGColor;
  self.playPauseButton.layer.shadowOffset = CGSizeMake(0, 3);
  self.playPauseButton.layer.shadowRadius = 6;
  self.playPauseButton.layer.shadowOpacity = 0.2;
  
  UIImageSymbolConfiguration *playCfg = [UIImageSymbolConfiguration
    configurationWithPointSize:22 weight:UIImageSymbolWeightBold];
  [self.playPauseButton setImage:[UIImage systemImageNamed:@"play.fill"
                                        withConfiguration:playCfg]
                        forState:UIControlStateNormal];
  [self.playPauseButton setTintColor:[UIColor blackColor]];
  [self addButtonPressEffect:self.playPauseButton];
  [self addSubview:self.playPauseButton];

  // 下一首按钮
  self.nextButton = [[UIButton alloc] init];
  [self.nextButton setImage:[UIImage systemImageNamed:@"forward.fill"
                                   withConfiguration:ctrlCfg]
                  forState:UIControlStateNormal];
  self.nextButton.tintColor = [UIColor whiteColor];
  [self addButtonPressEffect:self.nextButton];
  [self addSubview:self.nextButton];

  // ========== 两侧功能按钮 ==========
  // 随机播放按钮 - 左侧，较小的辅助按钮
  UIImageSymbolConfiguration *smallCfg = [UIImageSymbolConfiguration
    configurationWithPointSize:16 weight:UIImageSymbolWeightMedium];
  self.shuffleButton = [[UIButton alloc] init];
  [self.shuffleButton setImage:[UIImage systemImageNamed:@"shuffle"
                                       withConfiguration:smallCfg]
                      forState:UIControlStateNormal];
  self.shuffleButton.tintColor = [UIColor colorWithWhite:0.6 alpha:1];
  [self addButtonPressEffect:self.shuffleButton];
  [self addSubview:self.shuffleButton];

  // 评论按钮 - 右侧，高亮但不过于突兀
  self.commentButton = [[UIButton alloc] init];
  [self.commentButton setImage:[UIImage systemImageNamed:@"message.fill"
                                       withConfiguration:smallCfg]
                      forState:UIControlStateNormal];
  self.commentButton.tintColor = [UIColor systemGreenColor];
  self.commentButton.alpha = 0.9;
  [self addButtonPressEffect:self.commentButton];
  [self addSubview:self.commentButton];

  // ========== 底部：进度条 ==========
  self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
  self.progressView.progressTintColor = [UIColor whiteColor];
  self.progressView.trackTintColor = [UIColor colorWithWhite:1.0 alpha:0.2];
  // 更粗的进度条，易于观察
  self.progressView.layer.cornerRadius = 2.5;
  self.progressView.clipsToBounds = YES;
  [self addSubview:self.progressView];

  [self setupConstraints];
}

- (void)setupConstraints {
  // 基础尺寸定义
  CGFloat margin = 20;                    // 左右边距
  CGFloat albumSize = 76;                 // 专辑封面尺寸（稍大）
  CGFloat albumToContentGap = 16;         // 封面到内容的间距
  CGFloat rightContentX = margin + albumSize + albumToContentGap;
  
  // 专辑封面：左侧垂直居中
  [self.albumImageView mas_makeConstraints:^(MASConstraintMaker *make) {
    make.left.equalTo(self).offset(margin);
    make.centerY.equalTo(self);
    make.width.height.mas_equalTo(albumSize);
  }];

  // ========== 底部进度条 ==========
  // 进度条固定在底部，宽度充足
  [self.progressView mas_makeConstraints:^(MASConstraintMaker *make) {
    make.left.equalTo(self).offset(rightContentX);
    make.right.equalTo(self).offset(-margin);
    make.bottom.equalTo(self).offset(-16);
    make.height.mas_equalTo(5); // 加粗进度条
  }];

  // ========== 播放控制按钮行 ==========
  // 核心播放控制居中：上一首 - 播放/暂停 - 下一首
  CGFloat btnSpacing = 24;  // 播放按钮之间的间距
  
  // 播放/暂停按钮 - 居中，最大
  [self.playPauseButton mas_makeConstraints:^(MASConstraintMaker *make) {
    make.centerX.equalTo(self).offset(albumSize/2 + albumToContentGap/2); // 向右偏移（考虑左侧封面）
    make.bottom.equalTo(self.progressView.mas_top).offset(-14);
    make.width.height.mas_equalTo(52); // 圆形按钮 52pt
  }];

  // 上一首按钮 - 播放按钮左侧
  [self.prevButton mas_makeConstraints:^(MASConstraintMaker *make) {
    make.centerY.equalTo(self.playPauseButton);
    make.right.equalTo(self.playPauseButton.mas_left).offset(-btnSpacing);
    make.width.height.mas_equalTo(44);
  }];

  // 下一首按钮 - 播放按钮右侧
  [self.nextButton mas_makeConstraints:^(MASConstraintMaker *make) {
    make.centerY.equalTo(self.playPauseButton);
    make.left.equalTo(self.playPauseButton.mas_right).offset(btnSpacing);
    make.width.height.mas_equalTo(44);
  }];

  // 随机播放按钮 - 最左侧，与上一首保持距离
  [self.shuffleButton mas_makeConstraints:^(MASConstraintMaker *make) {
    make.centerY.equalTo(self.playPauseButton);
    make.right.equalTo(self.prevButton.mas_left).offset(-18);
    make.width.height.mas_equalTo(36);
  }];

  // 评论按钮 - 最右侧
  [self.commentButton mas_makeConstraints:^(MASConstraintMaker *make) {
    make.centerY.equalTo(self.playPauseButton);
    make.left.equalTo(self.nextButton.mas_right).offset(18);
    make.width.height.mas_equalTo(36);
  }];

  // ========== 顶部歌曲信息 ==========
  // 艺术家在控制按钮上方
  [self.artistLabel mas_makeConstraints:^(MASConstraintMaker *make) {
    make.left.equalTo(self).offset(rightContentX);
    make.right.equalTo(self).offset(-margin);
    make.bottom.equalTo(self.playPauseButton.mas_top).offset(-12);
  }];

  // 歌名在最上方
  [self.songNameLabel mas_makeConstraints:^(MASConstraintMaker *make) {
    make.left.equalTo(self).offset(rightContentX);
    make.right.equalTo(self).offset(-margin);
    make.bottom.equalTo(self.artistLabel.mas_top).offset(-4);
    make.top.greaterThanOrEqualTo(self).offset(10);
  }];
}

#pragma mark - 按钮按压效果

- (void)addButtonPressEffect:(UIButton *)button {
  [button addTarget:self action:@selector(buttonTouchDown:) forControlEvents:UIControlEventTouchDown];
  [button addTarget:self action:@selector(buttonTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
}

- (void)buttonTouchDown:(UIButton *)button {
  [UIView animateWithDuration:0.1 animations:^{
    button.transform = CGAffineTransformMakeScale(0.88, 0.88);
  }];
}

- (void)buttonTouchUp:(UIButton *)button {
  [UIView animateWithDuration:0.1 animations:^{
    button.transform = CGAffineTransformIdentity;
  }];
}

- (void)applyThemeColor:(UIColor *)baseColor {
  if (!baseColor) return;
  CGFloat r, g, b, a;
  if (![baseColor getRed:&r green:&g blue:&b alpha:&a]) return;
  // 与详细页面顶部背景色保持一致（darkenByPercentage:0.2 ≈ multiply 0.80）
  self.backgroundColor = [UIColor colorWithRed:r * 0.80
                                         green:g * 0.80
                                          blue:b * 0.80
                                         alpha:1.0];
}

@end
