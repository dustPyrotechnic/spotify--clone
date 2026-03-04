//
//  XCMusicPlayerView.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/12/1.
//

#import <UIKit/UIKit.h>
#import "XC-YYSongData.h"

NS_ASSUME_NONNULL_BEGIN

@class XCMusicPlayerView;

@protocol XCMusicPlayerViewDelegate <NSObject>
@optional
/// 主题色更新回调（图片加载完成后触发）
- (void)musicPlayerView:(XCMusicPlayerView *)view didUpdateThemeColor:(UIColor *)themeColor;
@end

@interface XCMusicPlayerView : UIView
// 歌曲信息
@property (nonatomic, strong) UIImage* image;
@property (nonatomic, strong) UIImageView* albumImage;
@property (nonatomic, strong) UILabel* songNameLabel;
// 防止名字过于长
@property (nonatomic, strong) UIScrollView* songNameContainerScrollView;
@property (nonatomic, strong) UILabel* authorNameLabel;
// 同样
@property (nonatomic, strong) UIScrollView* authorNameContainerScrollView;

// 播放信息和播放控制
/// 放置控制元件的容器视图
@property (nonatomic, strong) UIView* controlContainerView;
/// 主滑块
@property (nonatomic, strong) UISlider* mainSlider;
/// 当前时间标签
@property (nonatomic, strong) UILabel* currentTimeLabel;
/// 总时长标签
@property (nonatomic, strong) UILabel* totalTimeLabel;
/// 上一首按钮
@property (nonatomic, strong) UIButton* preSongButton;
/// 下一首按钮
@property (nonatomic, strong) UIButton* nexSongButton;
/// 播放或暂停按钮
@property (nonatomic, strong) UIButton* playOrStopButton;
/// 随机/顺序播放模式切换按钮
@property (nonatomic, strong) UIButton* shuffleModeButton;
/// 播放按钮背景视图（用于美化）
@property (nonatomic, strong) UIView* playButtonBackground;

// Phase 2: 评论入口按钮
@property (nonatomic, strong) UIButton* commentButton;

// 辅助动画效果
@property (nonatomic, assign) CGAffineTransform scaleTransform;
// 用来显示照片图层
@property (nonatomic, strong) UIView* containerImageView;
/// 当前封面提取的主题基色（供评论面板等使用）
@property (nonatomic, strong, readonly, nullable) UIColor *themeBaseColor;

/// 委托对象
@property (nonatomic, weak) id<XCMusicPlayerViewDelegate> delegate;

- (void) letAlbumImageBig;
- (void) letAlbumImageSmall;

#pragma mark - 配置方法
/// 根据歌曲数据配置视图
- (void)configureWithSong:(XC_YYSongData *)song;

/// 更新当前时间显示
- (void)updateCurrentTime:(NSTimeInterval)currentTime;
@end

NS_ASSUME_NONNULL_END
