//
//  XCSearchResultCell.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/23.
//

#import "XCSearchResultCell.h"
#import <Masonry/Masonry.h>
#import <SDWebImage/SDWebImage.h>
#import "XC-YYSongData.h"
#import "XC-YYAlbumData.h"

@interface XCSearchResultCell ()
@property (nonatomic, strong, readwrite) UIImageView *coverImageView;
@property (nonatomic, strong, readwrite) UILabel *titleLabel;
@property (nonatomic, strong, readwrite) UILabel *subtitleLabel;
@property (nonatomic, strong, readwrite) UIButton *actionButton;
@property (nonatomic, strong, readwrite, nullable) XC_YYSongData *songData;
@property (nonatomic, strong) UIView *highlightedView;
@property (nonatomic, copy, nullable) UIMenu *(^menuProvider)(XC_YYSongData *song);
@end

@implementation XCSearchResultCell

#pragma mark - Lifecycle

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self setupViews];
        [self setupConstraints];
    }
    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    // 取消进行中的图片加载，避免 Cell 复用时显示旧图片
    [self.coverImageView sd_cancelCurrentImageLoad];
    self.coverImageView.image = nil;
    self.titleLabel.text = nil;
    self.subtitleLabel.text = nil;
}

#pragma mark - Setup

- (void)setupViews {
    // 选中样式
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.backgroundColor = [UIColor clearColor];
    self.contentView.backgroundColor = [UIColor systemBackgroundColor];
    
    // 高亮背景视图
    self.highlightedView = [[UIView alloc] init];
    self.highlightedView.backgroundColor = [UIColor tertiarySystemFillColor];
    self.highlightedView.layer.cornerRadius = 8;
    self.highlightedView.alpha = 0;
    [self.contentView insertSubview:self.highlightedView atIndex:0];
    
    // 封面图片
    self.coverImageView = [[UIImageView alloc] init];
    self.coverImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.coverImageView.layer.cornerRadius = 6.0;
    self.coverImageView.layer.masksToBounds = YES;
    self.coverImageView.backgroundColor = [UIColor secondarySystemBackgroundColor];
    
    // 主标题
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    self.titleLabel.textColor = [UIColor labelColor];
    self.titleLabel.numberOfLines = 1;
    
    // 副标题
    self.subtitleLabel = [[UILabel alloc] init];
    self.subtitleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    self.subtitleLabel.textColor = [UIColor secondaryLabelColor];
    self.subtitleLabel.numberOfLines = 1;
    
    // 操作按钮
    self.actionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *symbolConfig = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightMedium];
    UIImage *menuImage = [UIImage systemImageNamed:@"ellipsis.circle.fill" withConfiguration:symbolConfig];
    [self.actionButton setImage:menuImage forState:UIControlStateNormal];
    self.actionButton.tintColor = [UIColor tertiaryLabelColor];
    self.actionButton.alpha = 0.8;
    
    [self.contentView addSubview:self.highlightedView];
    [self.contentView addSubview:self.coverImageView];
    [self.contentView addSubview:self.titleLabel];
    [self.contentView addSubview:self.subtitleLabel];
    [self.contentView addSubview:self.actionButton];
}

- (void)setupConstraints {
    // 高亮背景
    [self.highlightedView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.contentView).insets(UIEdgeInsetsMake(4, 12, 4, 12));
    }];
    
    // 封面图片 - 根据类型设置不同的圆角和尺寸
    [self.coverImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentView).offset(20);
        make.centerY.equalTo(self.contentView);
        make.width.height.mas_equalTo(52);
        make.top.greaterThanOrEqualTo(self.contentView).offset(10);
        make.bottom.lessThanOrEqualTo(self.contentView).offset(-10);
    }];
    
    // 操作按钮
    [self.actionButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self.contentView);
        make.right.equalTo(self.contentView).offset(-16);
        make.width.height.mas_equalTo(44);
    }];
    
    // 主标题
    [self.titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.contentView).offset(14);
        make.left.equalTo(self.coverImageView.mas_right).offset(14);
        make.right.lessThanOrEqualTo(self.actionButton.mas_left).offset(-8);
    }];
    
    // 副标题
    [self.subtitleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.titleLabel.mas_bottom).offset(5);
        make.left.equalTo(self.titleLabel);
        make.right.lessThanOrEqualTo(self.actionButton.mas_left).offset(-8);
        make.bottom.lessThanOrEqualTo(self.contentView).offset(-14);
    }];
}

