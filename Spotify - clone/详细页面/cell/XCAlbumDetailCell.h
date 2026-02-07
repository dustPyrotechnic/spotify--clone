//
//  XCAlbumDetailCell.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/12/11.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface XCAlbumDetailCell : UITableViewCell
/// 显示歌曲照片
@property (nonatomic, strong) UIImageView* mainImageView;
/// 显示歌曲名字
@property (nonatomic, strong) UILabel* songLabel;
/// 歌曲id信息
@property (nonatomic, strong) NSString* songId;
/// 显示作者名字
@property (nonatomic, strong) UILabel* authorLabel;
/// 显示歌曲时长
@property (nonatomic, strong) UILabel* durationLabel;
/// 显示菜单
@property (nonatomic, strong) UIButton* menuButton;
@end

NS_ASSUME_NONNULL_END
