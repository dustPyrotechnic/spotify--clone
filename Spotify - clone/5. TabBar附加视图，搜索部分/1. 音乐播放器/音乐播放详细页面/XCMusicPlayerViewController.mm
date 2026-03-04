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

// Phase 3: 评论模块
#import "XCSongCommentPanel.h"
#import "XCSongCommentList.h"
#import "XCSongCommentService.h"

// Phase 5: 楼层评论
#import "XCSongCommentFloorViewController.h"

@interface XCMusicPlayerViewController () <XCSongCommentPanelDelegate>
/// 拖动进度条前是否正在播放
@property (nonatomic, assign) BOOL wasPlayingBeforeSeek;
/// 是否正在拖动进度条
@property (nonatomic, assign) BOOL isSeeking;
/// 进度条更新定时器
@property (nonatomic, strong) NSTimer *progressTimer;

#pragma mark - Phase 3: 评论面板属性
/// 评论面板
@property (nonatomic, strong) XCSongCommentPanel *commentPanel;
/// 蒙层视图
@property (nonatomic, strong) UIView *commentMaskView;
/// 评论面板是否可见（内部存储）
@property (nonatomic, assign) BOOL commentPanelVisible;
/// 内容中心Y约束（用于动画）
@property (nonatomic, strong) MASConstraint *contentCenterYConstraint;
/// 评论面板展开时浮在可见区域的评论按钮（用于收起面板）
@property (nonatomic, strong) UIButton *floatingCommentButton;
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
    
    // 注册通知监听
    [self registerNotifications];
    
    // 同步 shuffle 按钮初始状态
    [self updateShuffleButtonState:self.musicPlayerModel.playMode];

    // 如果已有正在播放的歌曲，立即显示
    NSLog(@"[MusicPlayerVC] 检查是否有正在播放的歌曲");
    if (self.musicPlayerModel.nowPlayingSong) {
        NSLog(@"[MusicPlayerVC] 有正在播放的歌曲，调用 configureWithSong");
        [self.mainView configureWithSong:self.musicPlayerModel.nowPlayingSong];
        // 同步播放按钮状态（使用 Model 维护的状态）
        [self updatePlayButtonState:self.musicPlayerModel.isPlaying];
        // 如果正在播放，启动进度条定时器
        if (self.musicPlayerModel.isPlaying) {
            [self startProgressTimer];
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
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    NSLog(@"[MusicPlayerVC] viewWillAppear");
    
    // 同步当前播放进度到 UI
    [self syncCurrentProgressToUI];
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

#pragma mark - Phase 3: 评论面板

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

    // 确保视图尺寸已确定
    [self.view layoutIfNeeded];

    CGFloat screenHeight = self.view.bounds.size.height;
    CGFloat screenWidth  = self.view.bounds.size.width;
    CGFloat safeTop      = self.view.safeAreaInsets.top;
    CGFloat panelHeight  = screenHeight * 0.70;

    // 计算专辑图片动画参数（缩小并上移到可见区域上半部）
    CGFloat albumSize          = screenWidth * 0.618;
    CGFloat targetAlbumSize    = (screenHeight - panelHeight) * 0.42;   // 可见区域高度的 42%
    CGFloat albumScale         = targetAlbumSize / albumSize;
    CGFloat currentAlbumCenterY = safeTop + 100.0 + albumSize * 0.5;
    CGFloat targetAlbumCenterY  = safeTop + (screenHeight - panelHeight) * 0.38;
    CGFloat albumTranslateY    = targetAlbumCenterY - currentAlbumCenterY;

    // scale + translate：先缩放再平移（平移在父坐标系中）
    CGAffineTransform albumTransform = CGAffineTransformConcat(
        CGAffineTransformMakeScale(albumScale, albumScale),
        CGAffineTransformMakeTranslation(0, albumTranslateY)
    );

    // 1. 创建评论面板（首次显示时）
    if (!self.commentPanel) {
        self.commentPanel = [[XCSongCommentPanel alloc] init];
        self.commentPanel.delegate = self;
        [self.view addSubview:self.commentPanel];
        [self.commentPanel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.right.equalTo(self.view);
            make.height.mas_equalTo(panelHeight);
            make.top.equalTo(self.view.mas_bottom);
        }];
        // 应用与播放页同色系的主题背景（稍亮以区分层次）
        [self.commentPanel applyThemeColor:self.mainView.themeBaseColor];
    }

    // 2. 创建浮动评论按钮（位于封面下方可见区域，点击可收起面板）
    if (!self.floatingCommentButton) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:20
                                                                                             weight:UIImageSymbolWeightMedium];
        self.floatingCommentButton = [[UIButton alloc] init];
        [self.floatingCommentButton setImage:[UIImage systemImageNamed:@"message.fill" withConfiguration:config]
                                    forState:UIControlStateNormal];
        self.floatingCommentButton.tintColor = [UIColor whiteColor];
        self.floatingCommentButton.alpha = 0;
        [self.floatingCommentButton addTarget:self
                                       action:@selector(pressCommentButton)
                             forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:self.floatingCommentButton];

        // 浮动按钮垂直居中于专辑图片底部与面板顶部之间的空隙
        CGFloat albumBottomAfterTransform = targetAlbumCenterY + targetAlbumSize * 0.5;
        CGFloat buttonCenterY = albumBottomAfterTransform + (screenHeight - panelHeight - albumBottomAfterTransform) * 0.5;
        [self.floatingCommentButton mas_makeConstraints:^(MASConstraintMaker *make) {
            make.centerX.equalTo(self.view);
            make.centerY.equalTo(self.view.mas_top).offset(buttonCenterY);
            make.width.height.mas_equalTo(44);
        }];
    }

    // 3. 加载评论数据
    XCSongCommentList *preloadedList = [self.musicPlayerModel getPreloadedCommentList];
    if (preloadedList) {
        NSLog(@"[MusicPlayerVC] 使用预加载的评论数据");
        self.commentPanel.commentList = preloadedList;
    } else {
        NSLog(@"[MusicPlayerVC] 预加载数据不存在，立即请求");
        [self.commentPanel showLoading];
        [self loadComments];
    }

    // 4. 执行动画
    self.view.userInteractionEnabled = NO;
    [UIView animateWithDuration:0.35 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        // 专辑封面缩小上移
        self.mainView.albumImage.transform = albumTransform;
        self.mainView.containerImageView.transform = albumTransform;
        // 控制区域淡出
        self.mainView.controlContainerView.alpha = 0;
        // 评论面板滑入
        self.commentPanel.transform = CGAffineTransformMakeTranslation(0, -panelHeight);
        // 浮动评论按钮淡入
        self.floatingCommentButton.alpha = 1;
    } completion:^(BOOL finished) {
        self.view.userInteractionEnabled = YES;
    }];
}

