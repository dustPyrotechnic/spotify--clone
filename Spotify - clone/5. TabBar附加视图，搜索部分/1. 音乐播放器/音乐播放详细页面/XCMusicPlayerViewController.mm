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
#import <AVFoundation/AVFoundation.h>
#import <SDWebImage/SDWebImage.h>

// Phase 3: 评论模块
#import "XCSongCommentPanel.h"
#import "XCSongCommentList.h"
#import "XCSongCommentService.h"

// Phase 5: 楼层评论
#import "XCSongCommentFloorViewController.h"

// 迷你播放控制器（评论面板展开时使用）
#import "XCMiniPlayerView.h"

@interface XCMusicPlayerViewController () <XCSongCommentPanelDelegate, XCMusicPlayerViewDelegate>
/// 拖动进度条前是否正在播放
@property (nonatomic, assign) BOOL wasPlayingBeforeSeek;
/// 是否正在拖动进度条
@property (nonatomic, assign) BOOL isSeeking;
/// 进度条更新定时器
@property (nonatomic, strong) NSTimer *progressTimer;
/// 资源加载检查定时器（用于快速打开页面时检查加载状态）
@property (nonatomic, strong) NSTimer *loadingCheckTimer;
/// 评论面板
@property (nonatomic, strong) XCSongCommentPanel *commentPanel;
/// 蒙层视图
@property (nonatomic, strong) UIView *commentMaskView;
/// 评论面板是否可见（内部存储）
@property (nonatomic, assign) BOOL commentPanelVisible;
/// 内容中心Y约束（用于动画）
@property (nonatomic, strong) MASConstraint *contentCenterYConstraint;
/// 评论面板展开时显示在上方的迷你播放控制器
@property (nonatomic, strong) XCMiniPlayerView *miniPlayerView;
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
    self.mainView.delegate = self;
    NSLog(@"[MusicPlayerVC] 主视图初始化完成: %@", self.mainView);
    
    // 设置播放按钮响应
    [self.mainView.playOrStopButton addTarget:self action:@selector(handleTouchDownButton) forControlEvents:UIControlEventTouchDown];
    [self.mainView.playOrStopButton addTarget:self action:@selector(pressPlayOrStopButton) forControlEvents:UIControlEventTouchUpInside];


    // 设置下一首歌播放按钮
    [self.mainView.nexSongButton addTarget:self action:@selector(pressNextSong) forControlEvents:UIControlEventTouchUpInside];
    // 设置上一首歌播放按钮
    [self.mainView.preSongButton addTarget:self action:@selector(pressPreviousSong) forControlEvents:UIControlEventTouchUpInside];

    // 设置随机/顺序模式按钮响应
    [self.mainView.shuffleModeButton addTarget:self action:@selector(pressShuffle) forControlEvents:UIControlEventTouchUpInside];
    
    // Phase 3: 设置评论按钮响应
    [self.mainView.commentButton addTarget:self action:@selector(pressCommentButton) forControlEvents:UIControlEventTouchUpInside];
    
    // 设置进度条事件监听（Phase A：进度条拖动播放）
    [self setupSliderEventHandlers];
    
    [self.view addSubview:self.mainView];

    // 使用Masonry设置主视图约束
    [self.mainView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    
    // 设置根视图背景色与评论面板一致，避免动画时出现颜色闪烁
    // 评论面板颜色是主题色的 0.9 倍（darken 10%）
    self.view.backgroundColor = [self themeBackgroundColor];
    
    // 注册通知监听
    [self registerNotifications];
    
    // 同步 shuffle 按钮初始状态
    [self updateShuffleButtonState:self.musicPlayerModel.playMode];

    // 如果已有正在播放的歌曲，立即显示
    NSLog(@"[MusicPlayerVC] 检查是否有正在播放的歌曲");
    if (self.musicPlayerModel.nowPlayingSong) {
        NSLog(@"[MusicPlayerVC] 有正在播放的歌曲，调用 configureWithSong");
        [self.mainView configureWithSong:self.musicPlayerModel.nowPlayingSong];
        
        // 【修复】检查播放状态：正在播放或正在加载都显示为播放状态
        BOOL shouldShowPlaying = self.musicPlayerModel.isPlaying || self.musicPlayerModel.isLoading;
        NSLog(@"[MusicPlayerVC] 同步播放按钮状态: isPlaying=%d, isLoading=%d, 显示=%d",
              self.musicPlayerModel.isPlaying, self.musicPlayerModel.isLoading, shouldShowPlaying);
        [self updatePlayButtonState:shouldShowPlaying];
        
        // 如果正在播放，启动进度条定时器
        if (self.musicPlayerModel.isPlaying) {
            [self startProgressTimer];
        }
        
        // 【修复】如果正在加载资源，启动定时器检查加载完成
        if (self.musicPlayerModel.isLoading) {
            NSLog(@"[MusicPlayerVC] 资源正在加载中，启动检查定时器");
            [self startLoadingCheckTimer];
        }
    } else {
        NSLog(@"[MusicPlayerVC] 没有正在播放的歌曲");
    }
    NSLog(@"[MusicPlayerVC] viewDidLoad 结束");
}

