//
//  XCSearchViewController.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/12/5.
//

#import <UIKit/UIKit.h>

#import "XCSearchView.h"
#import "XCSearchModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface XCSearchViewController : UIViewController <UISearchResultsUpdating>
@property (nonatomic, strong) XCSearchView* mainView;
@property (nonatomic, strong) XCSearchModel* model;

// 搜索页面
@property (nonatomic, strong) UISearchController* searchController;
@end

NS_ASSUME_NONNULL_END
