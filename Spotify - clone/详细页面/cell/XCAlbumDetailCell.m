//
//  XCAlbumDetailCell.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/12/11.
//

#import "XCAlbumDetailCell.h"

#import "Masonry/Masonry.h"

@implementation XCAlbumDetailCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
  self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
  if (self) {
    [self setupViews];
    [self setupConstraints];
  }
  return self;
}

- (void)setupViews {
  self.selectionStyle = UITableViewCellSelectionStyleNone;
  self.backgroundColor = [UIColor clearColor];
  self.contentView.backgroundColor = [UIColor systemBackgroundColor];
  
  self.mainImageView = [[UIImageView alloc] init];
  self.mainImageView.contentMode = UIViewContentModeScaleAspectFill;
  self.mainImageView.layer.cornerRadius = 6.0;
  self.mainImageView.layer.masksToBounds = YES;
  
  self.songLabel = [[UILabel alloc] init];
  self.songLabel.font = [UIFont boldSystemFontOfSize:16.0];
  self.songLabel.textColor = [UIColor labelColor];
  self.songLabel.numberOfLines = 1;
  
  self.authorLabel = [[UILabel alloc] init];
  self.authorLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightRegular];
  self.authorLabel.textColor = [UIColor secondaryLabelColor];
  self.authorLabel.numberOfLines = 1;
  
  self.menuButton = [UIButton buttonWithType:UIButtonTypeSystem];
  UIImageSymbolConfiguration *symbolConfig = [UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightRegular];
  UIImage *menuImage = [UIImage systemImageNamed:@"ellipsis" withConfiguration:symbolConfig];
  [self.menuButton setImage:menuImage forState:UIControlStateNormal];
  self.menuButton.tintColor = [UIColor tertiaryLabelColor];
//  self.menuButton.contentEdgeInsets = UIEdgeInsetsMake(6, 6, 6, 6);
//  self.menuButton.showsTouchWhenHighlighted = YES;
  
  [self.contentView addSubview:self.mainImageView];
  [self.contentView addSubview:self.songLabel];
  [self.contentView addSubview:self.authorLabel];
  [self.contentView addSubview:self.menuButton];
  [self setupConstraints];
}

- (void)setupConstraints {
  // 封面图
  [self.mainImageView mas_makeConstraints:^(MASConstraintMaker *make) {
    make.left.equalTo(self.contentView).offset(16);
    make.centerY.equalTo(self.contentView);
    make.width.height.mas_equalTo(48);
    make.top.greaterThanOrEqualTo(self.contentView).offset(10);
    make.bottom.lessThanOrEqualTo(self.contentView).offset(-10);
  }];
  
  // 右侧菜单
  [self.menuButton mas_makeConstraints:^(MASConstraintMaker *make) {
    make.centerY.equalTo(self.contentView);
    make.right.equalTo(self.contentView).offset(-16);
    make.width.height.mas_equalTo(32);
  }];
  
  // 歌曲名称
  [self.songLabel mas_makeConstraints:^(MASConstraintMaker *make) {
    make.top.equalTo(self.contentView).offset(12);
    make.left.equalTo(self.mainImageView.mas_right).offset(12);
    make.right.lessThanOrEqualTo(self.menuButton.mas_left).offset(-12);
  }];
  
  // 作者
  [self.authorLabel mas_makeConstraints:^(MASConstraintMaker *make) {
    make.top.equalTo(self.songLabel.mas_bottom).offset(4);
    make.left.equalTo(self.songLabel);
    make.right.lessThanOrEqualTo(self.menuButton.mas_left).offset(-12);
    make.bottom.lessThanOrEqualTo(self.contentView).offset(-12);
  }];
}


@end
