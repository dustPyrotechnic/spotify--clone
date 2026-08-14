//
//  XCSearchResultViewController.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/22.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface XCSearchResultViewController : UIViewController <UISearchResultsUpdating, UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *resultTableView;
@property (nonatomic, copy) NSString *searchQuery;

@end

NS_ASSUME_NONNULL_END