- (void)dealloc {
    // 移除通知监听（防止内存泄漏）
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    // 停止定时器
    [self stopProgressTimer];
    [self stopLoadingCheckTimer];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    NSLog(@"[MusicPlayerVC] viewWillAppear");
    
    // 【修复】再次检查播放状态，确保快速打开页面时显示正确
    // 处理场景：viewDidLoad 时正在加载，现在加载已完成
    if (self.musicPlayerModel.nowPlayingSong) {
        BOOL shouldShowPlaying = self.musicPlayerModel.isPlaying || self.musicPlayerModel.isLoading;
        if (self.isPlaying != shouldShowPlaying) {
            NSLog(@"[MusicPlayerVC] viewWillAppear 更新播放按钮状态: %d", shouldShowPlaying);
            [self updatePlayButtonState:shouldShowPlaying];
        }
        
        // 如果正在加载但检查定时器未启动，启动它
        if (self.musicPlayerModel.isLoading && !self.loadingCheckTimer) {
            [self startLoadingCheckTimer];
        }
        
        // 如果正在播放但进度定时器未启动，启动它
        if (self.musicPlayerModel.isPlaying && !self.progressTimer) {
            [self startProgressTimer];
        }
    }
    
    // 同步当前播放进度到 UI
    [self syncCurrentProgressToUI];
}

#pragma mark - 主题颜色

/// 获取与评论面板一致的背景色（主题色的 0.9 倍）
- (UIColor *)themeBackgroundColor {
    UIColor *baseColor = self.mainView.themeBaseColor;
    if (!baseColor) {
        return [UIColor colorWithWhite:0.12 alpha:1.0]; // 默认深色背景
    }
    CGFloat r, g, b, a;
    if (![baseColor getRed:&r green:&g blue:&b alpha:&a]) {
        return [UIColor colorWithWhite:0.12 alpha:1.0];
    }
    // 与评论面板保持一致：darken 10%
    return [UIColor colorWithRed:r * 0.90
                           green:g * 0.90
                            blue:b * 0.90
                           alpha:1.0];
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

    // 监听播放模式变更
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handlePlayModeDidChange:)
                                                 name:XCMusicPlayerPlayModeDidChangeNotification
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
        
        // 重置播放进度显示（主视图和迷你播放器）
        [self syncCurrentProgressToUI];
        
        // 如果评论面板展开，更新评论数据和迷你播放器内容
        // 注意：颜色更新通过委托方法 musicPlayerView:didUpdateThemeColor: 异步处理
        if (self.commentPanelVisible) {
            NSLog(@"[MusicPlayerVC] 评论面板展开中，同步更新迷你播放器和评论");
            
            // 更新迷你播放器内容（歌曲信息、封面、进度）
            [self updateMiniPlayerContent];
            
            // 重新加载新歌曲的评论
            XCSongCommentList *preloadedList = [self.musicPlayerModel getPreloadedCommentList];
            if (preloadedList) {
                NSLog(@"[MusicPlayerVC] 使用预加载的评论数据");
                self.commentPanel.commentList = preloadedList;
            } else {
                NSLog(@"[MusicPlayerVC] 预加载数据不存在，立即请求");
                [self.commentPanel showLoading];
                [self loadComments];
            }
        }
    });
}

