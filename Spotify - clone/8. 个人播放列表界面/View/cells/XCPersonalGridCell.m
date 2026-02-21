//
//  XCPersonalGridCell.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/20.
//

#import "XCPersonalGridCell.h"
#import <Masonry/Masonry.h>
#import <SDWebImage/SDWebImage.h>

#pragma mark - 常量
static const CGFloat kCoverCornerRadius = 8.0;
static const CGFloat kLabelSpacing = 4.0;

@interface XCPersonalGridCell ()
@property (nonatomic, strong, readwrite) UIImageView* coverImageView;
@property (nonatomic, strong, readwrite) UILabel* nameLabel;
@property (nonatomic, strong, readwrite) UILabel* countLabel;
@end

@implementation XCPersonalGridCell

#pragma mark - 初始化
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupView];
    }
    return self;
}

#pragma mark - 视图设置
- (void)setupView {
    self.contentView.backgroundColor = [UIColor clearColor];
    
    // 封面图片
    self.coverImageView = [[UIImageView alloc] init];
    self.coverImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.coverImageView.clipsToBounds = YES;
    self.coverImageView.layer.cornerRadius = kCoverCornerRadius;
    self.coverImageView.backgroundColor = [UIColor systemGray5Color];
    
    // 添加占位图
    self.coverImageView.image = [UIImage systemImageNamed:@"music.note"];
    self.coverImageView.tintColor = [UIColor systemGray3Color];
    
    [self.contentView addSubview:self.coverImageView];
    
    // 名称标签
    self.nameLabel = [[UILabel alloc] init];
    self.nameLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    self.nameLabel.textColor = [UIColor labelColor];
    self.nameLabel.numberOfLines = 2;
    self.nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.contentView addSubview:self.nameLabel];
    
    // 歌曲数量标签
    self.countLabel = [[UILabel alloc] init];
    self.countLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    self.countLabel.textColor = [UIColor secondaryLabelColor];
    self.countLabel.numberOfLines = 1;
    [self.contentView addSubview:self.countLabel];
    
    // 设置约束
    [self setupConstraints];
}

- (void)setupConstraints {
    // 封面图片 - 正方形，顶部对齐
    [self.coverImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.right.equalTo(self.contentView);
        make.height.equalTo(self.coverImageView.mas_width);
    }];
    
    // 名称标签 - 封面下方
    [self.nameLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.coverImageView.mas_bottom).offset(kLabelSpacing + 4);
        make.left.right.equalTo(self.contentView);
    }];
    
    // 歌曲数量 - 名称下方
    [self.countLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.nameLabel.mas_bottom).offset(kLabelSpacing);
        make.left.right.equalTo(self.contentView);
        make.bottom.lessThanOrEqualTo(self.contentView);
    }];
}

#pragma mark - 配置方法
- (void)configureWithPlaylist:(XC_YYAlbumData*)playlist info:(nullable XCLocalPlaylistInfo*)info {
    // 设置名称
    self.nameLabel.text = playlist.name ?: @"未命名播放列表";
    
    // 设置歌曲数量
    if (info) {
        self.countLabel.text = info.songCountText;
    } else {
        self.countLabel.text = @"0首";
    }
    
    // 加载封面图片
    if (playlist.coverImgUrl && playlist.coverImgUrl.length > 0) {
        [self.coverImageView sd_setImageWithURL:[NSURL URLWithString:playlist.coverImgUrl]
                               placeholderImage:[UIImage systemImageNamed:@"music.note"]
                                        options:SDWebImageRetryFailed | SDWebImageLowPriority
                                      completed:^(UIImage * _Nullable image, NSError * _Nullable error, 
                                                 SDImageCacheType cacheType, NSURL * _Nullable imageURL) {
            if (image) {
                self.coverImageView.contentMode = UIViewContentModeScaleAspectFill;
            }
        }];
    } else {
        // 无封面，显示默认图标
        self.coverImageView.image = [UIImage systemImageNamed:@"music.note.list"];
        self.coverImageView.contentMode = UIViewContentModeCenter;
        self.coverImageView.backgroundColor = [UIColor systemGray5Color];
        self.coverImageView.tintColor = [UIColor systemGray3Color];
    }
    
    // 根据播放列表类型调整样式
    if (info && info.playlistType == XCPlaylistTypeSystem) {
        // 系统默认播放列表可以加特殊标记
        self.nameLabel.textColor = [UIColor systemGreenColor];
    } else {
        self.nameLabel.textColor = [UIColor labelColor];
    }
}

- (void)configurePlaceholder {
    self.nameLabel.text = @"加载中...";
    self.countLabel.text = @"";
    self.coverImageView.image = [UIImage systemImageNamed:@"music.note"];
    self.coverImageView.contentMode = UIViewContentModeCenter;
    self.coverImageView.backgroundColor = [UIColor systemGray5Color];
}

#pragma mark - 重用准备
- (void)prepareForReuse {
    [super prepareForReuse];
    
    // 取消图片加载
    [self.coverImageView sd_cancelCurrentImageLoad];
    
    // 重置状态
    self.coverImageView.image = nil;
    self.nameLabel.text = nil;
    self.countLabel.text = nil;
    self.nameLabel.textColor = [UIColor labelColor];
}

@end
