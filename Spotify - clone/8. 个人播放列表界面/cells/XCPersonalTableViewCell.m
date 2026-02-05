//
//  XCPersonalTableViewCell.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/3.
//

#import "XCPersonalTableViewCell.h"
#import <Masonry/Masonry.h>

@implementation XCPersonalTableViewCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
  self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
  if (self) {
//    self.backgroundColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0];
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    _mainImageView = [[UIImageView alloc] init];
    _mainImageView.contentMode = UIViewContentModeScaleAspectFill;
    _mainImageView.layer.cornerRadius = 4;
    _mainImageView.layer.masksToBounds = YES;
    _mainImageView.backgroundColor = [UIColor darkGrayColor]; // 占位色
    [self.contentView addSubview:_mainImageView];
    _titleLabel = [[UILabel alloc] init];
    _titleLabel.font = [UIFont systemFontOfSize:24 weight:UIFontWeightMedium];
    _titleLabel.textColor = [UIColor labelColor];
    [self.contentView addSubview:_titleLabel];

    [_mainImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentView).offset(16);
        make.centerY.equalTo(self.contentView);
        make.height.equalTo(self.contentView).multipliedBy(0.75); // 稍微留白
        make.width.equalTo(_mainImageView.mas_height);
    }];

    [_titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(_mainImageView.mas_right).offset(16);
        make.right.equalTo(self.contentView).offset(-16);
        make.centerY.equalTo(self.contentView);
    }];
  }
  return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

@end
