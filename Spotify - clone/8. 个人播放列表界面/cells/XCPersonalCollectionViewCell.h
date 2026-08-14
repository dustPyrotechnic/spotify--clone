//
//  XCPersonalCollectionViewCell.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/22.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 播放列表封面 Grid 模式 Cell（2 列布局）
@interface XCPersonalCollectionViewCell : UICollectionViewCell

@property (nonatomic, strong) UIImageView *coverImageView;
@property (nonatomic, strong) UILabel *nameLabel;

@end

NS_ASSUME_NONNULL_END
