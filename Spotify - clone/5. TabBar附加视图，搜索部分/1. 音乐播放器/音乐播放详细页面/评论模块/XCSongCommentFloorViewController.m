//
//  XCSongCommentFloorViewController.m
//  Spotify - clone
//
//  楼层评论页面 - 展示某条评论的全部回复
//

#import "XCSongCommentFloorViewController.h"
#import "XCSongCommentFloorList.h"
#import "XCSongCommentService.h"
#import "XCSongCommentCell.h"
#import <Masonry/Masonry.h>
#import <SDWebImage/SDWebImage.h>

// 楼层 cell 复用标识
static NSString * const kFloorCellID     = @"XCSongCommentCell";
// 每次加载数量
static const NSInteger kFloorPageSize    = 20;
// 楼层缩进基准（每层缩进量）
static const CGFloat   kFloorIndentUnit  = 20.0;

#pragma mark - ViewController

@interface XCSongCommentFloorViewController () <UITableViewDataSource, UITableViewDelegate, XCSongCommentCellDelegate>

// UI
@property (nonatomic, strong) UIView        *navBar;
@property (nonatomic, strong) UILabel       *titleLabel;
@property (nonatomic, strong) UIButton      *closeButton;
@property (nonatomic, strong) UITableView   *tableView;
@property (nonatomic, strong) UIActivityIndicatorView *loadingView;
@property (nonatomic, strong) UILabel       *emptyLabel;
@property (nonatomic, strong) UIButton      *loadMoreButton;

// 数据
@property (nonatomic, strong) XCSongComment         *parentCommentRW;
@property (nonatomic, copy)   NSString              *songIdRW;
@property (nonatomic, strong) XCSongCommentFloorList *floorList;
@property (nonatomic, assign) BOOL                  isLoadingMore;

@end

@implementation XCSongCommentFloorViewController

#pragma mark - 初始化

- (instancetype)initWithComment:(XCSongComment *)comment songId:(NSString *)songId {
    self = [super init];
    if (self) {
        _parentCommentRW = comment;
        _songIdRW = [songId copy];
    }
    return self;
}

- (XCSongComment *)parentComment { return _parentCommentRW; }
- (NSString *)songId             { return _songIdRW; }

#pragma mark - 生命周期

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
    [self loadFirstPage];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    // 离开时取消未完成的请求（避免回调打到已释放的对象）
    [[XCSongCommentService sharedInstance] cancelAllRequests];
}

#pragma mark - UI 搭建

- (void)setupUI {
    self.view.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1.0];

    [self setupNavBar];
    [self setupOwnerHeader];
    [self setupTableView];
    [self setupLoadingView];
    [self setupEmptyLabel];
}

- (void)setupNavBar {
    self.navBar = [[UIView alloc] init];
    self.navBar.backgroundColor = [UIColor colorWithWhite:0.14 alpha:1.0];
    [self.view addSubview:self.navBar];

    [self.navBar mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.right.equalTo(self.view);
        make.height.mas_equalTo(54 + [self statusBarHeight]);
    }];

    // 标题
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = [NSString stringWithFormat:@"%ld 条回复", (long)self.parentComment.replyCount];
    self.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.navBar addSubview:self.titleLabel];

    [self.titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.bottom.equalTo(self.navBar).offset(-14);
        make.centerX.equalTo(self.navBar);
    }];

    // 关闭按钮
    self.closeButton = [[UIButton alloc] init];
    [self.closeButton setImage:[UIImage systemImageNamed:@"xmark"] forState:UIControlStateNormal];
    self.closeButton.tintColor = [UIColor colorWithWhite:0.8 alpha:1.0];
    [self.closeButton addTarget:self action:@selector(tapClose) forControlEvents:UIControlEventTouchUpInside];
    [self.navBar addSubview:self.closeButton];

    [self.closeButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.navBar).offset(-16);
        make.centerY.equalTo(self.titleLabel);
        make.width.height.mas_equalTo(32);
    }];
}

/// 楼主评论固定在 tableView 顶部作为 header
- (void)setupOwnerHeader {
    // 由 tableView headerView 处理，setupTableView 中设置
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, 20, 0);
    [self.tableView registerClass:[XCSongCommentCell class] forCellReuseIdentifier:kFloorCellID];
    [self.view addSubview:self.tableView];

    [self.tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.navBar.mas_bottom);
        make.left.right.bottom.equalTo(self.view);
    }];

    // 楼主评论作为 tableHeaderView
    self.tableView.tableHeaderView = [self buildOwnerHeaderView];

    // 加载更多按钮作为 tableFooterView
    self.loadMoreButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 50)];
    [self.loadMoreButton setTitle:@"加载更多回复" forState:UIControlStateNormal];
    self.loadMoreButton.titleLabel.font = [UIFont systemFontOfSize:14];
    [self.loadMoreButton setTitleColor:[UIColor systemGreenColor] forState:UIControlStateNormal];
    [self.loadMoreButton addTarget:self action:@selector(tapLoadMore) forControlEvents:UIControlEventTouchUpInside];
    self.loadMoreButton.hidden = YES;
    self.tableView.tableFooterView = self.loadMoreButton;
}

