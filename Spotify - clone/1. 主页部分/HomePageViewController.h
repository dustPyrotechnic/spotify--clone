//
//  HomePageViewController.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/11/22.
//

#import <UIKit/UIKit.h>

#import "HomePageView.h"
#import "HomePageViewModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface HomePageViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, UICollectionViewDelegate, UICollectionViewDataSource, UIScrollViewDelegate, UICollectionViewDataSourcePrefetching>
///存储顶层的按钮数组
@property (nonatomic, strong) NSMutableArray* buttonArray;
@property (nonatomic, strong) HomePageView* mainView;
@property (nonatomic, strong) HomePageViewModel* model;
@end

NS_ASSUME_NONNULL_END
