//
//  XCMusicPlayerView.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/12/1.
//

#import "XCMusicPlayerView.h"

#import <Masonry/Masonry.h>
#import <ChameleonFramework/Chameleon.h>
#import <SDWebImage/SDWebImage.h>

@implementation XCMusicPlayerView
#pragma mark - 初始化视图内容
- (instancetype) init {
  NSLog(@"[MusicPlayerView] init 开始");
  self = [super init];
  if (self) {
    NSLog(@"[MusicPlayerView] 初始化子视图");

    // 初始化专辑图片
    self.albumImage = [[UIImageView alloc] init];
    // 【优化】不设置默认图片，避免切换歌曲时闪烁
    // 初始状态显示背景色，等有歌曲数据时再加载真实封面
    self.albumImage.contentMode = UIViewContentModeScaleAspectFill;
    self.albumImage.clipsToBounds = YES;
    self.albumImage.layer.cornerRadius = 12;
    self.albumImage.layer.masksToBounds = YES;
    self.albumImage.backgroundColor = [UIColor systemGray5Color];

    self.containerImageView = [[UIView alloc] init];
    self.containerImageView.layer.cornerRadius = 12;
    self.containerImageView.backgroundColor = [UIColor clearColor];
    // 添加柔和的阴影效果
    self.containerImageView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.containerImageView.layer.shadowOffset = CGSizeMake(0, 8);
    self.containerImageView.layer.shadowRadius = 20;
    self.containerImageView.layer.shadowOpacity = 0.3;
    [self addSubview:self.containerImageView];

    // 初始化放置控制元件的容器视图
    self.controlContainerView = [[UIView alloc] init];
    self.controlContainerView.backgroundColor = [UIColor clearColor];
    
    // 初始化歌曲名称标签
    self.songNameLabel = [[UILabel alloc] init];
    self.songNameLabel.text = @"歌曲名称";
    self.songNameLabel.font = [UIFont boldSystemFontOfSize:24];
    self.songNameLabel.textColor = [UIColor whiteColor];
    self.songNameLabel.textAlignment = NSTextAlignmentLeft;
    self.songNameLabel.numberOfLines = 1;
    // 根据文本长度自定义label长度
    self.songNameLabel.preferredMaxLayoutWidth = [self.songNameLabel.text sizeWithAttributes:@{NSFontAttributeName: self.songNameLabel.font}].width;

    // 初始化作者名称标签
    self.authorNameLabel = [[UILabel alloc] init];
    self.authorNameLabel.text = @"艺术家";
    self.authorNameLabel.font = [UIFont systemFontOfSize:18];
    self.authorNameLabel.textColor = [UIColor systemGray4Color];
    self.authorNameLabel.textAlignment = NSTextAlignmentLeft;
    self.authorNameLabel.numberOfLines = 1;
    // 根据文本长度自定义label长度
    self.authorNameLabel.preferredMaxLayoutWidth = [self.authorNameLabel.text sizeWithAttributes:@{NSFontAttributeName: self.authorNameLabel.font}].width;

    // 初始化两个标签的容器视图控制
    self.songNameContainerScrollView = [[UIScrollView alloc] init];
    self.songNameContainerScrollView.backgroundColor = [UIColor clearColor]; // 透明背景
    self.songNameContainerScrollView.showsHorizontalScrollIndicator = NO;
    self.songNameContainerScrollView.showsVerticalScrollIndicator = NO;
    self.songNameContainerScrollView.contentInset = UIEdgeInsetsMake(0, 10, 0, 10); // 内边距
    self.songNameContainerScrollView.contentOffset = CGPointMake(0, 0); // 内容偏移
    self.songNameContainerScrollView.contentSize = CGSizeMake(0, 0); // 内容大小
//    self.songNameContainerScrollView.delegate = self; // 代理
    self.songNameContainerScrollView.directionalLockEnabled = YES; // 方向锁定
    self.songNameContainerScrollView.pagingEnabled = YES; // 分页
    self.songNameContainerScrollView.scrollEnabled = YES; // 滚动
    self.songNameContainerScrollView.bounces = NO; // 不反弹

    self.authorNameContainerScrollView = [[UIScrollView alloc] init];
    self.authorNameContainerScrollView.backgroundColor = [UIColor clearColor]; // 透明背景
    self.authorNameContainerScrollView.showsHorizontalScrollIndicator = NO;
    self.authorNameContainerScrollView.showsVerticalScrollIndicator = NO;
    self.authorNameContainerScrollView.contentInset = UIEdgeInsetsMake(0, 10, 0, 10); // 内边距
    self.authorNameContainerScrollView.contentOffset = CGPointMake(0, 0); // 内容偏移
    self.authorNameContainerScrollView.contentSize = CGSizeMake(0, 0); // 内容大小
//    self.authorNameContainerScrollView.delegate = self; // 代理
    self.authorNameContainerScrollView.directionalLockEnabled = YES; // 方向锁定
    self.authorNameContainerScrollView.pagingEnabled = YES; // 分页
    self.authorNameContainerScrollView.scrollEnabled = YES; // 滚动
    self.authorNameContainerScrollView.bounces = NO; // 不反弹

    // 加入容器视图
    [self.songNameContainerScrollView addSubview:self.songNameLabel];
    [self.authorNameContainerScrollView addSubview:self.authorNameLabel];

    // 初始化进度条 - 优化样式
    self.mainSlider = [[UISlider alloc] init];
    self.mainSlider.sliderStyle = UISliderStyleThumbless;
    self.mainSlider.alpha = 1.0;
    self.mainSlider.minimumValue = 0.0;
    self.mainSlider.maximumValue = 1.0;
    self.mainSlider.value = 0.0;
    // 优化进度条颜色 - 使用白色系增加对比度
    self.mainSlider.minimumTrackTintColor = [UIColor whiteColor];
    self.mainSlider.maximumTrackTintColor = [UIColor colorWithWhite:1.0 alpha:0.3];
    
    // 初始化时间标签
    self.currentTimeLabel = [[UILabel alloc] init];
    self.currentTimeLabel.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightMedium];
    self.currentTimeLabel.textColor = [UIColor colorWithWhite:0.85 alpha:0.9];
    self.currentTimeLabel.text = @"0:00";
    self.currentTimeLabel.textAlignment = NSTextAlignmentLeft;
    
    self.totalTimeLabel = [[UILabel alloc] init];
    self.totalTimeLabel.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightMedium];
    self.totalTimeLabel.textColor = [UIColor colorWithWhite:0.85 alpha:0.9];
    self.totalTimeLabel.text = @"0:00";
    self.totalTimeLabel.textAlignment = NSTextAlignmentRight;

    UIImageSymbolConfiguration* configuration = [UIImageSymbolConfiguration configurationWithFont:[UIFont boldSystemFontOfSize:40]];
    // 初始化上一首按钮 - 添加按压效果
    self.preSongButton = [[UIButton alloc] init];
    UIImageSymbolConfiguration* smallConfig = [UIImageSymbolConfiguration configurationWithFont:[UIFont systemFontOfSize:22 weight:UIFontWeightMedium]];
    [self.preSongButton setImage:[UIImage systemImageNamed:@"backward.fill" withConfiguration:smallConfig] forState:UIControlStateNormal];
    self.preSongButton.tintColor = [UIColor whiteColor];
    self.preSongButton.contentMode = UIViewContentModeScaleAspectFit;
    [self addButtonPressEffect:self.preSongButton];
    
    // 初始化播放/暂停按钮 - 圆形背景，更突出
    self.playButtonBackground = [[UIView alloc] init];
    self.playButtonBackground.backgroundColor = [UIColor whiteColor];
    self.playButtonBackground.layer.cornerRadius = 35;
    self.playButtonBackground.layer.shadowColor = [UIColor blackColor].CGColor;
    self.playButtonBackground.layer.shadowOffset = CGSizeMake(0, 4);
    self.playButtonBackground.layer.shadowRadius = 8;
    self.playButtonBackground.layer.shadowOpacity = 0.2;
    
    self.playOrStopButton = [[UIButton alloc] init];
    UIImageSymbolConfiguration* playConfig = [UIImageSymbolConfiguration configurationWithFont:[UIFont systemFontOfSize:28 weight:UIFontWeightBold]];
    [self.playOrStopButton setImage:[UIImage systemImageNamed:@"play.fill" withConfiguration:playConfig] forState:UIControlStateNormal];
    self.playOrStopButton.tintColor = [UIColor blackColor]; // 黑色图标在白色背景上
    self.playOrStopButton.contentMode = UIViewContentModeScaleAspectFit;
    [self addButtonPressEffect:self.playOrStopButton];
    
    // 初始化下一首按钮 - 添加按压效果
    self.nexSongButton = [[UIButton alloc] init];
    [self.nexSongButton setImage:[UIImage systemImageNamed:@"forward.fill" withConfiguration:smallConfig] forState:UIControlStateNormal];
    self.nexSongButton.tintColor = [UIColor whiteColor];
    self.nexSongButton.contentMode = UIViewContentModeScaleAspectFit;
    [self addButtonPressEffect:self.nexSongButton];

    // 初始化随机/顺序模式切换按钮 - 添加按压效果
    UIImageSymbolConfiguration *shuffleConfig = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightMedium];
    self.shuffleModeButton = [[UIButton alloc] init];
    [self.shuffleModeButton setImage:[UIImage systemImageNamed:@"shuffle" withConfiguration:shuffleConfig] forState:UIControlStateNormal];
    self.shuffleModeButton.tintColor = [UIColor colorWithWhite:1.0 alpha:0.6];
    self.shuffleModeButton.contentMode = UIViewContentModeScaleAspectFit;
    [self addButtonPressEffect:self.shuffleModeButton];

    // 添加子视图
    [self addSubview:self.albumImage];
    [self addSubview:self.controlContainerView];


    [self.controlContainerView addSubview:self.songNameContainerScrollView];
    [self.controlContainerView addSubview:self.authorNameContainerScrollView];
    [self.controlContainerView addSubview:self.mainSlider];
    [self.controlContainerView addSubview:self.currentTimeLabel];
    [self.controlContainerView addSubview:self.totalTimeLabel];
    [self.controlContainerView addSubview:self.playButtonBackground];
    [self.controlContainerView addSubview:self.preSongButton];
    [self.controlContainerView addSubview:self.nexSongButton];
    [self.controlContainerView addSubview:self.playOrStopButton];
    [self.controlContainerView addSubview:self.shuffleModeButton];
    
    // 添加播放按钮背景的子视图关系
    [self.controlContainerView insertSubview:self.playButtonBackground belowSubview:self.playOrStopButton];
    
    // 使用Masonry进行自动布局
    [self setupConstraints];
    
    self.scaleTransform = CGAffineTransformMakeScale(1.3, 1.3);

