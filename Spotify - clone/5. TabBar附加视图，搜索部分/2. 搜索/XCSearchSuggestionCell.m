//
//  XCSearchSuggestionCell.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/23.
//

#import "XCSearchSuggestionCell.h"
#import <Masonry/Masonry.h>

@interface XCSearchSuggestionCell ()
@property (nonatomic, strong, readwrite) UILabel *titleLabel;
@property (nonatomic, strong) UIImageView *iconImageView;
@property (nonatomic, strong) UIView *highlightedView;
@end

@implementation XCSearchSuggestionCell

#pragma mark - Lifecycle

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self setupViews];
        [self setupConstraints];
    }
    return self;
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
    
    // 图标
    self.iconImageView = [[UIImageView alloc] init];
    self.iconImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.iconImageView.tintColor = [UIColor secondaryLabelColor];
    
    // 标题
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    self.titleLabel.textColor = [UIColor labelColor];
    self.titleLabel.numberOfLines = 1;
    
    [self.contentView addSubview:self.highlightedView];
    [self.contentView addSubview:self.iconImageView];
    [self.contentView addSubview:self.titleLabel];
}

- (void)setupConstraints {
    // 高亮背景
    [self.highlightedView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.contentView).insets(UIEdgeInsetsMake(2, 16, 2, 16));
    }];
    
    // 图标
    [self.iconImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentView).offset(24);
        make.centerY.equalTo(self.contentView);
        make.width.height.mas_equalTo(22);
    }];
    
    // 标题
    [self.titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.iconImageView.mas_right).offset(14);
        make.right.equalTo(self.contentView).offset(-24);
        make.centerY.equalTo(self.contentView);
        make.height.mas_greaterThanOrEqualTo(22);
    }];
}

#pragma mark - Configure

- (void)configureWithText:(NSString *)text type:(XCSuggestionType)type {
    self.suggestionType = type;
    self.titleLabel.text = text ?: @"";
    
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightMedium];
    
    switch (type) {
        case XCSuggestionTypeRecent: {
            // 最近搜索 - 时钟图标
            self.iconImageView.image = [UIImage systemImageNamed:@"clock.arrow.circlepath" withConfiguration:config];
            self.iconImageView.tintColor = [UIColor secondaryLabelColor];
            break;
        }
        case XCSuggestionTypeSuggestion: {
            // 搜索建议 - 放大镜图标
            self.iconImageView.image = [UIImage systemImageNamed:@"magnifyingglass" withConfiguration:config];
            self.iconImageView.tintColor = [UIColor systemGreenColor];
            break;
        }
        case XCSuggestionTypeHot: {
            // 热门搜索 - 火焰图标
            self.iconImageView.image = [UIImage systemImageNamed:@"flame.fill" withConfiguration:config];
            self.iconImageView.tintColor = [UIColor systemOrangeColor];
            break;
        }
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
