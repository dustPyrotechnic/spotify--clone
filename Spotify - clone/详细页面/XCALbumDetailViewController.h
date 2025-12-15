//
//  XCALbumDetailViewController.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/12/9.
//

#import <UIKit/UIKit.h>

#import "XCALbumDetailView.h"
#import "XCALbumDetailModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface XCALbumDetailViewController : UIViewController
@property (nonatomic, strong) XCALbumDetailView* mainView;
@property (nonatomic, strong) XCALbumDetailModel* model;
@end

NS_ASSUME_NONNULL_END
