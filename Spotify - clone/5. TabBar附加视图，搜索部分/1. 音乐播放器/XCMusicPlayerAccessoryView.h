//
//  XCMusicPayerAccessoryView.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/11/24.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface XCMusicPlayerAccessoryView : UIView
///封面视图
@property (nonatomic, strong) UIImageView* imageView;
///歌曲题目
@property (nonatomic, strong) UILabel* titleLabel;
///作者题目
@property (nonatomic, strong) UILabel* authorLabel;
///暂停播放按钮
@property (nonatomic, strong) UIButton* stopOrContinueButton;
///下一首歌按钮
@property (nonatomic, strong) UIButton* nextSong;
// 是否在播放
@property (nonatomic, assign) BOOL isPlaying;
// 使用一个block
///初始化这个View和照片
- (instancetype) initWithFrame:(CGRect)frame withImage:(UIImage*)image andTitle:(NSString*)title withSonger:(NSString*)songer withCondition:(BOOL) isPlaying;
@end

NS_ASSUME_NONNULL_END
