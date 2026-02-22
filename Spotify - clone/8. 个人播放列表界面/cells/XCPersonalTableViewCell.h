//
//  XCPersonalTableViewCell.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/3.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface XCPersonalTableViewCell : UITableViewCell

@property (nonatomic, strong) UIImageView *mainImageView;
@property (nonatomic, strong) UILabel *titleLabel;
/// 副标题：「歌单 · N 首歌」，13pt，secondaryLabel 颜色
@property (nonatomic, strong) UILabel *subtitleLabel;

@end

NS_ASSUME_NONNULL_END
