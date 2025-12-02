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
      UIImageSymbolConfiguration* size = [UIImageSymbolConfiguration configurationWithFont:[UIFont boldSystemFontOfSize:5]];
      UIImageSymbolConfiguration* conf = [UIImageSymbolConfiguration configurationPreferringMulticolor];
      UIImageSymbolConfiguration* final = [size configurationByApplyingConfiguration:conf];
      self.imageView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"arrow.down.circle.badge.xmark" withConfiguration:final]];

      self.titleLable = [[UILabel alloc] init];
      self.titleLable.text = @"网络发生故障，请稍后重试";
      self.titleLable.font = [UIFont systemFontOfSize:20];

      [self.contentView addSubview:self.imageView];
      [self.contentView addSubview:self.titleLable];
      [self.imageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(self.contentView);
        make.top.equalTo(self.contentView);
        make.left.equalTo(self.contentView);
        make.height.equalTo(self.contentView).offset(-40);
      }];
      [self.titleLable mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(self.contentView);
        make.height.mas_equalTo(20);
        make.top.equalTo(self.imageView.mas_bottom).offset(10);
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
