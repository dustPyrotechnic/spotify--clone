//
//  XCSongCommentCell.m
//  Spotify - clone
//
//  Created by Kimi on 2026/03/03.
//

#import "XCSongCommentCell.h"
#import <Masonry/Masonry.h>
#import <SDWebImage/SDWebImage.h>

@interface XCSongCommentCell ()

// UI 组件
@property (nonatomic, strong) UIImageView *avatarImageView;
@property (nonatomic, strong) UILabel *nicknameLabel;
@property (nonatomic, strong) UILabel *contentLabel;
@property (nonatomic, strong) UIButton *expandButton;
@property (nonatomic, strong) UIView *replyBoxView;
@property (nonatomic, strong) UILabel *replyLabel;
@property (nonatomic, strong) UIButton *viewRepliesButton;
@property (nonatomic, strong) UIButton *likeButton;
@property (nonatomic, strong) UILabel *timeLabel;

// 动态约束引用（用于显示/隐藏时折叠空间）
@property (nonatomic, strong) MASConstraint *expandButtonTopOffset;
@property (nonatomic, strong) MASConstraint *expandButtonHeight;
@property (nonatomic, strong) MASConstraint *replyBoxTopOffset;
@property (nonatomic, strong) MASConstraint *replyBoxHeight;
@property (nonatomic, strong) MASConstraint *viewRepliesTopOffset;
@property (nonatomic, strong) MASConstraint *viewRepliesHeight;

@end

@implementation XCSongCommentCell

+ (NSString *)reuseIdentifier {
    return @"XCSongCommentCell";
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.backgroundColor = [UIColor clearColor];
    
    // 头像
    self.avatarImageView = [[UIImageView alloc] init];
    self.avatarImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.avatarImageView.clipsToBounds = YES;
    self.avatarImageView.layer.cornerRadius = 16;
    self.avatarImageView.backgroundColor = [UIColor systemGray5Color];
    [self.contentView addSubview:self.avatarImageView];
    
    // 昵称
    self.nicknameLabel = [[UILabel alloc] init];
    self.nicknameLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    self.nicknameLabel.textColor = [UIColor colorWithWhite:0.9 alpha:1.0];
    [self.contentView addSubview:self.nicknameLabel];
    
    // 内容
    self.contentLabel = [[UILabel alloc] init];
    self.contentLabel.font = [UIFont systemFontOfSize:14];
    self.contentLabel.textColor = [UIColor colorWithWhite:0.85 alpha:1.0];
    self.contentLabel.numberOfLines = 0;
    self.contentLabel.lineBreakMode = NSLineBreakByWordWrapping;
    [self.contentView addSubview:self.contentLabel];
    
    // 展开/收起按钮
    self.expandButton = [[UIButton alloc] init];
    self.expandButton.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    [self.expandButton setTitleColor:[UIColor systemGreenColor] forState:UIControlStateNormal];
    [self.expandButton addTarget:self action:@selector(tapExpand) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.expandButton];
    
    // 回复引用框
    self.replyBoxView = [[UIView alloc] init];
    self.replyBoxView.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.5];
    self.replyBoxView.layer.cornerRadius = 6;
    [self.contentView addSubview:self.replyBoxView];
    
    self.replyLabel = [[UILabel alloc] init];
    self.replyLabel.font = [UIFont systemFontOfSize:12];
    self.replyLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
    self.replyLabel.numberOfLines = 2;
    [self.replyBoxView addSubview:self.replyLabel];
    
    // 查看回复按钮
    self.viewRepliesButton = [[UIButton alloc] init];
    self.viewRepliesButton.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    [self.viewRepliesButton setTitleColor:[UIColor systemGreenColor] forState:UIControlStateNormal];
    [self.viewRepliesButton addTarget:self action:@selector(tapViewReplies) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.viewRepliesButton];
    
    // 点赞按钮
    self.likeButton = [[UIButton alloc] init];
    self.likeButton.titleLabel.font = [UIFont systemFontOfSize:12];
    [self.likeButton setTitleColor:[UIColor colorWithWhite:0.6 alpha:1.0] forState:UIControlStateNormal];
    [self.likeButton setImage:[UIImage systemImageNamed:@"heart"] forState:UIControlStateNormal];
    [self.likeButton setImage:[UIImage systemImageNamed:@"heart.fill"] forState:UIControlStateSelected];
    [self.likeButton addTarget:self action:@selector(tapLike) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.likeButton];
    
    // 时间标签
    self.timeLabel = [[UILabel alloc] init];
    self.timeLabel.font = [UIFont systemFontOfSize:11];
    self.timeLabel.textColor = [UIColor colorWithWhite:0.5 alpha:1.0];
    [self.contentView addSubview:self.timeLabel];
    
    // 布局
    [self setupConstraints];
}

