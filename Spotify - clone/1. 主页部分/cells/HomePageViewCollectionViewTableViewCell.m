//
//  HomePageViewCollectionViewTableViewCell.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/11/22.
//

#import "HomePageViewCollectionViewTableViewCell.h"

#import "HomePageViewCollectionViewCell.h"

@implementation HomePageViewCollectionViewTableViewCell

- (instancetype) initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // 改为横向滑动的collectionView
      UICollectionViewFlowLayout* layout = [[UICollectionViewFlowLayout alloc] init];
      layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
      layout.itemSize = CGSizeMake(180, 180);
      layout.minimumLineSpacing = 15;
      layout.sectionInset = UIEdgeInsetsMake(0, 15, 0, 15);
      self.collectionView = [[UICollectionView alloc] initWithFrame:self.bounds collectionViewLayout:layout];
      self.collectionView.backgroundColor = [UIColor systemBackgroundColor];
      // 设置不显示滚动条
      self.collectionView.showsHorizontalScrollIndicator = NO;
      self.collectionView.showsVerticalScrollIndicator = NO;
      // 设置不反弹
      self.collectionView.bounces = NO;
      // 注册cell
      [self.collectionView registerClass:[HomePageViewCollectionViewCell class] forCellWithReuseIdentifier:@"HomePageViewCollectionViewCell"];
      // 添加到视图
      [self.contentView addSubview:self.collectionView];
    }
    return self;
}
- (void) layoutSubviews {
  self.collectionView.frame = self.bounds;
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
