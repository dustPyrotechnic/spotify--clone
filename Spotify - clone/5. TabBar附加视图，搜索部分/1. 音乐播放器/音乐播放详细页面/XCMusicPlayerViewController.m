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
    NSLog(@"[MusicPlayerVC] viewDidLoad 开始");
    [super viewDidLoad];
    
    NSLog(@"[MusicPlayerVC] 获取 Model 实例");
    self.musicPlayerModel = [XCMusicPlayerModel sharedInstance];
    
    NSLog(@"[MusicPlayerVC] 初始化主视图");
    // 初始化主视图
    self.mainView = [[XCMusicPlayerView alloc] init];
    NSLog(@"[MusicPlayerVC] 主视图初始化完成: %@", self.mainView);
    
    // 设置响应
    [self.mainView.playOrStopButton addTarget:self action:@selector(handleTouchDownButton) forControlEvents:UIControlEventTouchDown];
    [self.mainView.playOrStopButton addTarget:self action:@selector(pressPlayOrStopButton) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.mainView];

    // 使用Masonry设置主视图约束
    [self.mainView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    
    // 注册通知监听
    [self registerNotifications];
    
    // 如果已有正在播放的歌曲，立即显示
    NSLog(@"[MusicPlayerVC] 检查是否有正在播放的歌曲");
    if (self.musicPlayerModel.nowPlayingSong) {
        NSLog(@"[MusicPlayerVC] 有正在播放的歌曲，调用 configureWithSong");
        [self.mainView configureWithSong:self.musicPlayerModel.nowPlayingSong];
        // 同步播放按钮状态（使用 Model 维护的状态）
        [self updatePlayButtonState:self.musicPlayerModel.isPlaying];
    } else {
        NSLog(@"[MusicPlayerVC] 没有正在播放的歌曲");
    }
    NSLog(@"[MusicPlayerVC] viewDidLoad 结束");
}

- (void)dealloc {
    // 移除通知监听（防止内存泄漏）
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - 通知注册

- (void)registerNotifications {
    // 监听歌曲变更
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleNowPlayingSongDidChange:)
                                                 name:XCMusicPlayerNowPlayingSongDidChangeNotification
                                               object:nil];
    
    // 监听播放状态变更
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handlePlaybackStateDidChange:)
                                                 name:XCMusicPlayerPlaybackStateDidChangeNotification
                                               object:nil];
}

#pragma mark - 通知处理

- (void)handleNowPlayingSongDidChange:(NSNotification *)notification {
    NSLog(@"[MusicPlayerVC] handleNowPlayingSongDidChange 收到通知");
    XC_YYSongData *song = notification.userInfo[@"song"];
    if ([song isKindOfClass:[NSNull class]]) song = nil;
    
    NSLog(@"[MusicPlayerVC] 歌曲: %@", song.name);
    
    // 主线程更新 UI
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"[MusicPlayerVC] 主线程中调用 configureWithSong");
        [self.mainView configureWithSong:song];
    });
}

- (void)handlePlaybackStateDidChange:(NSNotification *)notification {
    NSLog(@"[MusicPlayerVC] handlePlaybackStateDidChange 收到通知");
    BOOL isPlaying = [notification.userInfo[@"isPlaying"] boolValue];
    
    NSLog(@"[MusicPlayerVC] 播放状态: %@", isPlaying ? @"播放" : @"暂停");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updatePlayButtonState:isPlaying];
    });
}

- (void)updatePlayButtonState:(BOOL)isPlaying {
    self.isPlaying = isPlaying;
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithFont:[UIFont boldSystemFontOfSize:40]];
    UIImage *image = isPlaying
        ? [UIImage systemImageNamed:@"pause.fill" withConfiguration:config]
        : [UIImage systemImageNamed:@"play.fill" withConfiguration:config];
    [self.mainView.playOrStopButton setImage:image forState:UIControlStateNormal];
    
    // 更新专辑图片动画
    if (isPlaying) {
        [self.mainView letAlbumImageBig];
    } else {
        [self.mainView letAlbumImageSmall];
    }
}

#pragma mark - 按钮响应方法

- (void)handleTouchDownButton {
    // 震动马达
    NSLog(@"按下播放暂停按钮");
    UIImpactFeedbackGenerator* feedbackGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [feedbackGenerator prepare];
    [feedbackGenerator impactOccurred];
}

- (void)pressPlayOrStopButton {
    // 直接调用 Model 的方法，由 Model 发送通知更新 UI
    if (self.musicPlayerModel.isPlaying) {
        [self.musicPlayerModel pauseMusic];
    } else {
        [self.musicPlayerModel playMusic];
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
