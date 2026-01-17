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
      self.titleLable.text = @"Network error, retry";
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
        make.top.equalTo(self.imageView.mas_bottom).offset(5);
        make.left.equalTo(self.contentView);
        make.right.equalTo(self.contentView);
        make.bottom.equalTo(self.contentView).offset (10);
      }];
    }
    return self;
}
- (void)prepareForReuse {
  [super prepareForReuse];
  // 重置内容，避免复用导致的闪动
  self.imageView.image = nil;
  self.titleLable.text = @"";
}
- (void) getDataAndLayout {
  // 为当前加载生成唯一标识
  
  self.titleLable.text = self.data.name ?: @"";
  self.imageView.image = nil;
  
  NSURL* url = [NSURL URLWithString:self.data.coverImgUrl];
  [self.imageView sd_setImageWithURL:url
                    placeholderImage:nil
                             options:SDWebImageRetryFailed | SDWebImageLowPriority
                           completed:^(UIImage * _Nullable image, NSError * _Nullable error, SDImageCacheType cacheType, NSURL * _Nullable imageURL) {
    if (image) {
      self.imageView.image = image;
    }
  }];
}
@end
