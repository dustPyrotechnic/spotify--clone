//
//  XCPersonalListCell.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/20.
//
//  列表视图 Cell（基于 UICollectionViewCell）
//

#import <UIKit/UIKit.h>
#import "XC-YYAlbumData.h"
#import "XCLocalPlaylistInfo.h"

NS_ASSUME_NONNULL_BEGIN

/// 个人播放列表列表 Cell
@interface XCPersonalListCell : UICollectionViewCell

#pragma mark - UI 元素
/// 封面图片
@property (nonatomic, strong, readonly) UIImageView* coverImageView;
/// 播放列表名称
@property (nonatomic, strong, readonly) UILabel* nameLabel;
/// 副标题（歌曲数量 + 创建者）
@property (nonatomic, strong, readonly) UILabel* subtitleLabel;
/// 右侧箭头
@property (nonatomic, strong, readonly) UIImageView* arrowImageView;

#pragma mark - 配置方法
/// 配置 Cell
/// @param playlist 播放列表数据
/// @param info 本地扩展信息
- (void)configureWithPlaylist:(XC_YYAlbumData*)playlist 
                           info:(nullable XCLocalPlaylistInfo*)info;

/// 配置占位图
- (void)configurePlaceholder;

@end

NS_ASSUME_NONNULL_END