- (UIView *)buildOwnerHeaderView {
    // 容器
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 1)];
    header.backgroundColor = [UIColor colorWithWhite:0.14 alpha:1.0];

    // 头像
    UIImageView *avatar = [[UIImageView alloc] initWithFrame:CGRectMake(16, 14, 36, 36)];
    avatar.layer.cornerRadius = 18;
    avatar.clipsToBounds = YES;
    avatar.contentMode = UIViewContentModeScaleAspectFill;
    avatar.backgroundColor = [UIColor systemGray5Color];
    if (self.parentComment.avatarUrl) {
        [avatar sd_setImageWithURL:[NSURL URLWithString:self.parentComment.avatarUrl]
                 placeholderImage:[UIImage systemImageNamed:@"person.circle"]];
    }
    [header addSubview:avatar];

    // 昵称
    UILabel *nickname = [[UILabel alloc] initWithFrame:CGRectMake(62, 14, self.view.bounds.size.width - 78, 18)];
    nickname.text = self.parentComment.nickname ?: @"未知用户";
    nickname.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    nickname.textColor = [UIColor colorWithWhite:0.9 alpha:1.0];
    [header addSubview:nickname];

    // 楼主标签
    UILabel *ownerTag = [[UILabel alloc] init];
    ownerTag.text = @"楼主";
    ownerTag.font = [UIFont systemFontOfSize:10];
    ownerTag.textColor = [UIColor systemGreenColor];
    ownerTag.backgroundColor = [UIColor colorWithRed:0.1 green:0.7 blue:0.3 alpha:0.2];
    ownerTag.layer.cornerRadius = 4;
    ownerTag.layer.masksToBounds = YES;
    ownerTag.textAlignment = NSTextAlignmentCenter;
    [header addSubview:ownerTag];
    [ownerTag sizeToFit];
    CGRect tagFrame = ownerTag.frame;
    tagFrame.size.width += 10;
    tagFrame.size.height = 18;
    tagFrame.origin.x = 62 + nickname.intrinsicContentSize.width + 8;
    tagFrame.origin.y = 14;
    ownerTag.frame = tagFrame;

    // 内容
    CGFloat contentY = 14 + 18 + 6;
    CGFloat contentWidth = self.view.bounds.size.width - 78;
    NSString *content = self.parentComment.content ?: @"";
    UILabel *contentLabel = [[UILabel alloc] init];
    contentLabel.text = content;
    contentLabel.font = [UIFont systemFontOfSize:14];
    contentLabel.textColor = [UIColor colorWithWhite:0.85 alpha:1.0];
    contentLabel.numberOfLines = 0;

    CGFloat contentH = [content boundingRectWithSize:CGSizeMake(contentWidth, CGFLOAT_MAX)
                                             options:NSStringDrawingUsesLineFragmentOrigin
                                          attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:14]}
                                             context:nil].size.height;
    contentH = ceil(contentH);
    contentLabel.frame = CGRectMake(62, contentY, contentWidth, contentH);
    [header addSubview:contentLabel];

    // 分割线
    CGFloat totalH = contentY + contentH + 14;
    UIView *separator = [[UIView alloc] initWithFrame:CGRectMake(0, totalH - 0.5, self.view.bounds.size.width, 0.5)];
    separator.backgroundColor = [UIColor colorWithWhite:0.3 alpha:1.0];
    [header addSubview:separator];

    header.frame = CGRectMake(0, 0, self.view.bounds.size.width, totalH);
    return header;
}

- (void)setupLoadingView {
    self.loadingView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.loadingView.color = [UIColor whiteColor];
    self.loadingView.hidesWhenStopped = YES;
    [self.view addSubview:self.loadingView];

    [self.loadingView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self.view);
    }];
}

- (void)setupEmptyLabel {
    self.emptyLabel = [[UILabel alloc] init];
    self.emptyLabel.text = @"暂无回复";
    self.emptyLabel.font = [UIFont systemFontOfSize:16];
    self.emptyLabel.textColor = [UIColor colorWithWhite:0.5 alpha:1.0];
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.hidden = YES;
    [self.view addSubview:self.emptyLabel];

    [self.emptyLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self.view);
    }];
}

#pragma mark - 数据加载

