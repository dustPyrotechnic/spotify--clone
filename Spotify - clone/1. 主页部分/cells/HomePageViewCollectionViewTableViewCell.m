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
      // 专辑卡片略小一些，留出左右留白；高度稍微加大，给两行标题预留空间
      layout.itemSize = CGSizeMake(170, 230);
      layout.minimumLineSpacing = 12;
      layout.sectionInset = UIEdgeInsetsMake(0, 16, 0, 16);
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
