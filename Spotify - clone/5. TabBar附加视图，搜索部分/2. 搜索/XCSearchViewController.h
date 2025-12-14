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

@interface XCSearchViewController : UIViewController
@property (nonatomic, strong) XCSearchView* mainView;
@property (nonatomic, strong) XCSearchModel* model;
@end

NS_ASSUME_NONNULL_END
