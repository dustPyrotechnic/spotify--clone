//
//  HomePageViewCollectionViewTableViewCell.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/11/22.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface HomePageViewCollectionViewTableViewCell : UITableViewCell
@property (nonatomic, strong) UICollectionView* collectionView;

// 根据传入的数据来更新页面部分内容

@end

NS_ASSUME_NONNULL_END
