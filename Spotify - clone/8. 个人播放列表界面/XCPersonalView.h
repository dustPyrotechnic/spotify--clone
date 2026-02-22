//
//  XCPersonalView.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/1.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface XCPersonalView : UIView

/// 列表模式
@property (nonatomic, strong) UITableView *tableView;
/// 封面 Grid 模式
@property (nonatomic, strong) UICollectionView *collectionView;

@end

NS_ASSUME_NONNULL_END
