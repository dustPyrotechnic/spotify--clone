//
//  XCPersonalCollectionViewCell.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/22.
//

#import "XCPersonalCollectionViewCell.h"
#import <Masonry/Masonry.h>

@implementation XCPersonalCollectionViewCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _coverImageView = [[UIImageView alloc] init];
        _coverImageView.contentMode = UIViewContentModeScaleAspectFill;
        _coverImageView.layer.cornerRadius = 6;
        _coverImageView.layer.masksToBounds = YES;
        _coverImageView.backgroundColor = [UIColor systemGray5Color];
        [self.contentView addSubview:_coverImageView];

        _nameLabel = [[UILabel alloc] init];
        _nameLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
        _nameLabel.textColor = [UIColor labelColor];
        _nameLabel.numberOfLines = 2;
        [self.contentView addSubview:_nameLabel];

        [_coverImageView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.left.right.equalTo(self.contentView);
            make.height.equalTo(_coverImageView.mas_width);
        }];

        [_nameLabel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(_coverImageView.mas_bottom).offset(6);
            make.left.right.equalTo(self.contentView);
            make.bottom.lessThanOrEqualTo(self.contentView);
        }];
    }
    return self;
}

@end