//    [self letAlbumImageBig];
    NSLog(@"[MusicPlayerView] init 完成");
  }
  return self;
}
- (void) layoutSubviews {
    NSLog(@"[MusicPlayerView] layoutSubviews 被调用");
    
    [super layoutSubviews];
    
    NSLog(@"[MusicPlayerView] self.bounds = %@", NSStringFromCGRect(self.bounds));
    
    // 检查 bounds 是否有效（宽高必须大于0）
    if (CGRectIsEmpty(self.bounds) || self.bounds.size.width == 0 || self.bounds.size.height == 0) {
        NSLog(@"[MusicPlayerView] ⚠️ bounds 无效，跳过背景更新");
        return;
    }
    
    // 【优化】只使用 albumImage.image 来计算背景色
    UIImage *imageToUse = self.albumImage.image;
    NSLog(@"[MusicPlayerView] 使用的图片: %@", imageToUse);
    
    if (!imageToUse) {
        NSLog(@"[MusicPlayerView] ⚠️ 没有可用图片，跳过背景设置");
        // 使用默认背景色
        self.backgroundColor = [UIColor systemBackgroundColor];
        return;
    }
    
    NSLog(@"[MusicPlayerView] 开始计算图片平均颜色");
    UIColor* aveColor = [UIColor colorWithAverageColorFromImage:imageToUse];
    NSLog(@"[MusicPlayerView] 平均颜色: %@", aveColor);
    
    if (!aveColor) {
        NSLog(@"[MusicPlayerView] ⚠️ 无法获取平均颜色");
        return;
    }
    
    NSLog(@"[MusicPlayerView] 开始创建渐变色");
    UIColor *gradientColor = [UIColor colorWithGradientStyle:UIGradientStyleTopToBottom
                                                     withFrame:self.bounds
                                                     andColors:@[[aveColor darkenByPercentage:0.2],[aveColor darkenByPercentage:0.05], [aveColor darkenByPercentage:0.3]]];
    NSLog(@"[MusicPlayerView] 渐变色: %@", gradientColor);
    
    self.backgroundColor = gradientColor;
    NSLog(@"[MusicPlayerView] layoutSubviews 完成");
}
- (void)setupConstraints {
  [self.containerImageView mas_makeConstraints:^(MASConstraintMaker *make) {
    make.width.equalTo(self.albumImage);
    make.height.equalTo(self.albumImage);
    make.center.equalTo(self.albumImage);
  }];
  // 专辑图片布局 - 顶部居中，占据较大空间
  [self.albumImage mas_makeConstraints:^(MASConstraintMaker *make) {
    make.top.equalTo(self.mas_safeAreaLayoutGuideTop).offset(100);
    make.centerX.equalTo(self);
    make.width.equalTo(self).multipliedBy(0.618);
    make.height.equalTo(self.albumImage.mas_width);
  }];

  [self.controlContainerView mas_makeConstraints:^(MASConstraintMaker *make) {
    make.bottom.equalTo(self);
    make.height.equalTo(self).multipliedBy(1 - 0.618);
    make.width.equalTo(self);
    make.centerX.equalTo(self);
  }];

  // 在容器内，布局标题
  [self.songNameLabel mas_makeConstraints:^(MASConstraintMaker *make) {
    make.top.equalTo(self.songNameContainerScrollView);
    make.left.equalTo(self.songNameContainerScrollView);
    make.right.equalTo(self.songNameContainerScrollView);
    make.height.equalTo(self.songNameContainerScrollView.mas_height);
  }];
  [self.authorNameLabel mas_makeConstraints:^(MASConstraintMaker *make) {
    make.top.equalTo(self.authorNameContainerScrollView);
    make.left.equalTo(self.authorNameContainerScrollView);
    make.right.equalTo(self.authorNameContainerScrollView);
    make.height.equalTo(self.authorNameContainerScrollView.mas_height);
  }];
  
  [self.songNameContainerScrollView mas_makeConstraints:^(MASConstraintMaker *make) {
    make.top.equalTo(self.controlContainerView);
    make.left.equalTo(self.controlContainerView).offset(30);
    // make.right.equalTo(self.controlContainerView);
    make.height.equalTo(self.songNameLabel.mas_height);
    make.width.mas_equalTo(300);
  }];
  [self.authorNameContainerScrollView mas_makeConstraints:^(MASConstraintMaker *make) {
    make.top.equalTo(self.songNameContainerScrollView.mas_bottom);
    make.left.equalTo(self.controlContainerView).offset(30);
    // make.right.equalTo(self.controlContainerView);
    make.width.mas_equalTo(200);
    make.height.equalTo(self.authorNameLabel.mas_height);
  }];
  // 滑动条布局 - 优化位置
  [self.mainSlider mas_makeConstraints:^(MASConstraintMaker *make) {
    make.top.equalTo(self.authorNameContainerScrollView.mas_bottom).offset(40);
    make.width.mas_equalTo(self.controlContainerView.mas_width).multipliedBy(0.85);
    make.centerX.equalTo(self.controlContainerView);
    make.height.mas_equalTo(24);
  }];
  
  // 时间标签布局
  [self.currentTimeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
    make.top.equalTo(self.mainSlider.mas_bottom).offset(4);
    make.left.equalTo(self.mainSlider);
    make.height.mas_equalTo(16);
    make.width.mas_equalTo(50);
  }];
  
  [self.totalTimeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
    make.top.equalTo(self.mainSlider.mas_bottom).offset(4);
    make.right.equalTo(self.mainSlider);
    make.height.mas_equalTo(16);
    make.width.mas_equalTo(50);
  }];

  // 播放按钮背景（圆形）
  [self.playButtonBackground mas_makeConstraints:^(MASConstraintMaker *make) {
    make.centerX.equalTo(self.controlContainerView);
    make.centerY.equalTo(self.playOrStopButton);
    make.width.height.mas_equalTo(70);
  }];

  // 控制按钮布局 - 优化间距和层级
  [self.shuffleModeButton mas_makeConstraints:^(MASConstraintMaker *make) {
    make.right.equalTo(self.preSongButton.mas_left).offset(-40);
    make.centerY.equalTo(self.playOrStopButton);
    make.width.height.mas_equalTo(44);
  }];
  
  [self.preSongButton mas_makeConstraints:^(MASConstraintMaker *make) {
    make.centerY.equalTo(self.playOrStopButton);
    make.right.equalTo(self.playOrStopButton.mas_left).offset(-50);
    make.width.height.mas_equalTo(44);
  }];
  
  [self.playOrStopButton mas_makeConstraints:^(MASConstraintMaker *make) {
    make.top.equalTo(self.currentTimeLabel.mas_bottom).offset(35);
    make.centerX.equalTo(self.controlContainerView);
    make.width.height.mas_equalTo(70);
  }];
  
  [self.nexSongButton mas_makeConstraints:^(MASConstraintMaker *make) {
    make.centerY.equalTo(self.playOrStopButton);
    make.left.equalTo(self.playOrStopButton.mas_right).offset(50);
    make.width.height.mas_equalTo(44);
  }];
}