- (void)handlePlaybackStateDidChange:(NSNotification *)notification {
    NSLog(@"[MusicPlayerVC] handlePlaybackStateDidChange 收到通知");
    BOOL isPlaying = [notification.userInfo[@"isPlaying"] boolValue];
    
    NSLog(@"[MusicPlayerVC] 播放状态: %@", isPlaying ? @"播放" : @"暂停");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updatePlayButtonState:isPlaying];
        
        // 根据播放状态启停进度条定时器
        if (isPlaying) {
            [self startProgressTimer];
        } else {
            [self stopProgressTimer];
        }
    });
}

- (void)updatePlayButtonState:(BOOL)isPlaying {
    self.isPlaying = isPlaying;
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithFont:[UIFont boldSystemFontOfSize:40]];
    UIImage *image = isPlaying
        ? [UIImage systemImageNamed:@"pause.fill" withConfiguration:config]
        : [UIImage systemImageNamed:@"play.fill" withConfiguration:config];
    [self.mainView.playOrStopButton setImage:image forState:UIControlStateNormal];
    
    // 评论面板展开时不更新封面大小，收起时由 hideCommentPanel 按状态恢复
    if (!self.commentPanelVisible) {
        if (isPlaying) {
            [self.mainView letAlbumImageBig];
        } else {
            [self.mainView letAlbumImageSmall];
        }
    }

    // 同步迷你播放器的播放按钮图标
    if (self.miniPlayerView) {
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration
            configurationWithPointSize:22 weight:UIImageSymbolWeightBold];
        NSString *iconName = isPlaying ? @"pause.fill" : @"play.fill";
        [self.miniPlayerView.playPauseButton setImage:[UIImage systemImageNamed:iconName
                                                             withConfiguration:cfg]
                                             forState:UIControlStateNormal];
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
        [self stopProgressTimer];
    } else {
        [self.musicPlayerModel playMusic];
        [self startProgressTimer];
    }
}
- (void)pressNextSong {
    [self.musicPlayerModel playNextSong];
}

- (void)pressPreviousSong {
    [self.musicPlayerModel playPreviousSong];
}

#pragma mark - 进度条拖动功能（Phase A）

