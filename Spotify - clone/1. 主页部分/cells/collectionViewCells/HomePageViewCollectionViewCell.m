//
//  HomePageViewCollectionViewCell.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/11/22.
//

#import "HomePageViewCollectionViewCell.h"

#import <Masonry/Masonry.h>
#import <SDWebImage/SDWebImage.h>

@implementation HomePageViewCollectionViewCell
- (instancetype) initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
      //TODO: 完成布局
      // 测试代码
//      self.backgroundColor = [UIColor systemRedColor];
      self.backgroundColor = [UIColor clearColor];
      self.contentView.backgroundColor = [UIColor clearColor];
      UIImageSymbolConfiguration* size = [UIImageSymbolConfiguration configurationWithFont:[UIFont boldSystemFontOfSize:5]];
      UIImageSymbolConfiguration* conf = [UIImageSymbolConfiguration configurationPreferringMulticolor];
      UIImageSymbolConfiguration* final = [size configurationByApplyingConfiguration:conf];
      self.imageView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"arrow.down.circle.badge.xmark" withConfiguration:final]];
      self.imageView.contentMode = UIViewContentModeScaleAspectFill;
      self.imageView.layer.cornerRadius = 12.0;
      self.imageView.clipsToBounds = YES;
      // 增加阴影效果
      self.imageView.layer.shadowColor = [UIColor blackColor].CGColor;
      self.imageView.layer.shadowOffset = CGSizeMake(0, 2);
      self.imageView.layer.shadowOpacity = 0.2;
      self.imageView.layer.shadowRadius = 4.0;

      self.titleLable = [[UILabel alloc] init];
      self.titleLable.text = @"网络发生故障，请稍后重试";
      self.titleLable.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
      // 美化label
      self.titleLable.numberOfLines = 2;
      self.titleLable.textColor = [UIColor labelColor];
      self.titleLable.textAlignment = NSTextAlignmentLeft;

      [self.contentView addSubview:self.imageView];
      [self.contentView addSubview:self.titleLable];

      [self.imageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.contentView);
        make.left.equalTo(self.contentView);
        make.right.equalTo(self.contentView);
        make.height.equalTo(self.imageView.mas_width);
      }];

      [self.titleLable mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.imageView.mas_bottom).offset(8);
        make.left.equalTo(self.contentView);
        make.right.equalTo(self.contentView);
        make.bottom.lessThanOrEqualTo(self.contentView).offset(-4);
      }];
    }
    return self;
}
- (void) getDataAndLayout {
  NSURL* url = [NSURL URLWithString:self.data.imageURL];
  [self.imageView sd_setImageWithURL:url];
  [self.titleLable setText:self.data.nameAlbum];
}
@end
