//
//  XCMiniPlayerView.h
//  Spotify - clone
//
//  评论面板展开时显示在上方的简易播放控制器
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface XCMiniPlayerView : UIView

/// 专辑封面
@property (nonatomic, strong) UIImageView *albumImageView;
/// 歌曲名称
@property (nonatomic, strong) UILabel *songNameLabel;
/// 艺术家名称
@property (nonatomic, strong) UILabel *artistLabel;
/// 播放顺序按钮（左侧）
@property (nonatomic, strong) UIButton *shuffleButton;
/// 上一首
@property (nonatomic, strong) UIButton *prevButton;
/// 播放 / 暂停
@property (nonatomic, strong) UIButton *playPauseButton;
/// 下一首
@property (nonatomic, strong) UIButton *nextButton;
/// 评论按钮（右侧，点击收起评论面板）
@property (nonatomic, strong) UIButton *commentButton;
/// 播放进度条
@property (nonatomic, strong) UIProgressView *progressView;

/// 应用播放页主题色（与详细页面背景色一致，darken ~20%）
- (void)applyThemeColor:(UIColor *)baseColor;

@end

NS_ASSUME_NONNULL_END