/// 设置进度条事件监听
- (void)setupSliderEventHandlers {
    // 手指触碰滑块 - 开始拖动
    [self.mainView.mainSlider addTarget:self 
                                 action:@selector(sliderTouchDown:) 
                       forControlEvents:UIControlEventTouchDown];
    
    // 滑块值变化 - 拖动中
    [self.mainView.mainSlider addTarget:self 
                                 action:@selector(sliderValueChanged:) 
                       forControlEvents:UIControlEventValueChanged];
    
    // 手指松开滑块 - 结束拖动
    [self.mainView.mainSlider addTarget:self 
                                 action:@selector(sliderTouchUp:) 
                       forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    
    NSLog(@"[MusicPlayerVC] 进度条事件监听已设置");
}

/// TouchDown - 暂停并记录状态
- (void)sliderTouchDown:(UISlider *)slider {
    NSLog(@"[MusicPlayerVC] 👇 用户开始拖动进度条");
    
    // 如果正在调整中（快速多次点击），先取消之前的
    if (self.isSeeking) {
        NSLog(@"[MusicPlayerVC] 检测到正在拖动中，重置状态");
    }
    
    // 记录当前播放状态
    self.isSeeking = YES;
    self.wasPlayingBeforeSeek = self.musicPlayerModel.player.rate > 0;
    
    // 如果正在播放，暂停
    if (self.wasPlayingBeforeSeek) {
        NSLog(@"[MusicPlayerVC] 拖动前正在播放，先暂停");
        [self.musicPlayerModel pauseMusic];
    }
    
    // 停止进度条定时器（防止拖动时进度条自己跳动）
    [self stopProgressTimer];
    
    // 触感反馈
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [feedback impactOccurred];
}

/// ValueChanged - 拖动中更新显示
- (void)sliderValueChanged:(UISlider *)slider {
    // 将 slider 的 0.0~1.0 转换为实际时间（秒）
    CGFloat progress = slider.value;  // 0.0 ~ 1.0
    NSTimeInterval totalDuration = self.musicPlayerModel.nowPlayingSong.duration / 1000.0;
    NSTimeInterval targetTime = progress * totalDuration;
    
    // 格式化时间显示
    NSString *timeText = [self formatTime:targetTime];
    NSLog(@"[MusicPlayerVC] 🎚️ 拖动中: %@ (%.1fs)", timeText, targetTime);
    
    // 实时更新时间标签
    [self.mainView updateCurrentTime:targetTime];
}

/// TouchUp - 执行跳转并恢复
- (void)sliderTouchUp:(UISlider *)slider {
    NSLog(@"[MusicPlayerVC] 👆 用户松开进度条");
    
    // 计算目标时间
    CGFloat progress = slider.value;
    NSTimeInterval totalDuration = self.musicPlayerModel.nowPlayingSong.duration / 1000.0;
    NSTimeInterval targetTime = progress * totalDuration;
    
    NSLog(@"[MusicPlayerVC] 准备跳转到: %.1fs", targetTime);
    
    // 执行跳转（seek）
    [self seekToTime:targetTime];
    
    // 如果之前在播放，恢复播放
    if (self.wasPlayingBeforeSeek) {
        NSLog(@"[MusicPlayerVC] 恢复播放");
        [self.musicPlayerModel playMusic];
        [self startProgressTimer];
    }
    
    // 重置状态
    self.isSeeking = NO;
    
    // 触感反馈
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [feedback impactOccurred];
}

/// 跳转到指定时间
- (void)seekToTime:(NSTimeInterval)time {
    // 检查有效性
    if (time < 0) time = 0;
    NSTimeInterval duration = self.musicPlayerModel.nowPlayingSong.duration / 1000.0;
    if (time > duration) time = duration;
    
    CMTime targetCMTime = CMTimeMakeWithSeconds(time, NSEC_PER_SEC);
    
    __weak typeof(self) weakSelf = self;
    [self.musicPlayerModel.player seekToTime:targetCMTime 
                           completionHandler:^(BOOL finished) {
        if (finished) {
            NSLog(@"[PlayerVC] ✅ 跳转完成: %.1fs", time);
            // 跳转完成后更新锁屏信息
            [weakSelf.musicPlayerModel updateLockScreenInfo];
        } else {
            NSLog(@"[PlayerVC] ⚠️ 跳转被取消");
        }
    }];
}

/// 格式化时间显示
- (NSString *)formatTime:(NSTimeInterval)timeInterval {
    NSInteger minutes = (NSInteger)timeInterval / 60;
    NSInteger seconds = (NSInteger)timeInterval % 60;
    return [NSString stringWithFormat:@"%02ld:%02ld", (long)minutes, (long)seconds];
}

#pragma mark - 资源加载检查（修复快速打开页面状态不同步问题）

/// 启动资源加载检查定时器
- (void)startLoadingCheckTimer {
    [self stopLoadingCheckTimer];
    
    // 每 0.3 秒检查一次资源加载状态
    self.loadingCheckTimer = [NSTimer scheduledTimerWithTimeInterval:0.3
                                                              target:self
                                                            selector:@selector(checkLoadingState)
                                                            userInfo:nil
                                                             repeats:YES];
    NSLog(@"[MusicPlayerVC] 启动资源加载检查定时器");
}

/// 停止资源加载检查定时器
- (void)stopLoadingCheckTimer {
    if (self.loadingCheckTimer) {
        [self.loadingCheckTimer invalidate];
        self.loadingCheckTimer = nil;
        NSLog(@"[MusicPlayerVC] 停止资源加载检查定时器");
    }
}

/// 检查资源加载状态
- (void)checkLoadingState {
    // 如果资源加载完成
    if (!self.musicPlayerModel.isLoading) {
        NSLog(@"[MusicPlayerVC] 资源加载完成，更新播放状态");
        
        // 更新播放按钮状态
        [self updatePlayButtonState:self.musicPlayerModel.isPlaying];
        
        // 如果已经开始播放，启动进度条定时器
        if (self.musicPlayerModel.isPlaying) {
            [self startProgressTimer];
        }
        
        // 停止检查定时器
        [self stopLoadingCheckTimer];
    }
}

#pragma mark - 进度条自动更新

/// 开始定时更新滑块位置
- (void)startProgressTimer {
    [self stopProgressTimer];
    
    // 每 0.5 秒更新一次
    self.progressTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                          target:self
                                                        selector:@selector(updateSliderProgress)
                                                        userInfo:nil
                                                         repeats:YES];
    NSLog(@"[MusicPlayerVC] 启动进度条定时器");
}

