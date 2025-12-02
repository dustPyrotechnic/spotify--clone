//
//  HomePageViewCollectionViewCell.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/11/22.
//

#import <UIKit/UIKit.h>
#import "XCAlbumSimpleData.h"

NS_ASSUME_NONNULL_BEGIN

@interface HomePageViewCollectionViewCell : UICollectionViewCell
@property (nonatomic, strong) UIImageView* imageView;
@property (nonatomic, strong) UILabel* titleLable;
@property (nonatomic, strong) XCAlbumSimpleData* data;
- (void) getDataAndLayout;
@end

NS_ASSUME_NONNULL_END
