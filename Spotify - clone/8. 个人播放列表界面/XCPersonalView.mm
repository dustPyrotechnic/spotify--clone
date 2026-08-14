//
//  XCPersonalView.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/1.
//

#import "XCPersonalView.h"
#import <Masonry/Masonry.h>

@implementation XCPersonalView

- (instancetype)init {
    self = [super init];
    if (self) {
        self.backgroundColor = [UIColor systemBackgroundColor];

        // 列表模式
        _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        _tableView.backgroundColor = [UIColor systemBackgroundColor];
        _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        [self addSubview:_tableView];

        // 封面 Grid 模式
        UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
        layout.minimumInteritemSpacing = 12;
        layout.minimumLineSpacing = 16;
        layout.sectionInset = UIEdgeInsetsMake(16, 16, 16, 16);
        _collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero
                                             collectionViewLayout:layout];
        _collectionView.backgroundColor = [UIColor systemBackgroundColor];
        _collectionView.alpha = 0;
        [self addSubview:_collectionView];

        [_tableView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self);
        }];

        [_collectionView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self);
        }];
    }
    return self;
}

@end