/// 停止定时更新
- (void)stopProgressTimer {
    if (self.progressTimer) {
        [self.progressTimer invalidate];
        self.progressTimer = nil;
        NSLog(@"[MusicPlayerVC] 停止进度条定时器");
    }
}

/// 更新滑块位置
- (void)updateSliderProgress {
    // 拖动中不更新（避免冲突）
    if (self.isSeeking) return;
    
    // 检查有效性
    if (!self.musicPlayerModel.player || !self.musicPlayerModel.nowPlayingSong) return;
    
    NSTimeInterval currentTime = CMTimeGetSeconds(self.musicPlayerModel.player.currentTime);
    NSTimeInterval duration = self.musicPlayerModel.nowPlayingSong.duration / 1000.0;
    
    // 处理无效值
    if (isnan(currentTime) || currentTime < 0) currentTime = 0;
    if (duration <= 0) return;

    // 更新滑块位置
    CGFloat progress = currentTime / duration;
    self.mainView.mainSlider.value = progress;

    // 同步迷你播放器进度条
    if (self.miniPlayerView) {
        self.miniPlayerView.progressView.progress = progress;
    }

    // 更新当前时间标签
    [self.mainView updateCurrentTime:currentTime];
}

/// 同步当前播放进度到 UI（用于 viewWillAppear 等场景）
- (void)syncCurrentProgressToUI {
    if (!self.musicPlayerModel.player || !self.musicPlayerModel.nowPlayingSong) {
        NSLog(@"[MusicPlayerVC] 无法同步进度：播放器或歌曲为空");
        return;
    }
    
    NSTimeInterval currentTime = CMTimeGetSeconds(self.musicPlayerModel.player.currentTime);
    NSTimeInterval duration = self.musicPlayerModel.nowPlayingSong.duration / 1000.0;
    
    // 处理无效值
    if (isnan(currentTime) || currentTime < 0) currentTime = 0;
    if (duration <= 0) return;
    
    // 更新滑块位置
    CGFloat progress = currentTime / duration;
    self.mainView.mainSlider.value = progress;
    
    // 同步迷你播放器进度条
    if (self.miniPlayerView) {
        self.miniPlayerView.progressView.progress = progress;
    }
    
    // 更新当前时间标签
    [self.mainView updateCurrentTime:currentTime];
    
    NSLog(@"[MusicPlayerVC] 同步播放进度到 UI: %.1f / %.1f (%.1f%%)", 
          currentTime, duration, progress * 100);
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

#pragma mark - 播放模式

- (void)pressShuffle {
    XCMusicPlayerModel *m = [XCMusicPlayerModel sharedInstance];
    m.playMode = (m.playMode == XCPlayModeSequential) ? XCPlayModeShuffle : XCPlayModeSequential;
    UIImpactFeedbackGenerator *f = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [f impactOccurred];
}

- (void)updateShuffleButtonState:(XCPlayMode)mode {
    BOOL isShuffle = (mode == XCPlayModeShuffle);
    self.mainView.shuffleModeButton.tintColor = isShuffle
        ? [UIColor whiteColor]
        : [UIColor colorWithWhite:1.0 alpha:0.5];
}

- (void)handlePlayModeDidChange:(NSNotification *)note {
    XCPlayMode mode = (XCPlayMode)[note.userInfo[@"playMode"] integerValue];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateShuffleButtonState:mode];
    });
}

- (void)pressCommentButton {
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [feedback impactOccurred];
    
    if (self.commentPanelVisible) {
        [self hideCommentPanel];
    } else {
        [self showCommentPanel];
    }
}

