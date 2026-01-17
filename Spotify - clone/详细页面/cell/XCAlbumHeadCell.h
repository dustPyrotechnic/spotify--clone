//
//  XCAlbumHeadCell.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/12/21.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface XCAlbumHeadCell : UITableViewCell
/// 封面图
@property (nonatomic, strong) UIImageView* albumImageView;
/// 专辑标题
@property (nonatomic, strong) UILabel* titleLabel;
/// 更新日期
@property (nonatomic, strong) UILabel* refreshDateLabel;
/// 播放按钮
@property (nonatomic, strong) UIButton* playButton;
/// 随机按钮
@property (nonatomic, strong) UIButton* randomButton;
@end

NS_ASSUME_NONNULL_END
