//
//  XCSearchView.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/12/5.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface XCSearchView : UIView
// 搜索页面
@property (nonatomic, strong) UISearchController* searchController;
// 假的输入框
@property (nonatomic, strong) UITextField* searchTexttfield;
@end

NS_ASSUME_NONNULL_END
