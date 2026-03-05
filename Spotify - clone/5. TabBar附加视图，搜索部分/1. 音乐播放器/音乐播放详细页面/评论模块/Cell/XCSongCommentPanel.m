//
//  XCSongCommentPanel.m
//  Spotify - clone
//
//  Created by Kimi on 2026/03/03.
//

#import "XCSongCommentPanel.h"
#import "XCSongCommentCell.h"
#import <Masonry/Masonry.h>

@interface XCSongCommentPanel () <UITableViewDataSource, UITableViewDelegate, XCSongCommentCellDelegate>

// UI 组件
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, strong) UILabel *emptyLabel;

@end

@implementation XCSongCommentPanel

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    self.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1.0];
    self.layer.cornerRadius = 16;
    self.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    self.clipsToBounds = YES;
    
    // 表格 - 使用 Plain 样式避免 Grouped 样式的白色背景区域
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    // iOS 15+ 需要设置 sectionHeaderTopPadding 为 0，避免顶部留白
    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 0;
    }
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, 20, 0);
    // 启用自动高度：Cell 高度由 Auto Layout 约束决定
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 100.0;
    [self.tableView registerClass:[XCSongCommentCell class] forCellReuseIdentifier:[XCSongCommentCell reuseIdentifier]];
    [self addSubview:self.tableView];
    
    // 加载指示器
    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.loadingIndicator.color = [UIColor whiteColor];
    self.loadingIndicator.hidesWhenStopped = YES;
    [self addSubview:self.loadingIndicator];
    
    // 空状态标签
    self.emptyLabel = [[UILabel alloc] init];
    self.emptyLabel.text = @"暂无评论";
    self.emptyLabel.font = [UIFont systemFontOfSize:16];
    self.emptyLabel.textColor = [UIColor colorWithWhite:0.5 alpha:1.0];
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.hidden = YES;
    [self addSubview:self.emptyLabel];
    
    // 布局
    [self setupConstraints];
}

- (void)setupConstraints {
    // 表格 - 顶部留一点边距
    [self.tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self).offset(12);
        make.left.right.bottom.equalTo(self);
    }];
    
    // 加载指示器
    [self.loadingIndicator mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self);
    }];
    
    // 空状态
    [self.emptyLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self);
    }];
}

#pragma mark - Theme

- (void)applyThemeColor:(UIColor *)baseColor {
    if (!baseColor) return;
    CGFloat r, g, b, a;
    if (![baseColor getRed:&r green:&g blue:&b alpha:&a]) return;
    // 播放页背景约 darken 20-30%，评论面板 darken 10%，形成层次感
    self.backgroundColor = [UIColor colorWithRed:r * 0.90
                                           green:g * 0.90
                                            blue:b * 0.90
                                           alpha:1.0];
}

#pragma mark - Data

- (void)setCommentList:(XCSongCommentList *)commentList {
    _commentList = commentList;
    [self reloadData];
}

- (void)reloadData {
    [self hideLoading];
    
    if (self.commentList.totalCount == 0) {
        [self showEmptyState];
    } else {
        self.emptyLabel.hidden = YES;
        self.tableView.hidden = NO;
        [self.tableView reloadData];
    }
}

#pragma mark - Public Methods

- (void)showLoading {
    self.loadingIndicator.hidden = NO;
    [self.loadingIndicator startAnimating];
    self.tableView.hidden = YES;
    self.emptyLabel.hidden = YES;
}

- (void)hideLoading {
    [self.loadingIndicator stopAnimating];
    self.loadingIndicator.hidden = YES;
}

- (void)showEmptyState {
    self.emptyLabel.hidden = NO;
    self.tableView.hidden = YES;
}

- (void)endRefreshing {
    [self.tableView.refreshControl endRefreshing];
}