#pragma mark - Configure

- (void)setResultType:(XCSearchResultType)resultType {
    _resultType = resultType;
    
    // 根据类型设置不同的圆角和图标
    switch (resultType) {
        case XCSearchResultTypeSong:
            self.coverImageView.layer.cornerRadius = 6;
            break;
        case XCSearchResultTypeAlbum:
            self.coverImageView.layer.cornerRadius = 4;
            break;
        case XCSearchResultTypeArtist:
            self.coverImageView.layer.cornerRadius = 26; // 圆形
            break;
    }
}

- (void)configureWithSong:(XC_YYSongData *)song {
    self.resultType = XCSearchResultTypeSong;
    self.songData = song;
    
    // 标题
    self.titleLabel.text = song.name ?: @"未知歌曲";
    
    // 副标题：艺人 - 专辑
    NSString *artist = song.artist ?: @"未知艺人";
    self.subtitleLabel.text = artist;
    
    // 封面图
    NSString *imageUrl = [song.mainIma isKindOfClass:[NSString class]] ? song.mainIma : nil;
    [self loadImageWithURL:imageUrl placeholder:@"music.note"];
    
    // 更新菜单（如果已配置）
    [self updateMenu];
}

- (void)configureWithAlbum:(XC_YYAlbumData *)album {
    self.resultType = XCSearchResultTypeAlbum;
    
    // 标题
    self.titleLabel.text = album.name ?: @"未知专辑";
    
    // 副标题：艺人
    NSString *artist = album.artistName ?: @"未知艺人";
    self.subtitleLabel.text = [NSString stringWithFormat:@"专辑 · %@", artist];
    
    // 封面图
    NSString *imageUrl = [album.coverImgUrl isKindOfClass:[NSString class]] ? album.coverImgUrl : nil;
    [self loadImageWithURL:imageUrl placeholder:@"rectangle.stack"];
}

- (void)configureWithArtist:(NSDictionary *)artist {
    self.resultType = XCSearchResultTypeArtist;
    
    // 标题
    self.titleLabel.text = artist[@"name"] ?: @"未知艺人";
    
    // 副标题
    self.subtitleLabel.text = @"艺人";
    
    // 封面图
    id rawPicUrl = artist[@"picUrl"] ?: artist[@"img1v1Url"];
    NSString *picUrl = [rawPicUrl isKindOfClass:[NSString class]] ? rawPicUrl : nil;
    [self loadImageWithURL:picUrl placeholder:@"person.circle.fill"];
}

- (void)loadImageWithURL:(NSString *)urlString placeholder:(NSString *)placeholderName {
    NSURL *url = urlString.length > 0 ? [NSURL URLWithString:urlString] : nil;
    UIImage *placeholder = [UIImage systemImageNamed:placeholderName];
    
    [self.coverImageView sd_setImageWithURL:url
                           placeholderImage:placeholder
                                    options:SDWebImageRetryFailed | SDWebImageLowPriority
                                  completed:nil];
}

#pragma mark - Menu

- (void)configureActionMenuWithProvider:(UIMenu *(^)(XC_YYSongData *song))menuProvider {
    self.menuProvider = menuProvider;
    [self updateMenu];
}

- (void)updateMenu {
    if (self.menuProvider && self.songData && self.resultType == XCSearchResultTypeSong) {
        UIMenu *menu = self.menuProvider(self.songData);
        self.actionButton.menu = menu;
        self.actionButton.showsMenuAsPrimaryAction = YES;
    } else {
        self.actionButton.menu = nil;
        self.actionButton.showsMenuAsPrimaryAction = NO;
    }
}

#pragma mark - Highlight

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:highlighted animated:animated];
    
    [UIView animateWithDuration:animated ? 0.15 : 0 animations:^{
        self.highlightedView.alpha = highlighted ? 1.0 : 0.0;
    }];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
    
    [UIView animateWithDuration:animated ? 0.15 : 0 animations:^{
        self.highlightedView.alpha = selected ? 1.0 : 0.0;
    } completion:^(BOOL finished) {
        if (selected) {
            [UIView animateWithDuration:0.15 animations:^{
                self.highlightedView.alpha = 0.0;
            }];
        }
    }];
}

@end