- (void)setupConstraints {
    // 头像
    [self.avatarImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentView).offset(16);
        make.top.equalTo(self.contentView).offset(12);
        make.width.height.mas_equalTo(32);
    }];

    // 昵称
    [self.nicknameLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.avatarImageView.mas_right).offset(10);
        make.top.equalTo(self.avatarImageView);
        make.right.equalTo(self.contentView).offset(-16);
        make.height.mas_equalTo(18);
    }];

    // 内容（numberOfLines=0，高度由文本决定）
    [self.contentLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.nicknameLabel);
        make.top.equalTo(self.nicknameLabel.mas_bottom).offset(4);
        make.right.equalTo(self.contentView).offset(-16);
    }];

    // 展开按钮 - 初始高度 0，有长评论时动态展开
    [self.expandButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentLabel);
        self.expandButtonTopOffset = make.top.equalTo(self.contentLabel.mas_bottom).offset(0);
        self.expandButtonHeight = make.height.mas_equalTo(0);
    }];

    // 回复引用框 - 初始高度 0，有引用时动态展开
    self.replyBoxView.clipsToBounds = YES;
    [self.replyBoxView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentLabel);
        make.right.equalTo(self.contentView).offset(-16);
        self.replyBoxTopOffset = make.top.equalTo(self.expandButton.mas_bottom).offset(0);
        self.replyBoxHeight = make.height.mas_equalTo(0);
    }];

    // replyLabel 只约束上/左/右，由 clipsToBounds 处理溢出
    [self.replyLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.right.equalTo(self.replyBoxView).insets(UIEdgeInsetsMake(8, 10, 0, 10));
    }];

    // 查看回复按钮 - 初始高度 0，有回复时动态展开
    [self.viewRepliesButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentLabel);
        self.viewRepliesTopOffset = make.top.equalTo(self.replyBoxView.mas_bottom).offset(0);
        self.viewRepliesHeight = make.height.mas_equalTo(0);
    }];

    // 点赞按钮 - top 连接链式布局，bottom 锚定 contentView（形成完整约束链）
    [self.likeButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.contentView).offset(-16);
        make.top.equalTo(self.viewRepliesButton.mas_bottom).offset(8);
        make.bottom.equalTo(self.contentView).offset(-12);
    }];

    // 时间标签
    [self.timeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentLabel);
        make.centerY.equalTo(self.likeButton);
    }];
}

#pragma mark - Data Binding

- (void)setComment:(XCSongComment *)comment {
    _comment = comment;
    
    // 头像
    [self.avatarImageView sd_setImageWithURL:[NSURL URLWithString:comment.avatarUrl]
                            placeholderImage:[UIImage systemImageNamed:@"person.circle"]];
    
    // 昵称
    self.nicknameLabel.text = comment.nickname ?: @"未知用户";
    
    // 内容（处理长评论）
    [self updateContentDisplay];
    
    // 点赞
    self.likeButton.selected = comment.isLiked;
    [self.likeButton setTitle:[self formatCount:comment.likedCount] forState:UIControlStateNormal];

    // 时间
    self.timeLabel.text = [self formatTime:comment.timestamp];

    // 更新回复框、回复按钮的动态约束
    [self updateDynamicConstraints];
}