- (void)showCommentPanel {
    if (self.commentPanelVisible) return;

    NSLog(@"[MusicPlayerVC] 显示评论面板");
    self.commentPanelVisible = YES;

    [self.view layoutIfNeeded];
    CGFloat screenHeight = self.view.bounds.size.height;
    CGFloat panelHeight  = screenHeight * 0.70;

    // 更新根视图背景色与评论面板一致，避免动画时颜色闪烁
    self.view.backgroundColor = [self themeBackgroundColor];

    // 创建评论面板
    if (!self.commentPanel) {
        self.commentPanel = [[XCSongCommentPanel alloc] init];
        self.commentPanel.delegate = self;
        [self.view addSubview:self.commentPanel];
        [self.commentPanel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.right.equalTo(self.view);
            make.height.mas_equalTo(panelHeight);
            make.top.equalTo(self.view.mas_bottom);
        }];
        [self.commentPanel applyThemeColor:self.mainView.themeBaseColor];
    }

    // 创建迷你播放控制器（填充评论面板上方的可见区域）
    if (!self.miniPlayerView) {
        self.miniPlayerView = [[XCMiniPlayerView alloc] init];
        self.miniPlayerView.alpha = 0;
        [self.view addSubview:self.miniPlayerView];
        [self.miniPlayerView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.view.mas_safeAreaLayoutGuideTop);
            make.left.right.equalTo(self.view);
            make.bottom.equalTo(self.view.mas_bottom).offset(-panelHeight);
        }];

        // 绑定按钮事件
        [self.miniPlayerView.shuffleButton addTarget:self
                                              action:@selector(pressShuffle)
                                    forControlEvents:UIControlEventTouchUpInside];
        [self.miniPlayerView.prevButton addTarget:self
                                           action:@selector(pressPreviousSong)
                                 forControlEvents:UIControlEventTouchUpInside];
        [self.miniPlayerView.playPauseButton addTarget:self
                                                action:@selector(pressPlayOrStopButton)
                                      forControlEvents:UIControlEventTouchUpInside];
        [self.miniPlayerView.nextButton addTarget:self
                                           action:@selector(pressNextSong)
                                 forControlEvents:UIControlEventTouchUpInside];
        [self.miniPlayerView.commentButton addTarget:self
                                              action:@selector(pressCommentButton)
                                    forControlEvents:UIControlEventTouchUpInside];

        [self updateMiniPlayerContent];
        [self.miniPlayerView applyThemeColor:self.mainView.themeBaseColor];
    }

    // 加载评论数据
    XCSongCommentList *preloadedList = [self.musicPlayerModel getPreloadedCommentList];
    if (preloadedList) {
        NSLog(@"[MusicPlayerVC] 使用预加载的评论数据");
        self.commentPanel.commentList = preloadedList;
    } else {
        NSLog(@"[MusicPlayerVC] 预加载数据不存在，立即请求");
        [self.commentPanel showLoading];
        [self loadComments];
    }

    // 动画：主视图淡出，迷你播放器淡入，面板滑入
    self.view.userInteractionEnabled = NO;
    [UIView animateWithDuration:0.35 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.mainView.alpha = 0;
        self.commentPanel.transform = CGAffineTransformMakeTranslation(0, -panelHeight);
        self.miniPlayerView.alpha = 1;
    } completion:^(BOOL finished) {
        self.view.userInteractionEnabled = YES;
    }];
}

- (void)hideCommentPanel {
    if (!self.commentPanelVisible) return;

    NSLog(@"[MusicPlayerVC] 隐藏评论面板");
    self.commentPanelVisible = NO;

    CGFloat panelHeight = self.view.bounds.size.height * 0.70;
    // 直接恢复到正确的播放状态大小，与主视图淡入同步完成
    CGAffineTransform targetAlbumTransform = self.isPlaying ? self.mainView.scaleTransform
                                                            : CGAffineTransformIdentity;

    self.view.userInteractionEnabled = NO;
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        self.mainView.alpha = 1;
        self.mainView.albumImage.transform = targetAlbumTransform;
        self.mainView.containerImageView.transform = targetAlbumTransform;
        self.commentPanel.transform = CGAffineTransformIdentity;
        self.miniPlayerView.alpha = 0;
    } completion:^(BOOL finished) {
        self.view.userInteractionEnabled = YES;
        [self.commentPanel removeFromSuperview];
        self.commentPanel = nil;
        [self.miniPlayerView removeFromSuperview];
        self.miniPlayerView = nil;
    }];
}