- (void)endLoadMore:(BOOL)hasMore {
    // 加载完成后刷新底部区域，无更多时可显示提示
    [self.tableView reloadData];
    if (!hasMore) {
        UILabel *footer = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.tableView.bounds.size.width, 40)];
        footer.text = @"— 已加载全部评论 —";
        footer.font = [UIFont systemFontOfSize:12];
        footer.textColor = [UIColor colorWithWhite:0.5 alpha:1.0];
        footer.textAlignment = NSTextAlignmentCenter;
        self.tableView.tableFooterView = footer;
    } else {
        self.tableView.tableFooterView = nil;
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.commentList.hotComments.count > 0 ? 2 : 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.commentList.hotComments.count > 0 && section == 0) {
        return self.commentList.hotComments.count;
    }
    return self.commentList.comments.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    XCSongCommentCell *cell = [tableView dequeueReusableCellWithIdentifier:[XCSongCommentCell reuseIdentifier] forIndexPath:indexPath];
    
    XCSongComment *comment = [self commentAtIndexPath:indexPath];
    cell.comment = comment;
    cell.delegate = self;
    
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (self.commentList.hotComments.count > 0 && section == 0) {
        return @"精彩评论";
    }
    return [NSString stringWithFormat:@"全部评论 (%ld)", (long)self.commentList.comments.count];
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
}

// 自定义 section header 视图，设置背景色与面板一致
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    NSString *title = [self tableView:tableView titleForHeaderInSection:section];
    
    UIView *headerView = [[UIView alloc] init];
    headerView.backgroundColor = [UIColor clearColor];
    
    UILabel *label = [[UILabel alloc] init];
    label.font = [UIFont boldSystemFontOfSize:16];
    label.textColor = [UIColor colorWithWhite:0.9 alpha:1.0];
    label.text = title;
    [headerView addSubview:label];
    
    [label mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(headerView).offset(16);
        make.right.equalTo(headerView).offset(-16);
        make.centerY.equalTo(headerView);
    }];
    
    return headerView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 40;
}

#pragma mark - XCSongCommentCellDelegate

- (void)commentCell:(XCSongCommentCell *)cell didTapExpand:(BOOL)expanded {
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    if (!indexPath) return;

    XCSongComment *comment = [self commentAtIndexPath:indexPath];
    BOOL isHot = (self.commentList.hotComments.count > 0 && indexPath.section == 0);

    // 更新 model 中的展开状态（同时刷新高度缓存）
    [self.commentList updateExpandState:expanded forCommentAtIndex:indexPath.row isHot:isHot];

    // 先刷新 cell 内容（numberOfLines、按钮文字），再动画行高
    [cell refreshContentDisplay];

    [self.tableView beginUpdates];
    [self.tableView endUpdates];

    // 展开后滚动确保 cell 完整可见
    if (expanded) {
        [self.tableView scrollToRowAtIndexPath:indexPath
                              atScrollPosition:UITableViewScrollPositionNone
                                      animated:YES];
    }

    // 通知外层 delegate（Bug 8 修复）
    if ([self.delegate respondsToSelector:@selector(commentPanel:didToggleExpandForComment:atIndexPath:)]) {
        [self.delegate commentPanel:self didToggleExpandForComment:comment atIndexPath:indexPath];
    }
}

- (void)commentCell:(XCSongCommentCell *)cell didTapViewReplies:(XCSongComment *)comment {
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    if ([self.delegate respondsToSelector:@selector(commentPanel:didTapViewReplies:)]) {
        [self.delegate commentPanel:self didTapViewReplies:comment];
    }
}

- (void)commentCell:(XCSongCommentCell *)cell didTapLike:(XCSongComment *)comment {
    // 点赞功能暂不实现
}

#pragma mark - Helpers

- (XCSongComment *)commentAtIndexPath:(NSIndexPath *)indexPath {
    BOOL isHot = (self.commentList.hotComments.count > 0 && indexPath.section == 0);
    return [self.commentList commentAtIndex:indexPath.row isHot:isHot];
}

@end
