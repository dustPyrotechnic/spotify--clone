//
//  XCSearchResultCell.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/23.
//

#import <UIKit/UIKit.h>

@class XC_YYSongData;
@class XC_YYAlbumData;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, XCSearchResultType) {
    XCSearchResultTypeSong,    // 歌曲
    XCSearchResultTypeAlbum,   // 专辑
    XCSearchResultTypeArtist   // 艺人
};

/// 搜索结果通用 Cell - 统一歌曲、专辑、艺人的展示风格
@interface XCSearchResultCell : UITableViewCell

/// 结果类型
@property (nonatomic, assign) XCSearchResultType resultType;

/// 封面图片
@property (nonatomic, strong, readonly) UIImageView *coverImageView;
/// 主标题
@property (nonatomic, strong, readonly) UILabel *titleLabel;
/// 副标题
@property (nonatomic, strong, readonly) UILabel *subtitleLabel;
/// 右侧操作按钮
@property (nonatomic, strong, readonly) UIButton *actionButton;

/// 关联的歌曲数据（用于菜单操作）
@property (nonatomic, strong, readonly, nullable) XC_YYSongData *songData;

/// 设置歌曲数据
- (void)configureWithSong:(XC_YYSongData *)songData;
/// 设置专辑数据
- (void)configureWithAlbum:(XC_YYAlbumData *)albumData;
/// 设置艺人数据
- (void)configureWithArtist:(NSDictionary *)artistData;

/// 配置操作按钮的菜单（仅对歌曲有效）
- (void)configureActionMenuWithProvider:(UIMenu *(^)(XC_YYSongData *song))menuProvider;

@end

NS_ASSUME_NONNULL_END