- (void)loadFirstPage {
    [self showLoading];

    __weak typeof(self) weakSelf = self;
    [[XCSongCommentService sharedInstance] fetchFloorComments:self.parentComment.commentId
                                                        songId:self.songId
                                                         limit:kFloorPageSize
                                                          time:nil
                                                    completion:^(XCSongCommentFloorList * _Nullable floorList, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            [strongSelf hideLoading];

            if (error || !floorList) {
                [strongSelf showEmptyState];
                return;
            }

            strongSelf.floorList = floorList;
            [strongSelf.tableView reloadData];
            strongSelf.loadMoreButton.hidden = !floorList.hasMore;
        });
    }];
}

- (void)tapLoadMore {
    if (self.isLoadingMore || !self.floorList.hasMore) return;
    self.isLoadingMore = YES;

    [self.loadMoreButton setTitle:@"加载中..." forState:UIControlStateNormal];
    self.loadMoreButton.enabled = NO;

    __weak typeof(self) weakSelf = self;
    [[XCSongCommentService sharedInstance] fetchFloorComments:self.parentComment.commentId
                                                        songId:self.songId
                                                         limit:kFloorPageSize
                                                          time:self.floorList.nextTime
                                                    completion:^(XCSongCommentFloorList * _Nullable newPage, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            strongSelf.isLoadingMore = NO;
            strongSelf.loadMoreButton.enabled = YES;

            if (!error && newPage) {
                [strongSelf appendFloorList:newPage];
            }

            BOOL hasMore = strongSelf.floorList.hasMore;
            strongSelf.loadMoreButton.hidden = !hasMore;
            [strongSelf.loadMoreButton setTitle:@"加载更多回复" forState:UIControlStateNormal];
        });
    }];
}

/// 将新一页数据追加合并到现有 floorList，并插入对应行
- (void)appendFloorList:(XCSongCommentFloorList *)newPage {
    if (!newPage || newPage.floorItems.count == 0) return;

    NSInteger oldCount = self.floorList.floorItems.count;
    [self.floorList appendItemsFromFloorList:newPage];

    NSMutableArray<NSIndexPath *> *newPaths = [NSMutableArray array];
    for (NSInteger i = oldCount; i < (NSInteger)self.floorList.floorItems.count; i++) {
        [newPaths addObject:[NSIndexPath indexPathForRow:i inSection:0]];
    }
    [self.tableView insertRowsAtIndexPaths:newPaths withRowAnimation:UITableViewRowAnimationFade];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.floorList.floorItems.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    XCSongCommentCell *cell = [tableView dequeueReusableCellWithIdentifier:kFloorCellID forIndexPath:indexPath];
    cell.delegate = self;

    XCSongCommentFloorItem *item = [self.floorList itemAtIndex:indexPath.row];
    cell.comment = item.comment;

    // 根据楼层深度设置左侧缩进（最大2级，超过的不再加深）
    NSInteger indentLevel = MIN(item.floorLevel - 1, 2);
    cell.contentView.layoutMargins = UIEdgeInsetsMake(0, 16 + indentLevel * kFloorIndentUnit, 0, 0);
    cell.separatorInset = UIEdgeInsetsMake(0, 16 + indentLevel * kFloorIndentUnit, 0, 0);

    return cell;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 100;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
}

#pragma mark - XCSongCommentCellDelegate

- (void)commentCell:(XCSongCommentCell *)cell didTapExpand:(BOOL)expanded {
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    if (!indexPath) return;
    cell.comment.isExpanded = expanded;
    [cell refreshContentDisplay];
    [self.tableView beginUpdates];
    [self.tableView endUpdates];
}

- (void)commentCell:(XCSongCommentCell *)cell didTapViewReplies:(XCSongComment *)comment {
    // 楼层内的嵌套回复：不再递归进入，忽略
}

- (void)commentCell:(XCSongCommentCell *)cell didTapLike:(XCSongComment *)comment {
    // 点赞暂不实现
}

#pragma mark - 状态视图

- (void)showLoading {
    self.tableView.hidden = YES;
    self.emptyLabel.hidden = YES;
    [self.loadingView startAnimating];
}

- (void)hideLoading {
    [self.loadingView stopAnimating];
    self.tableView.hidden = NO;
}

- (void)showEmptyState {
    self.tableView.hidden = YES;
    self.emptyLabel.hidden = NO;
}

#pragma mark - Actions

- (void)tapClose {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - 工具方法

- (CGFloat)statusBarHeight {
    if (@available(iOS 13.0, *)) {
        UIWindowScene *scene = (UIWindowScene *)[UIApplication sharedApplication].connectedScenes.anyObject;
        return scene.statusBarManager.statusBarFrame.size.height;
    }
    return 20;
}

@end
