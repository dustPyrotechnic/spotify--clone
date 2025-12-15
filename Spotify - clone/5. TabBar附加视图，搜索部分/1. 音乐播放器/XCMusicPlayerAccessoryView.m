//
//  XCMusicPayerAccessoryView.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/11/24.
//

#import "XCMusicPlayerAccessoryView.h"

#import "XCMusicPlayerViewController.h"

#import <Masonry/Masonry.h>

@implementation XCMusicPlayerAccessoryView

- (instancetype) initWithFrame:(CGRect)frame withImage:(UIImage*)image andTitle:(NSString*)title withSonger:(NSString*)songer withCondition:(BOOL) isPlaying {
  self = [super initWithFrame:frame];
  self.backgroundColor = [UIColor systemBackgroundColor];
  // 设置图像
  self.imageView = [[UIImageView alloc] initWithImage:image];
  self.imageView.frame = CGRectMake(0, 0, 20, 20);
  self.imageView.layer.cornerRadius = 5;
  self.imageView.layer.masksToBounds = YES;
  // 设置歌曲名称和歌唱家

  self.titleLabel = [[UILabel alloc] init];
  _titleLabel.text = title;
  self.titleLabel.numberOfLines = 1;
  _titleLabel.frame = CGRectMake(0, 0, 100, 30);
  // 更改颜色
  _titleLabel.textColor = [UIColor labelColor];


  self.authorLabel = [[UILabel alloc] init];
  _authorLabel.text = songer;
  self.authorLabel.numberOfLines = 1;
  _authorLabel.frame = CGRectMake(0, 0, 50, 20);
  _authorLabel.textColor = [UIColor systemGrayColor];
  _authorLabel.font = [UIFont systemFontOfSize:15];


  // 配置按钮
  self.stopOrContinueButton = [[UIButton alloc] init];
  self.stopOrContinueButton.frame = CGRectMake(0, 0, 40, 40);

  [self.stopOrContinueButton setImage:[UIImage systemImageNamed:@"play.fill"] forState:UIControlStateNormal];

  [self.stopOrContinueButton addTarget:self action:@selector(pressStopOrContinueButton:) forControlEvents:UIControlEventTouchUpInside];
  self.stopOrContinueButton.tintColor = [UIColor labelColor];

  self.nextSong = [[UIButton alloc] init];
  self.nextSong.frame = CGRectMake(0, 0, 40, 40);
  [self.nextSong setImage:[UIImage systemImageNamed:@"forward.fill"] forState:UIControlStateNormal];
  [self.nextSong addTarget:self action:@selector(pressNextButton:) forControlEvents:UIControlEventTouchUpInside];
  self.nextSong.tintColor = [UIColor labelColor];

  self.isPlaying = isPlaying;
  
  // 加入视图
  [self addSubview:self.imageView];

  [self addSubview:self.titleLabel];
  [self addSubview:self.authorLabel];

  [self addSubview:self.stopOrContinueButton];
  [self addSubview:self.nextSong];

  // 开始布局内容
  [self.imageView mas_makeConstraints:^(MASConstraintMaker *make) {
    make.top.equalTo(self).offset(7);
    make.left.equalTo(self).offset(20);
    make.centerY.equalTo(self);
    make.width.mas_equalTo(self.imageView.mas_height);
//    make.height.mas_equalTo(38);
  }];

  [self.titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
    make.left.equalTo(self.imageView.mas_right).offset(10);
    make.centerY.equalTo(self).offset(-10);
  }];
  [self.authorLabel mas_makeConstraints:^(MASConstraintMaker *make) {
    make.left.equalTo(self.imageView.mas_right).offset(10);
    make.centerY.equalTo(self).offset(10);
  }];

  [self.stopOrContinueButton mas_makeConstraints:^(MASConstraintMaker *make) {
    make.right.equalTo(self).offset(-70);
    make.centerY.equalTo(self);
  }];
  [self.nextSong mas_makeConstraints:^(MASConstraintMaker *make) {
    make.right.equalTo(self).offset(-30);
    make.centerY.equalTo(self);
  }];


  UITapGestureRecognizer* tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
  tapGesture.numberOfTapsRequired = 1; // 需要点击一次
  tapGesture.numberOfTouchesRequired = 1; // 需要一根手指
  [self addGestureRecognizer:tapGesture];

  return self;
}
- (void) pressStopOrContinueButton:(UIButton*)sender {
  NSLog(@"按下播放按钮");
  self.isPlaying = !self.isPlaying;

  if (self.isPlaying) {
//    [sender setImage:[UIImage systemImageNamed:@"pause.fill"] forState:UIControlStateNormal];
    [sender.imageView setSymbolImage:[UIImage systemImageNamed:@"pause.fill"] withContentTransition:[NSSymbolReplaceContentTransition replaceDownUpTransition]];
    [sender setImage:[UIImage systemImageNamed:@"pause.fill"] forState:UIControlStateNormal];
  } else {
//    [sender setImage:[UIImage systemImageNamed:@"play.fill"] forState:UIControlStateNormal];
    [sender.imageView setSymbolImage:[UIImage systemImageNamed:@"play.fill"] withContentTransition:[NSSymbolReplaceContentTransition replaceDownUpTransition]];
    [sender setImage:[UIImage systemImageNamed:@"play.fill"] forState:UIControlStateNormal];
  }

}

- (void) pressNextButton:(UIButton*)sender {
  NSLog(@"播放下一首歌");
  self.isPlaying = NO;
  [self pressStopOrContinueButton:self.stopOrContinueButton];
}

- (void) handleTap:(UITapGestureRecognizer*) gestureRecognizer {
  // TODO: 弹出音乐播放器视图
  NSLog(@"弹出音乐播放器视图");
  XCMusicPlayerViewController* playerVC = [[XCMusicPlayerViewController alloc] init];
  playerVC.modalPresentationStyle = UIModalPresentationPageSheet;
  UISheetPresentationController *sheet = playerVC.sheetPresentationController;
  // 设置停靠点，大约全屏的高度
  sheet.detents = @[[UISheetPresentationControllerDetent largeDetent]];
  // 显示顶部的小把手 (Grabber)
  sheet.prefersGrabberVisible = YES;
  sheet.preferredCornerRadius = 20.0;
  playerVC.popoverPresentationController.sourceItem = self;
  if (self.presentPlayerViewControllerBlock) {
    self.presentPlayerViewControllerBlock(playerVC);
  }
}

- (void) handleSwipe {
  // TODO: 解决滑动事件
}
/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end