- (void)hideCommentPanel {
    if (!self.commentPanelVisible) return;

    NSLog(@"[MusicPlayerVC] 隐藏评论面板");
    self.commentPanelVisible = NO;

    CGFloat panelHeight = self.view.bounds.size.height * 0.70;

    // 按当前播放状态决定封面目标大小
    CGAffineTransform targetAlbumTransform = self.isPlaying ? self.mainView.scaleTransform : CGAffineTransformIdentity;

    self.view.userInteractionEnabled = NO;
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        // 专辑封面恢复到正确播放状态大小
        self.mainView.albumImage.transform = targetAlbumTransform;
        self.mainView.containerImageView.transform = targetAlbumTransform;
        // 控制区域恢复
        self.mainView.controlContainerView.alpha = 1;
        // 评论面板滑出
        self.commentPanel.transform = CGAffineTransformIdentity;
        // 浮动按钮淡出
        self.floatingCommentButton.alpha = 0;
    } completion:^(BOOL finished) {
        self.view.userInteractionEnabled = YES;
        [self.commentPanel removeFromSuperview];
        self.commentPanel = nil;
        [self.floatingCommentButton removeFromSuperview];
        self.floatingCommentButton = nil;
    }];
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

- (void)commentPanel:(XCSongCommentPanel *)panel didChangeSortType:(XCCommentSortType)sortType {
    NSLog(@"[MusicPlayerVC] 切换评论排序: %ld", (long)sortType);
    [self.commentPanel showLoading];

    NSString *songId = self.musicPlayerModel.nowPlayingSong.songId;
    __weak typeof(self) weakSelf = self;
    [[XCSongCommentService sharedInstance] fetchCommentsForSongId:songId
                                                         sortType:sortType
                                                            limit:20
                                                           before:nil
                                                       completion:^(XCSongCommentList * _Nullable commentList, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf || !commentList) return;
            strongSelf.commentPanel.commentList = commentList;
        });
    }];
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

@end
