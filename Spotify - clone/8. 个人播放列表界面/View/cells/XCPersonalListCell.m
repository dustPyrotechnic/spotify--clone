//
//  XCPersonalListCell.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/20.
//

#import "XCPersonalListCell.h"
#import <Masonry/Masonry.h>
#import <SDWebImage/SDWebImage.h>

#pragma mark - 常量
static const CGFloat kCoverSize = 60.0;
static const CGFloat kCoverCornerRadius = 4.0;
static const CGFloat kHorizontalPadding = 16.0;
static const CGFloat kHorizontalSpacing = 12.0;

@interface XCPersonalListCell ()
@property (nonatomic, strong, readwrite) UIImageView* coverImageView;
@property (nonatomic, strong, readwrite) UILabel* nameLabel;
@property (nonatomic, strong, readwrite) UILabel* subtitleLabel;
@property (nonatomic, strong, readwrite) UIImageView* arrowImageView;
@property (nonatomic, strong) UIView* separatorLine;
@end

@implementation XCPersonalListCell

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
    self.contentView.backgroundColor = [UIColor systemBackgroundColor];
    
    // 封面图片
    self.coverImageView = [[UIImageView alloc] init];
    self.coverImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.coverImageView.clipsToBounds = YES;
    self.coverImageView.layer.cornerRadius = kCoverCornerRadius;
    self.coverImageView.backgroundColor = [UIColor systemGray5Color];
    [self.contentView addSubview:self.coverImageView];
    
    // 名称标签
    self.nameLabel = [[UILabel alloc] init];
    self.nameLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    self.nameLabel.textColor = [UIColor labelColor];
    self.nameLabel.numberOfLines = 1;
    [self.contentView addSubview:self.nameLabel];
    
    // 副标题标签
    self.subtitleLabel = [[UILabel alloc] init];
    self.subtitleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    self.subtitleLabel.textColor = [UIColor secondaryLabelColor];
    self.subtitleLabel.numberOfLines = 1;
    [self.contentView addSubview:self.subtitleLabel];
    
    // 箭头图标
    self.arrowImageView = [[UIImageView alloc] init];
    self.arrowImageView.image = [UIImage systemImageNamed:@"chevron.right"];
    self.arrowImageView.tintColor = [UIColor tertiaryLabelColor];
    self.arrowImageView.contentMode = UIViewContentModeScaleAspectFit;
    [self.contentView addSubview:self.arrowImageView];
    
    // 分割线
    self.separatorLine = [[UIView alloc] init];
    self.separatorLine.backgroundColor = [UIColor separatorColor];
    [self.contentView addSubview:self.separatorLine];
    
    // 设置约束
    [self setupConstraints];
}

- (void)setupConstraints {
    // 封面图片
    [self.coverImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentView).offset(kHorizontalPadding);
        make.centerY.equalTo(self.contentView);
        make.width.height.mas_equalTo(kCoverSize);
    }];
    
    // 箭头图标
    [self.arrowImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.contentView).offset(-kHorizontalPadding);
        make.centerY.equalTo(self.contentView);
        make.width.height.mas_equalTo(20);
    }];
    
    // 名称标签
    [self.nameLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.coverImageView.mas_right).offset(kHorizontalSpacing);
        make.right.equalTo(self.arrowImageView.mas_left).offset(-kHorizontalSpacing);
        make.top.equalTo(self.contentView).offset(18);
    }];
    
    // 副标题标签
    [self.subtitleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.nameLabel);
        make.top.equalTo(self.nameLabel.mas_bottom).offset(4);
    }];
    
    // 分割线
    [self.separatorLine mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.nameLabel);
        make.right.bottom.equalTo(self.contentView);
        make.height.mas_equalTo(0.5);
    }];
}

#pragma mark - 配置方法
- (void)configureWithPlaylist:(XC_YYAlbumData*)playlist info:(nullable XCLocalPlaylistInfo*)info {
    // 设置名称
    self.nameLabel.text = playlist.name ?: @"未命名播放列表";
    
    // 设置副标题
    NSMutableString* subtitle = [NSMutableString string];
    if (info) {
        [subtitle appendString:info.songCountText];
        if (playlist.artistName && playlist.artistName.length > 0) {
            [subtitle appendFormat:@" · %@", playlist.artistName];
        }
    } else {
        [subtitle appendString:@"0首"];
    }
    self.subtitleLabel.text = subtitle;
    
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
        self.coverImageView.image = [UIImage systemImageNamed:@"music.note.list"];
        self.coverImageView.contentMode = UIViewContentModeCenter;
        self.coverImageView.backgroundColor = [UIColor systemGray5Color];
        self.coverImageView.tintColor = [UIColor systemGray3Color];
    }
    
    // 系统默认播放列表样式
    if (info && info.playlistType == XCPlaylistTypeSystem) {
        self.nameLabel.textColor = [UIColor systemGreenColor];
    } else {
        self.nameLabel.textColor = [UIColor labelColor];
    }
}

- (void)configurePlaceholder {
    self.nameLabel.text = @"加载中...";
    self.subtitleLabel.text = @"";
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
    self.subtitleLabel.text = nil;
    self.nameLabel.textColor = [UIColor labelColor];
}

#pragma mark - 高亮效果
- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    
    if (highlighted) {
        self.contentView.backgroundColor = [UIColor systemGray6Color];
    } else {
        self.contentView.backgroundColor = [UIColor systemBackgroundColor];
    }
}

@end
