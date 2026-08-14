//
//  XCPersonalViewController.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/1.
//

#import <UIKit/UIKit.h>

#import "XCPersonalModel.h"
#import "XCPersonalView.h"

#import "XCPersonalTableViewCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface XCPersonalViewController : UIViewController <UITableViewDelegate,UITableViewDataSource>
/// 存储数据的模型
@property (nonatomic,strong) XCPersonalModel* model;
/// 主视图
@property (nonatomic,strong) XCPersonalView* mainView;
@end

NS_ASSUME_NONNULL_END