/// 填充迷你播放器的歌曲信息和播放状态
- (void)updateMiniPlayerContent {
    if (!self.miniPlayerView) return;

    XC_YYSongData *song = self.musicPlayerModel.nowPlayingSong;
    self.miniPlayerView.songNameLabel.text  = song.name   ?: @"未知歌曲";
    self.miniPlayerView.artistLabel.text    = song.artist ?: @"未知艺术家";
    
    // 加载专辑封面 - 优先使用主视图已加载的图片，如果没有则独立加载
    if (self.mainView.albumImage.image && [self isSameSong:song image:self.mainView.albumImage.image]) {
        self.miniPlayerView.albumImageView.image = self.mainView.albumImage.image;
    } else if (song.mainIma) {
        // 独立加载封面
        NSURL *imageURL = [NSURL URLWithString:song.mainIma];
        [self.miniPlayerView.albumImageView sd_setImageWithURL:imageURL
                                            placeholderImage:self.mainView.albumImage.image
                                                     options:SDWebImageRetryFailed];
    }

    // 播放 / 暂停按钮图标
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration
        configurationWithPointSize:22 weight:UIImageSymbolWeightBold];
    NSString *iconName = self.isPlaying ? @"pause.fill" : @"play.fill";
    [self.miniPlayerView.playPauseButton setImage:[UIImage systemImageNamed:iconName
                                                         withConfiguration:cfg]
                                         forState:UIControlStateNormal];

    // 当前进度
    self.miniPlayerView.progressView.progress = self.mainView.mainSlider.value;
}

/// 判断图片是否属于当前歌曲（简单判断：图片不为空即可）
- (BOOL)isSameSong:(XC_YYSongData *)song image:(UIImage *)image {
    // 只要主视图有图片，就认为是当前歌曲的（因为切歌时会立即开始加载新封面）
    return image != nil;
}

- (void)loadComments {
    NSString *songId = self.musicPlayerModel.nowPlayingSong.songId;
    if (!songId) return;

    __weak typeof(self) weakSelf = self;
    [[XCSongCommentService sharedInstance] fetchCommentsForSongId:songId
                                                         sortType:XCCommentSortTypeHot
                                                            limit:20
                                                           before:nil
                                                       completion:^(XCSongCommentList * _Nullable commentList, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            if (commentList) {
                strongSelf.commentPanel.commentList = commentList;
            } else {
                [strongSelf.commentPanel showEmptyState];
            }
        });
    }];
}

#pragma mark - XCSongCommentPanelDelegate

- (void)commentPanelDidTapClose:(XCSongCommentPanel *)panel {
    [self hideCommentPanel];
}

- (BOOL)isCommentPanelVisible {
    return self.commentPanelVisible;
}

- (void)commentPanelDidRequestLoadMore:(XCSongCommentPanel *)panel {
    // 加载更多逻辑
}

- (void)commentPanel:(XCSongCommentPanel *)panel didTapViewReplies:(XCSongComment *)comment {
    NSLog(@"[MusicPlayerVC] 查看评论回复: %@", comment.commentId);

    NSString *songId = self.musicPlayerModel.nowPlayingSong.songId;
    if (!songId || !comment.commentId) return;

    XCSongCommentFloorViewController *floorVC = [[XCSongCommentFloorViewController alloc] initWithComment:comment songId:songId];
    floorVC.modalPresentationStyle = UIModalPresentationPageSheet;

    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *sheet = floorVC.sheetPresentationController;
        sheet.detents = @[UISheetPresentationControllerDetent.mediumDetent,
                          UISheetPresentationControllerDetent.largeDetent];
        sheet.prefersGrabberVisible = YES;
        sheet.preferredCornerRadius = 16;
    }

    [self presentViewController:floorVC animated:YES completion:nil];
}

- (void)commentPanel:(XCSongCommentPanel *)panel didToggleExpandForComment:(XCSongComment *)comment atIndexPath:(NSIndexPath *)indexPath {
    // 长评论展开/收起已在面板内部处理
}

#pragma mark - XCMusicPlayerViewDelegate

/// 主题色更新回调（图片加载完成后触发）
- (void)musicPlayerView:(XCMusicPlayerView *)view didUpdateThemeColor:(UIColor *)themeColor {
    NSLog(@"[MusicPlayerVC] 收到主题色更新: %@", themeColor);
    
    // 如果评论面板展开，同步更新所有相关视图的颜色
    if (self.commentPanelVisible) {
        NSLog(@"[MusicPlayerVC] 评论面板展开中，同步更新颜色");
        
        // 更新根视图背景色
        self.view.backgroundColor = [self themeBackgroundColor];
        
        // 更新评论面板颜色
        [self.commentPanel applyThemeColor:themeColor];
        
        // 更新迷你播放器颜色
        [self.miniPlayerView applyThemeColor:themeColor];
    }
}

@end
