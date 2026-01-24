//
//  XCAlbumHeadCell.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/12/21.
//

#import "XCAlbumHeadCell.h"

#import <Masonry/Masonry.h>

@implementation XCAlbumHeadCell

- (instancetype) initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
  self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
  if (self) {
    self.backgroundColor = [UIColor systemBackgroundColor];

    // 初始化专辑封面
    self.albumImageView = [[UIImageView alloc] init];
    self.albumImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.albumImageView.clipsToBounds = YES;
    self.albumImageView.layer.cornerRadius = 12;
    self.albumImageView.backgroundColor = [UIColor systemGray5Color];

    // 初始化标题标签
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = @"专辑标题";
    self.titleLabel.font = [UIFont boldSystemFontOfSize:24];
    self.titleLabel.textColor = [UIColor labelColor];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.numberOfLines = 2;

    // 初始化更新时间标签
    self.refreshDateLabel = [[UILabel alloc] init];
    self.refreshDateLabel.text = @"1周前更新";
    self.refreshDateLabel.font = [UIFont systemFontOfSize:14];
    self.refreshDateLabel.textColor = [UIColor secondaryLabelColor];
    self.refreshDateLabel.textAlignment = NSTextAlignmentCenter;
    self.refreshDateLabel.numberOfLines = 1;

    // 初始化播放按钮
    UIAction* playAction = [UIAction actionWithTitle:@"播放" image:[UIImage systemImageNamed:@"play.fill"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
      NSLog(@"播放该列表");
    }];
    self.playButton = [UIButton buttonWithConfiguration:[UIButtonConfiguration filledButtonConfiguration] primaryAction:playAction];
    self.playButton.configuration.baseBackgroundColor = [UIColor systemGreenColor];
    self.playButton.configuration.baseForegroundColor = [UIColor whiteColor];
    NSMutableAttributedString *playAttributedTitle = [[NSMutableAttributedString alloc] initWithString:@"播放"];
    [playAttributedTitle addAttribute:NSFontAttributeName
                                value:[UIFont boldSystemFontOfSize:18]
                                range:NSMakeRange(0, playAttributedTitle.length)];
    self.playButton.configuration.attributedTitle = playAttributedTitle;

    self.playButton.configuration.image = [UIImage systemImageNamed:@"play.fill"];
    self.playButton.configuration.imagePlacement = NSDirectionalRectEdgeLeading;
    self.playButton.configuration.imagePadding = 8;
    self.playButton.layer.cornerRadius = 25;
    self.playButton.clipsToBounds = YES;
    self.playButton.tintColor = [UIColor systemGreenColor];

    // 初始化随机播放按钮
    UIAction* randomAction = [UIAction actionWithTitle:@"随机播放" image:[UIImage systemImageNamed:@"shuffle"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
      NSLog(@"随机播放该列表");
    }];
    self.randomButton = [UIButton buttonWithConfiguration:[UIButtonConfiguration filledButtonConfiguration] primaryAction:randomAction];
    self.randomButton.configuration.baseBackgroundColor = [UIColor systemGreenColor];
    self.randomButton.configuration.baseForegroundColor = [UIColor whiteColor];
    NSMutableAttributedString *randomAttributedTitle = [[NSMutableAttributedString alloc] initWithString:@"随机播放"];
    [randomAttributedTitle addAttribute:NSFontAttributeName
                                  value:[UIFont boldSystemFontOfSize:18]
                                  range:NSMakeRange(0, randomAttributedTitle.length)];
    self.randomButton.configuration.attributedTitle = randomAttributedTitle;
    self.randomButton.configuration.image = [UIImage systemImageNamed:@"shuffle"];
    self.randomButton.configuration.imagePlacement = NSDirectionalRectEdgeLeading;
    self.randomButton.configuration.imagePadding = 8;
    self.randomButton.layer.cornerRadius = 25;
    self.randomButton.clipsToBounds = YES;
    self.randomButton.tintColor = [UIColor systemGreenColor];

    // 添加子视图
    [self addSubview:self.albumImageView];
    [self addSubview:self.titleLabel];
    [self addSubview:self.refreshDateLabel];
    [self addSubview:self.playButton];
    [self addSubview:self.randomButton];

    // 设置约束
    [self setupConstraints];
  }
  return self;
}
- (void) layoutSubviews {
  [self setupConstraints];
}
- (void) setupConstraints {
  // 专辑封面约束 - 顶部中央
  [self.albumImageView mas_makeConstraints:^(MASConstraintMaker *make) {
    make.top.equalTo(self.mas_safeAreaLayoutGuideTop).offset(20);
    make.centerX.equalTo(self);
    make.width.equalTo(self).multipliedBy(0.65);
    make.height.equalTo(self.albumImageView.mas_width);
  }];

  // 标题标签约束 - 封面下方，竖直排列
  [self.titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
    make.top.equalTo(self.albumImageView.mas_bottom).offset(24);
    make.left.equalTo(self).offset(20);
    make.right.equalTo(self).offset(-20);
    make.centerX.equalTo(self);
  }];

  // 更新时间标签约束 - 标题下方
  [self.refreshDateLabel mas_makeConstraints:^(MASConstraintMaker *make) {
    make.top.equalTo(self.titleLabel.mas_bottom).offset(8);
    make.left.equalTo(self).offset(20);
    make.right.equalTo(self).offset(-20);
    make.centerX.equalTo(self);
  }];

  // 播放按钮约束 - 更新时间下方，左侧
  [self.playButton mas_makeConstraints:^(MASConstraintMaker *make) {
    make.top.equalTo(self.refreshDateLabel.mas_bottom).offset(24);
    make.left.equalTo(self).offset(20);
    make.right.equalTo(self.mas_centerX).offset(-8);
    make.height.mas_equalTo(50);
  }];

  // 随机播放按钮约束 - 更新时间下方，右侧，与播放按钮并排
  [self.randomButton mas_makeConstraints:^(MASConstraintMaker *make) {
    make.top.equalTo(self.refreshDateLabel.mas_bottom).offset(24);
    make.left.equalTo(self.mas_centerX).offset(8);
    make.right.equalTo(self).offset(-20);
    make.height.mas_equalTo(50);
  }];
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
