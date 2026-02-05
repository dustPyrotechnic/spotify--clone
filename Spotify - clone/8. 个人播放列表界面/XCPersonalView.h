//
//  XCPersonalView.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/1.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface XCPersonalView : UIView
/// 显示个人播放列表
@property (nonatomic, strong) UITableView* tableView;
@end

NS_ASSUME_NONNULL_END