- (void)updateContentDisplay {
    if (!self.comment) return;

    BOOL showExpand = self.comment.isLongComment;

    if (self.comment.isLongComment && !self.comment.isExpanded) {
        // 折叠状态：限制 3 行，Auto Layout 会计算对应高度
        self.contentLabel.numberOfLines = 3;
        self.contentLabel.text = self.comment.content;
        self.expandButton.hidden = NO;
        [self.expandButton setTitle:@"展开 ▼" forState:UIControlStateNormal];
    } else {
        // 展开或短评论：不限行数
        self.contentLabel.numberOfLines = 0;
        self.contentLabel.text = self.comment.content;
        if (self.comment.isLongComment) {
            self.expandButton.hidden = NO;
            [self.expandButton setTitle:@"收起 ▲" forState:UIControlStateNormal];
        } else {
            self.expandButton.hidden = YES;
        }
    }

    // 同步展开按钮的约束空间
    [self.expandButtonTopOffset setOffset:showExpand ? 4 : 0];
    [self.expandButtonHeight setOffset:showExpand ? 20 : 0];
}

/// 根据 comment 数据更新回复框和查看回复按钮的动态约束
- (void)updateDynamicConstraints {
    if (!self.comment) return;

    // 回复引用框
    BOOL hasReply = (self.comment.replyToComment != nil);
    self.replyBoxView.hidden = !hasReply;
    [self.replyBoxTopOffset setOffset:hasReply ? 8 : 0];
    [self.replyBoxHeight setOffset:hasReply ? 44 : 0];
    if (hasReply) {
        self.replyLabel.text = [NSString stringWithFormat:@"@%@: %@",
                                self.comment.replyToComment.nickname ?: @"",
                                self.comment.replyToComment.content ?: @""];
    }

    // 查看回复按钮
    BOOL hasReplies = (self.comment.replyCount > 0);
    self.viewRepliesButton.hidden = !hasReplies;
    [self.viewRepliesTopOffset setOffset:hasReplies ? 8 : 0];
    [self.viewRepliesHeight setOffset:hasReplies ? 24 : 0];
    if (hasReplies) {
        [self.viewRepliesButton setTitle:[NSString stringWithFormat:@"查看 %ld 条回复 >", (long)self.comment.replyCount]
                                forState:UIControlStateNormal];
    }
}

#pragma mark - Public

- (void)refreshContentDisplay {
    [self updateContentDisplay];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    [self.avatarImageView sd_cancelCurrentImageLoad];
    // 重置所有动态约束为折叠状态，防止复用时出现残留尺寸
    [self.expandButtonTopOffset setOffset:0];
    [self.expandButtonHeight setOffset:0];
    [self.replyBoxTopOffset setOffset:0];
    [self.replyBoxHeight setOffset:0];
    [self.viewRepliesTopOffset setOffset:0];
    [self.viewRepliesHeight setOffset:0];
}

#pragma mark - Actions

- (void)tapExpand {
    if ([self.delegate respondsToSelector:@selector(commentCell:didTapExpand:)]) {
        [self.delegate commentCell:self didTapExpand:!self.comment.isExpanded];
    }
}

- (void)tapViewReplies {
    if ([self.delegate respondsToSelector:@selector(commentCell:didTapViewReplies:)]) {
        [self.delegate commentCell:self didTapViewReplies:self.comment];
    }
}

- (void)tapLike {
    if ([self.delegate respondsToSelector:@selector(commentCell:didTapLike:)]) {
        [self.delegate commentCell:self didTapLike:self.comment];
    }
}

#pragma mark - Helpers

- (NSString *)formatCount:(NSInteger)count {
    if (count >= 10000) {
        return [NSString stringWithFormat:@"%.1fw", count / 10000.0];
    } else if (count >= 1000) {
        return [NSString stringWithFormat:@"%.1fk", count / 1000.0];
    }
    return [NSString stringWithFormat:@"%ld", (long)count];
}

- (NSString *)formatTime:(NSTimeInterval)timestamp {
    // 静态复用，避免每次调用都 alloc init
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd";
    });

    NSDate *date = [NSDate dateWithTimeIntervalSince1970:timestamp];
    NSTimeInterval diff = [[NSDate date] timeIntervalSinceDate:date];

    if (diff < 60) {
        return @"刚刚";
    } else if (diff < 3600) {
        return [NSString stringWithFormat:@"%ld分钟前", (long)(diff / 60)];
    } else if (diff < 86400) {
        return [NSString stringWithFormat:@"%ld小时前", (long)(diff / 3600)];
    } else if (diff < 7 * 86400) {
        return [NSString stringWithFormat:@"%ld天前", (long)(diff / 86400)];
    }

    return [formatter stringFromDate:date];
}

@end
