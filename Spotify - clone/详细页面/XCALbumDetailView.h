//
//  XCALbumDetailView.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/12/9.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface XCALbumDetailView : UIView
@property (nonatomic, strong) UIImageView* albumImageView;
@property (nonatomic, strong) UILabel* titleLabel;
@property (nonatomic, strong) UILabel* refreshDateLabel;

@property (nonatomic, strong) UIButton* playButton;
@property (nonatomic, strong) UIButton* randomButton;

@property (nonatomic, strong) UITableView* tableView;
@end

NS_ASSUME_NONNULL_END
