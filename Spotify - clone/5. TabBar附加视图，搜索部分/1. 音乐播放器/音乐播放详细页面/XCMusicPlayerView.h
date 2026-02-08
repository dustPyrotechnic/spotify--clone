//
//  XCMusicPlayerView.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/12/1.
//

#import <UIKit/UIKit.h>
#import "XC-YYSongData.h"

NS_ASSUME_NONNULL_BEGIN

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
/// 上一首按钮
@property (nonatomic, strong) UIButton* preSongButton;
/// 下一首按钮
@property (nonatomic, strong) UIButton* nexSongButton;
/// 播放或暂停按钮
@property (nonatomic, strong) UIButton* playOrStopButton;

// 辅助动画效果
@property (nonatomic, assign) CGAffineTransform scaleTransform;
// 用来显示照片图层
@property (nonatomic, strong) UIView* containerImageView;
- (void) letAlbumImageBig;
- (void) letAlbumImageSmall;

#pragma mark - 配置方法
/// 根据歌曲数据配置视图
- (void)configureWithSong:(XC_YYSongData *)song;
@end

NS_ASSUME_NONNULL_END
