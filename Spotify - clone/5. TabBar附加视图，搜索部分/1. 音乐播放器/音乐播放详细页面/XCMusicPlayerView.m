//
//  XCMusicPlayerView.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/12/1.
//

#import "XCMusicPlayerView.h"

#import <Masonry/Masonry.h>
#import <ChameleonFramework/Chameleon.h>

@implementation XCMusicPlayerView
#pragma mark - 初始化视图内容
- (instancetype) init {
  self = [super init];
  if (self) {
    // 测试
    self.image = [UIImage imageNamed:@"testImage.jpg"];


    // 设置背景色
//    self.backgroundColor = aveColor;

    // 初始化专辑图片
    self.albumImage = [[UIImageView alloc] init];
    self.albumImage.image = self.image;
    self.albumImage.contentMode = UIViewContentModeScaleAspectFill;
    self.albumImage.clipsToBounds = YES;
    self.albumImage.layer.cornerRadius = 20;
    self.albumImage.layer.masksToBounds = YES;
    self.albumImage.backgroundColor = [UIColor systemGray5Color];

    self.containerImageView = [[UIView alloc] init];
    self.containerImageView.layer.cornerRadius = 20;
    self.containerImageView.backgroundColor = [UIColor whiteColor];
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

    // 初始化进度条
    self.mainSlider = [[UISlider alloc] init];
    self.mainSlider.sliderStyle = UISliderStyleThumbless;

    self.mainSlider.alpha = 0.5;

    self.mainSlider.minimumValue = 0.0;
    self.mainSlider.maximumValue = 1.0;
    self.mainSlider.value = 0.0;
    self.mainSlider.tintColor = [UIColor systemGray4Color];
    self.mainSlider.minimumTrackTintColor = [UIColor systemGray6Color];
    self.mainSlider.maximumTrackTintColor = [UIColor systemGray2Color];

    UIImageSymbolConfiguration* configuration = [UIImageSymbolConfiguration configurationWithFont:[UIFont boldSystemFontOfSize:40]];
    // 初始化上一首按钮
    self.preSongButton = [[UIButton alloc] init];
    [self.preSongButton setImage:[UIImage systemImageNamed:@"backward.fill" withConfiguration:configuration] forState:UIControlStateNormal];
    self.preSongButton.tintColor = [UIColor whiteColor];
    self.preSongButton.contentMode = UIViewContentModeScaleAspectFit;
    
    // 初始化播放/暂停按钮
    self.playOrStopButton = [[UIButton alloc] init];
    [self.playOrStopButton setImage:[UIImage systemImageNamed:@"play.fill" withConfiguration:configuration] forState:UIControlStateNormal];
    self.playOrStopButton.tintColor = [UIColor whiteColor];
    self.playOrStopButton.contentMode = UIViewContentModeScaleAspectFit;
    
    // 初始化下一首按钮
    self.nexSongButton = [[UIButton alloc] init];
    [self.nexSongButton setImage:[UIImage systemImageNamed:@"forward.fill" withConfiguration:configuration] forState:UIControlStateNormal];
    self.nexSongButton.tintColor = [UIColor whiteColor];
    self.nexSongButton.contentMode = UIViewContentModeScaleAspectFit;
    
    // 添加子视图
    [self addSubview:self.albumImage];
    [self addSubview:self.controlContainerView];


    [self.controlContainerView addSubview:self.songNameContainerScrollView];
    [self.controlContainerView addSubview:self.authorNameContainerScrollView];
    [self.controlContainerView addSubview:self.mainSlider];
    [self.controlContainerView addSubview:self.preSongButton];
    [self.controlContainerView addSubview:self.nexSongButton];
    [self.controlContainerView addSubview:self.playOrStopButton];
    
    // 使用Masonry进行自动布局
    [self setupConstraints];
    
    self.scaleTransform = CGAffineTransformMakeScale(1.4, 1.4);

//    [self letAlbumImageBig];
  }
  return self;
}
- (void) layoutSubviews {

  UIColor* aveColor = [UIColor colorWithAverageColorFromImage:self.image];
  UIColor *gradientColor = [UIColor colorWithGradientStyle:UIGradientStyleTopToBottom
                                                     withFrame:self.bounds
                                                     andColors:@[[aveColor darkenByPercentage:0.2],[aveColor darkenByPercentage:0.05], [aveColor darkenByPercentage:0.3]]];
  self.backgroundColor = gradientColor;
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
  // 滑动条布局
  [self.mainSlider mas_makeConstraints:^(MASConstraintMaker *make) {
    make.top.equalTo(self.songNameContainerScrollView.mas_bottom).offset(30);
//    make.left.equalTo(self.controlContainerView).offset(30);
//    make.right.equalTo(self.controlContainerView).offset(-30);
    make.width.mas_equalTo(self.controlContainerView.mas_width).multipliedBy(0.85);
    make.centerX.equalTo(self.controlContainerView);
    make.height.mas_equalTo(30);
  }];


  [self.preSongButton mas_makeConstraints:^(MASConstraintMaker *make) {
    make.top.equalTo(self.mainSlider.mas_bottom).offset(30);
    make.right.equalTo(self.playOrStopButton.mas_left).offset(-50);
    make.width.mas_equalTo(50);
    make.height.mas_equalTo(50);
  }];
  [self.playOrStopButton mas_makeConstraints:^(MASConstraintMaker *make) {
    make.top.equalTo(self.mainSlider.mas_bottom).offset(30);
//    make.left.equalTo(self.preSongButton).offset(30);
    make.centerX.equalTo(self.controlContainerView);
    make.width.mas_equalTo(50);
    make.height.mas_equalTo(50);
  }];
  [self.nexSongButton mas_makeConstraints:^(MASConstraintMaker *make) {
    make.top.equalTo(self.mainSlider.mas_bottom).offset(30);
    make.left.equalTo(self.playOrStopButton.mas_right).offset(50);
    make.width.mas_equalTo(50);
    make.height.mas_equalTo(50);
  }];
}
#pragma mark - 动画效果

- (void) letAlbumImageBig {
  [UIView animateWithDuration:0.5 animations:^{
    self.albumImage.transform = self.scaleTransform;
    self.containerImageView.transform = self.scaleTransform;
    self.containerImageView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.containerImageView.layer.shadowOffset = CGSizeMake(0, 10);
    self.containerImageView.layer.shadowOpacity = 0.5;
    self.containerImageView.layer.shadowRadius = 10;
    self.containerImageView.layer.masksToBounds = NO;
  }];



}
- (void) letAlbumImageSmall {
  // 恢复原始大小
  [UIView animateWithDuration:0.5 animations:^{
    self.albumImage.transform = CGAffineTransformIdentity;
    self.containerImageView.transform = CGAffineTransformIdentity;
    // 恢复阴影
//    self.containerImageView.layer.shadowColor = [UIColor clearColor].CGColor;
    self.containerImageView.layer.shadowOffset = CGSizeMake(0, 0);
    self.containerImageView.layer.shadowOpacity = 0;
    self.containerImageView.layer.shadowRadius = 0;
//    self.containerImageView.layer.masksToBounds = YES;
  }];

}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end
