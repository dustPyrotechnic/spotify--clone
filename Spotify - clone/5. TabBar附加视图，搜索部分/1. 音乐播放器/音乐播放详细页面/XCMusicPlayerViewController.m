//
//  XCMusicPlayerViewController.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/12/1.
//

#import "XCMusicPlayerViewController.h"
#import "XCMusicPlayerView.h"
#import "XCMusicPlayerModel.h"

#import <Masonry/Masonry.h>
#import <CoreGraphics/CoreGraphics.h>

@interface XCMusicPlayerViewController ()

@end

@implementation XCMusicPlayerViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  // Do any additional setup after loading the view.
  self.musicPlayerModel = [XCMusicPlayerModel sharedInstance];
  
  // 初始化主视图
  self.mainView = [[XCMusicPlayerView alloc] init];
  // 设置响应
  [self.mainView.playOrStopButton addTarget:self action:@selector(handleTouchDownButton) forControlEvents:UIControlEventTouchDown];
  [self.mainView.playOrStopButton addTarget:self action:@selector(pressPlayOrStopButton) forControlEvents:UIControlEventTouchUpInside];
  [self.view addSubview:self.mainView];

  // 使用Masonry设置主视图约束
  [self.mainView mas_makeConstraints:^(MASConstraintMaker *make) {
      make.edges.equalTo(self.view);
  }];
}
# pragma mark -按钮响应方法
-(void)handleTouchDownButton {
  // 震动马达
  NSLog(@"按下播放暂停按钮");
  UIImpactFeedbackGenerator* feedbackGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
  [feedbackGenerator prepare];
  [feedbackGenerator impactOccurred];

}
- (void)pressPlayOrStopButton {
  self.isPlaying = !self.isPlaying; // 取反，表示当前应该是什么状态
  UIImageSymbolConfiguration* configuration = [UIImageSymbolConfiguration configurationWithFont:[UIFont boldSystemFontOfSize:40]];
  if (self.isPlaying) { // 正在播放
    [self.mainView letAlbumImageBig];
    [self.mainView.playOrStopButton setImage:[UIImage systemImageNamed:@"pause.fill" withConfiguration:configuration] forState:UIControlStateNormal];
    //TODO: 播放器设置内容
  } else {
    [self.mainView letAlbumImageSmall];
    [self.mainView.playOrStopButton setImage:[UIImage systemImageNamed:@"play.fill" withConfiguration:configuration] forState:UIControlStateNormal];
    //TODO: 设置暂停
  }
}
/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