#pragma mark - 按钮按压效果

- (void)addButtonPressEffect:(UIButton *)button {
    // 添加按钮按压时的缩放效果
    [button addTarget:self action:@selector(buttonTouchDown:) forControlEvents:UIControlEventTouchDown];
    [button addTarget:self action:@selector(buttonTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
}

- (void)buttonTouchDown:(UIButton *)button {
    [UIView animateWithDuration:0.1 animations:^{
        button.transform = CGAffineTransformMakeScale(0.9, 0.9);
    }];
}

- (void)buttonTouchUp:(UIButton *)button {
    [UIView animateWithDuration:0.1 animations:^{
        button.transform = CGAffineTransformIdentity;
    }];
}
#pragma mark - 动画效果

- (void) letAlbumImageBig {
  [UIView animateWithDuration:0.5 animations:^{
    self.albumImage.transform = self.scaleTransform;
    self.containerImageView.transform = self.scaleTransform;
    // 播放时增强阴影效果
    self.containerImageView.layer.shadowOffset = CGSizeMake(0, 15);
    self.containerImageView.layer.shadowOpacity = 0.4; 
    self.containerImageView.layer.shadowRadius = 25;
  }];
}

- (void) letAlbumImageSmall {
  // 恢复原始大小
  [UIView animateWithDuration:0.5 animations:^{
    self.albumImage.transform = CGAffineTransformIdentity;
    self.containerImageView.transform = CGAffineTransformIdentity;
    // 暂停时恢复柔和阴影
    self.containerImageView.layer.shadowOffset = CGSizeMake(0, 8);
    self.containerImageView.layer.shadowOpacity = 0.3;
    self.containerImageView.layer.shadowRadius = 20;
  }];
}

#pragma mark - 配置方法

- (void)configureWithSong:(XC_YYSongData *)song {
    NSLog(@"[MusicPlayerView] configureWithSong 被调用");
    
    if (!song) {
        NSLog(@"[MusicPlayerView] ⚠️ song 为空，直接返回");
        return;
    }
    
    NSLog(@"[MusicPlayerView] 歌曲信息: name=%@, artist=%@, mainIma=%@", song.name, song.artist, song.mainIma);
    
    // 更新歌曲名
    self.songNameLabel.text = song.name ?: @"未知歌曲";
    NSLog(@"[MusicPlayerView] 歌曲名已设置");
    
    // 更新艺术家名称
    self.authorNameLabel.text = song.artist ?: @"未知艺术家";
    NSLog(@"[MusicPlayerView] 艺术家已设置");
    
    // 更新总时长标签
    if (song.duration > 0) {
        self.totalTimeLabel.text = [self formatTimeInterval:song.duration / 1000.0];
    } else {
        self.totalTimeLabel.text = @"0:00";
    }
    
    // 使用 SDWebImage 加载专辑封面（优化：避免闪烁）
    if (song.mainIma) {
        NSLog(@"[MusicPlayerView] 开始加载专辑封面: %@", song.mainIma);
        NSURL *imageURL = [NSURL URLWithString:song.mainIma];
        NSLog(@"[MusicPlayerView] 图片 URL: %@", imageURL);
        
        // 【优化】先尝试从缓存获取图片，避免显示 placeholder 造成闪烁
        NSString *key = [[SDWebImageManager sharedManager] cacheKeyForURL:imageURL];
        UIImage *cachedImage = [[SDImageCache sharedImageCache] imageFromCacheForKey:key];
        
        __weak typeof(self) weakSelf = self;
        
        if (cachedImage) {
            // 缓存中有，直接使用，不需要 placeholder
            NSLog(@"[MusicPlayerView] 使用缓存的图片，无闪烁");
            self.albumImage.image = cachedImage;
            [self setNeedsLayout];
        } else {
            // 缓存中没有，使用当前显示的图片作为 placeholder（避免显示默认图）
            // 如果当前没有图片，则使用 nil（显示空白背景色）
            UIImage *currentImage = self.albumImage.image;
            BOOL hasValidCurrentImage = (currentImage != nil && 
                                        currentImage != [UIImage imageNamed:@"testImage.jpg"]);
            
            NSLog(@"[MusicPlayerView] 缓存未命中，使用当前图片作为 placeholder: %@", 
                  hasValidCurrentImage ? @"是" : @"否");
            
            [self.albumImage sd_setImageWithURL:imageURL
                               placeholderImage:hasValidCurrentImage ? currentImage : nil
                                        options:SDWebImageRetryFailed | SDWebImageAvoidAutoSetImage
                                       progress:nil
                                      completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {
                NSLog(@"[MusicPlayerView] 图片加载完成回调触发");
                if (error) {
                    NSLog(@"[MusicPlayerView] ⚠️ 图片加载错误: %@", error.localizedDescription);
                } else if (image) {
                    NSLog(@"[MusicPlayerView] 图片加载成功，使用淡入动画");
                    // 使用淡入动画平滑过渡
                    [UIView transitionWithView:weakSelf.albumImage
                                      duration:0.3
                                       options:UIViewAnimationOptionTransitionCrossDissolve
                                    animations:^{
                        weakSelf.albumImage.image = image;
                    } completion:nil];
                }
                // 图片加载完成后标记需要重新布局，在 layoutSubviews 中更新背景
                [weakSelf setNeedsLayout];
            }];
        }
    }
    // 不在这里直接调用 updateBackgroundGradient，交给 layoutSubviews 处理
}

#pragma mark - 时间格式化

/// 格式化时间显示 (秒 -> mm:ss)
- (NSString *)formatTimeInterval:(NSTimeInterval)timeInterval {
    NSInteger minutes = (NSInteger)timeInterval / 60;
    NSInteger seconds = (NSInteger)timeInterval % 60;
    return [NSString stringWithFormat:@"%ld:%02ld", (long)minutes, (long)seconds];
}

#pragma mark - 公开方法

/// 更新当前时间显示
- (void)updateCurrentTime:(NSTimeInterval)currentTime {
    self.currentTimeLabel.text = [self formatTimeInterval:currentTime];
}

- (void)updateBackgroundGradient {
    NSLog(@"[MusicPlayerView] updateBackgroundGradient 被调用，触发重新布局");
    // 标记需要重新布局，在 layoutSubviews 中更新背景
    // 这样可以确保视图已经有有效尺寸
    [self setNeedsLayout];
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end
