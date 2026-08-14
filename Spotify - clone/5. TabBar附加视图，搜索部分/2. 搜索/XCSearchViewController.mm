//
//  XCSearchViewController.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/12/5.
//

#import "XCSearchViewController.h"
#import "XCSearchModel.h"
#import "XCCategoryCell.h"
#import "XCCategoryModel.h"
#import "XCMusicPlayerModel.h"
#import "XCAlbumDetailCell.h"
#import "XCSearchResultCell.h"
#import "XCSearchSuggestionCell.h"
#import "XCPlaylistDatabaseManager.h"
#import <Masonry/Masonry.h>
#import <SDWebImage/SDWebImage.h>

typedef NS_ENUM(NSInteger, XCSearchState) {
    XCSearchStateCategory,    // 分类浏览
    XCSearchStatePredictive,  // 搜索预测
    XCSearchStateResults      // 搜索结果
};

static NSString * const kXCRecentSearchesKey = @"XCRecentSearches";
static NSInteger  const kXCRecentSearchesMax = 10;
static NSInteger  const kPredictiveTableTag   = 100;
static NSInteger  const kResultTableTag       = 200;

/// 硬编码热搜备用（API 失败时降级使用）
static NSArray<NSString *> *XCHotSearchTerms(void) {
    return @[@"周杰伦", @"Taylor Swift", @"华语流行", @"说散就散", @"夜曲", @"晴天", @"告白气球", @"Blinding Lights"];
}

@interface XCSearchViewController () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UISearchBarDelegate, UISearchResultsUpdating, UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;

@property (nonatomic, strong) UILabel *sectionTitleLabel;
@property (nonatomic, strong) UICollectionView *categoryCollectionView;
@property (nonatomic, strong) NSArray<XCCategoryModel *> *categories;
@property (nonatomic, strong) UISearchController *searchController;

@property (nonatomic, strong) UITableView *resultTableView;
@property (nonatomic, strong) UITableView *predictiveTableView;
@property (nonatomic, strong) NSMutableArray<NSString *> *recentSearches;
@property (nonatomic, assign) XCSearchState currentState;

// 热搜与实时建议
@property (nonatomic, strong) NSArray<NSString *> *hotSearchTerms;
@property (nonatomic, strong) NSArray<NSString *> *currentSuggestions;
@property (nonatomic, assign) BOOL isShowingSuggestions;
@property (nonatomic, strong) NSTimer *suggestionDebounceTimer;

// 三类搜索结果
@property (nonatomic, strong) NSArray<XC_YYSongData *>   *songResults;
@property (nonatomic, strong) NSArray<XC_YYAlbumData *>  *albumResults;
@property (nonatomic, strong) NSArray                    *artistResults;

// 分段控件 & 状态
@property (nonatomic, assign) NSInteger selectedSegmentIndex;
@property (nonatomic, strong) UISegmentedControl *resultSegmentControl;

// 加载指示器 & 查询保护
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, copy)   NSString *lastSearchQuery;

// 空状态视图
@property (nonatomic, strong) UIView *emptyStateView;
@property (nonatomic, strong) UIImageView *emptyStateIcon;
@property (nonatomic, strong) UILabel *emptyStateTitle;
@property (nonatomic, strong) UILabel *emptyStateSubtitle;

@end

@implementation XCSearchViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        self.model = [[XCSearchModel alloc] init];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"搜索";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    self.definesPresentationContext = YES;
    self.navigationItem.searchController = self.searchController;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;

    if (@available(iOS 18.0, *)) {
        self.navigationItem.preferredSearchBarPlacement = UINavigationItemSearchBarPlacementStacked;
    }

    [self setupData];
    [self setupUI];
    [self setupConstraints];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.searchController.active) {
        [self.searchController setActive:NO];
    }
}

#pragma mark - Data

- (void)setupData {
    self.categories        = [XCCategoryModel defaultCategories];
    self.songResults       = @[];
    self.albumResults      = @[];
    self.artistResults     = @[];
    self.hotSearchTerms    = @[];
    self.currentSuggestions = @[];
    self.recentSearches    = [NSMutableArray array];
    self.selectedSegmentIndex = 0;
}

#pragma mark - UI Setup

- (void)setupUI {
    // 分类浏览区
    [self.view addSubview:self.scrollView];
    [self.scrollView addSubview:self.contentView];
    [self.contentView addSubview:self.sectionTitleLabel];
    [self.contentView addSubview:self.categoryCollectionView];

    // 分段控件（结果页顶部，初始隐藏）
    self.resultSegmentControl = [[UISegmentedControl alloc]
        initWithItems:@[@"歌曲", @"专辑", @"艺人"]];
    self.resultSegmentControl.selectedSegmentIndex = 0;
    [self.resultSegmentControl addTarget:self
                                  action:@selector(segmentChanged:)
                        forControlEvents:UIControlEventValueChanged];
    self.resultSegmentControl.hidden = YES;
    [self.view addSubview:self.resultSegmentControl];

    [self.resultSegmentControl mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.view.mas_safeAreaLayoutGuideTop).offset(8);
        make.left.equalTo(self.view).offset(16);
        make.right.equalTo(self.view).offset(-16);
        make.height.mas_equalTo(32);
    }];

    // 搜索结果表格（初始隐藏，顶部靠在分段控件下方）
    [self.view addSubview:self.resultTableView];
    self.resultTableView.hidden = YES;

    [self.resultTableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.resultSegmentControl.mas_bottom).offset(8);
        make.left.right.bottom.equalTo(self.view);
    }];

    // 预测搜索表格（初始隐藏）
    [self.view addSubview:self.predictiveTableView];
    self.predictiveTableView.hidden = YES;

    [self.predictiveTableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.view.mas_safeAreaLayoutGuideTop);
        make.left.right.bottom.equalTo(self.view);
    }];

    // 加载指示器（居中于结果区）
    self.loadingIndicator = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.loadingIndicator.hidesWhenStopped = YES;
    [self.view addSubview:self.loadingIndicator];

    [self.loadingIndicator mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.view);
        make.top.equalTo(self.resultSegmentControl.mas_bottom).offset(60);
    }];
    
    // 空状态视图
    [self setupEmptyStateView];
}

- (void)setupConstraints {
    [self.scrollView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];

    [self.contentView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.scrollView);
        make.width.equalTo(self.scrollView);
    }];

    [self.sectionTitleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.contentView).offset(20);
        make.left.equalTo(self.contentView).offset(20);
    }];

    [self.categoryCollectionView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.sectionTitleLabel.mas_bottom).offset(16);
        make.left.equalTo(self.contentView).offset(16);
        make.right.equalTo(self.contentView).offset(-16);
        make.height.mas_equalTo([self calculateCategoryCollectionHeight]);
        make.bottom.equalTo(self.contentView).offset(-30);
    }];
}

- (CGFloat)calculateCategoryCollectionHeight {
    if (!self.categories.count) return 0;
    NSInteger rows = (self.categories.count + 1) / 2;
    CGFloat itemHeight = 110;
    CGFloat lineSpacing = 12;
    return rows * itemHeight + (rows - 1) * lineSpacing;
}

#pragma mark - Empty State

- (void)setupEmptyStateView {
    self.emptyStateView = [[UIView alloc] init];
    self.emptyStateView.hidden = YES;
    [self.view addSubview:self.emptyStateView];
    
    // 图标
    self.emptyStateIcon = [[UIImageView alloc] init];
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:60 weight:UIImageSymbolWeightLight];
    self.emptyStateIcon.image = [UIImage systemImageNamed:@"magnifyingglass.circle" withConfiguration:config];
    self.emptyStateIcon.tintColor = [UIColor tertiaryLabelColor];
    self.emptyStateIcon.contentMode = UIViewContentModeScaleAspectFit;
    [self.emptyStateView addSubview:self.emptyStateIcon];
    
    // 标题
    self.emptyStateTitle = [[UILabel alloc] init];
    self.emptyStateTitle.font = [UIFont boldSystemFontOfSize:20];
    self.emptyStateTitle.textColor = [UIColor labelColor];
    self.emptyStateTitle.textAlignment = NSTextAlignmentCenter;
    [self.emptyStateView addSubview:self.emptyStateTitle];
    
    // 副标题
    self.emptyStateSubtitle = [[UILabel alloc] init];
    self.emptyStateSubtitle.font = [UIFont systemFontOfSize:15];
    self.emptyStateSubtitle.textColor = [UIColor secondaryLabelColor];
    self.emptyStateSubtitle.textAlignment = NSTextAlignmentCenter;
    self.emptyStateSubtitle.numberOfLines = 0;
    [self.emptyStateView addSubview:self.emptyStateSubtitle];
    
    // 约束
    [self.emptyStateView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.view);
        make.centerY.equalTo(self.view).offset(-40);
        make.left.right.equalTo(self.view).inset(40);
    }];
    
    [self.emptyStateIcon mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.emptyStateView);
        make.top.equalTo(self.emptyStateView);
        make.width.height.mas_equalTo(80);
    }];
    
    [self.emptyStateTitle mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.emptyStateView);
        make.top.equalTo(self.emptyStateIcon.mas_bottom).offset(16);
        make.left.right.equalTo(self.emptyStateView);
    }];
    
    [self.emptyStateSubtitle mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.emptyStateView);
        make.top.equalTo(self.emptyStateTitle.mas_bottom).offset(8);
        make.left.right.equalTo(self.emptyStateView);
        make.bottom.equalTo(self.emptyStateView);
    }];
}

- (void)showEmptyStateWithTitle:(NSString *)title subtitle:(NSString *)subtitle {
    self.emptyStateTitle.text = title;
    self.emptyStateSubtitle.text = subtitle;
    self.emptyStateView.hidden = NO;
    self.emptyStateView.alpha = 0;
    
    [UIView animateWithDuration:0.25 animations:^{
        self.emptyStateView.alpha = 1.0;
    }];
}

- (void)hideEmptyState {
    if (self.emptyStateView.hidden) return;
    
    [UIView animateWithDuration:0.2 animations:^{
        self.emptyStateView.alpha = 0;
    } completion:^(BOOL finished) {
        self.emptyStateView.hidden = YES;
    }];
}

- (void)checkAndShowEmptyState {
    BOOL hasResults = NO;
    switch (self.selectedSegmentIndex) {
        case 0: hasResults = self.songResults.count > 0; break;
        case 1: hasResults = self.albumResults.count > 0; break;
        case 2: hasResults = self.artistResults.count > 0; break;
    }
    
    if (!hasResults && !self.loadingIndicator.isAnimating && self.lastSearchQuery.length > 0) {
        NSString *typeName = @"";
        switch (self.selectedSegmentIndex) {
            case 0: typeName = @"歌曲"; break;
            case 1: typeName = @"专辑"; break;
            case 2: typeName = @"艺人"; break;
        }
        [self showEmptyStateWithTitle:@"未找到结果" 
                             subtitle:[NSString stringWithFormat:@"没有找到与\"%@\"相关的%@", self.lastSearchQuery, typeName]];
    } else {
        [self hideEmptyState];
    }
}

#pragma mark - State Machine

- (void)transitionToState:(XCSearchState)state animated:(BOOL)animated {
    self.currentState = state;
    
    // 切换状态时隐藏空状态
    [self hideEmptyState];

    // 分段控件只在结果页显示
    self.resultSegmentControl.hidden = (state != XCSearchStateResults);

    UIView *targetView;
    switch (state) {
        case XCSearchStateCategory:   targetView = self.scrollView;          break;
        case XCSearchStatePredictive: targetView = self.predictiveTableView; break;
        case XCSearchStateResults:    targetView = self.resultTableView;     break;
    }

    NSArray *allViews = @[self.scrollView, self.predictiveTableView, self.resultTableView];

    if (!animated) {
        for (UIView *v in allViews) v.hidden = (v != targetView);
        return;
    }

    targetView.alpha = 0;
    targetView.hidden = NO;
    [UIView animateWithDuration:0.2 animations:^{
        targetView.alpha = 1;
        for (UIView *v in allViews) {
            if (v != targetView) v.alpha = 0;
        }
    } completion:^(BOOL finished) {
        for (UIView *v in allViews) {
            v.hidden = (v != targetView);
            v.alpha = 1;
        }
    }];
}

#pragma mark - Segmented Control

- (void)segmentChanged:(UISegmentedControl *)sender {
    self.selectedSegmentIndex = sender.selectedSegmentIndex;
    [self.resultTableView reloadData];
    [self checkAndShowEmptyState];
}

#pragma mark - Recent Searches

- (void)saveRecentSearch:(NSString *)query {
    NSMutableArray *recent = [[[NSUserDefaults standardUserDefaults]
        arrayForKey:kXCRecentSearchesKey] mutableCopy] ?: [NSMutableArray array];
    [recent removeObject:query];
    [recent insertObject:query atIndex:0];
    if (recent.count > kXCRecentSearchesMax) {
        [recent removeLastObject];
    }
    [[NSUserDefaults standardUserDefaults] setObject:recent forKey:kXCRecentSearchesKey];
    self.recentSearches = recent;
}

- (void)clearRecentSearches {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kXCRecentSearchesKey];
    self.recentSearches = [NSMutableArray array];
    [self.predictiveTableView reloadData];
}

#pragma mark - Network Helpers

- (void)loadHotSearches {
    __weak typeof(self) weakSelf = self;
    [self.model fetchHotSearchesWithCompletion:^(NSArray<NSString *> *hotWords, NSError *error) {
        weakSelf.hotSearchTerms = (hotWords.count > 0) ? hotWords : XCHotSearchTerms();
        [weakSelf.predictiveTableView reloadData];
    }];
}

- (void)loadSuggestionsForQuery:(NSString *)query {
    [self.suggestionDebounceTimer invalidate];
    self.suggestionDebounceTimer = nil;

    if (query.length == 0) {
        self.isShowingSuggestions = NO;
        self.currentSuggestions = @[];
        [self.predictiveTableView reloadData];
        return;
    }

    __weak typeof(self) weakSelf = self;
    self.suggestionDebounceTimer = [NSTimer scheduledTimerWithTimeInterval:0.3
                                                                    target:weakSelf
                                                                  selector:@selector(fireSuggestionTimer:)
                                                                  userInfo:[query copy]
                                                                   repeats:NO];
}

- (void)fireSuggestionTimer:(NSTimer *)timer {
    NSString *query = timer.userInfo;
    if (query.length == 0) return;

    __weak typeof(self) weakSelf = self;
    [self.model fetchSuggestionsWithQuery:query
                               completion:^(NSArray<NSString *> *suggestions, NSError *error) {
        weakSelf.isShowingSuggestions = YES;
        weakSelf.currentSuggestions = suggestions ?: @[];
        [weakSelf.predictiveTableView reloadData];
    }];
}

#pragma mark - Search Execution

- (void)performSearchWithQuery:(NSString *)query {
    self.lastSearchQuery = query;
    self.selectedSegmentIndex = 0;
    self.resultSegmentControl.selectedSegmentIndex = 0;

    // 清空旧结果，开始加载
    self.songResults   = @[];
    self.albumResults  = @[];
    self.artistResults = @[];
    [self.resultTableView reloadData];
    [self.loadingIndicator startAnimating];

    __weak typeof(self) weakSelf = self;

    // 用计数器等待三路并发全部完成
    __block NSInteger completedCount = 0;
    void (^checkAllDone)(void) = ^{
        completedCount++;
        if (completedCount == 3) {
            [weakSelf.loadingIndicator stopAnimating];
            [weakSelf.resultTableView reloadData];
            [weakSelf checkAndShowEmptyState];
        }
    };

    [self.model searchSongsWithQuery:query offset:0 limit:30
                          completion:^(NSArray<XC_YYSongData *> *results, NSError *error) {
        if ([weakSelf.lastSearchQuery isEqualToString:query]) {
            weakSelf.songResults = results ?: @[];
        }
        checkAllDone();
    }];

    [self.model searchAlbumsWithQuery:query offset:0 limit:20
                           completion:^(NSArray<XC_YYAlbumData *> *results, NSError *error) {
        if ([weakSelf.lastSearchQuery isEqualToString:query]) {
            weakSelf.albumResults = results ?: @[];
        }
        checkAllDone();
    }];

    [self.model searchArtistsWithQuery:query offset:0 limit:20
                            completion:^(NSArray *results, NSError *error) {
        if ([weakSelf.lastSearchQuery isEqualToString:query]) {
            weakSelf.artistResults = results ?: @[];
        }
        checkAllDone();
    }];
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.categories.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    XCCategoryCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"CategoryCell" forIndexPath:indexPath];
    cell.model = self.categories[indexPath.item];
    return cell;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    // 添加选中动画
    XCCategoryCell *cell = (XCCategoryCell *)[collectionView cellForItemAtIndexPath:indexPath];
    [UIView animateWithDuration:0.1 animations:^{
        cell.transform = CGAffineTransformMakeScale(0.95, 0.95);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.1 animations:^{
            cell.transform = CGAffineTransformIdentity;
        }];
    }];
    
    XCCategoryModel *model = self.categories[indexPath.item];
    NSLog(@"选中分类: %@", model.name);
    // TODO: 跳转分类歌单页
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat width = (collectionView.bounds.size.width - 12) / 2;
    return CGSizeMake(width, 110);
}

#pragma mark - UISearchBarDelegate

- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar {
    return YES;
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    NSArray *saved = [[NSUserDefaults standardUserDefaults] arrayForKey:kXCRecentSearchesKey];
    self.recentSearches = saved ? [saved mutableCopy] : [NSMutableArray array];
    self.isShowingSuggestions = NO;
    self.currentSuggestions = @[];
    // 从 API 获取热搜（非阻塞，回调后 reload）
    [self loadHotSearches];
    [self.predictiveTableView reloadData];
    [self transitionToState:XCSearchStatePredictive animated:YES];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    [self.suggestionDebounceTimer invalidate];
    self.suggestionDebounceTimer = nil;
    self.isShowingSuggestions = NO;
    self.currentSuggestions = @[];
    [self transitionToState:XCSearchStateCategory animated:YES];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    NSString *query = searchBar.text;
    if (query.length == 0) return;

    [searchBar resignFirstResponder];
    [self saveRecentSearch:query];

    // 取消防抖，立即提交搜索
    [self.suggestionDebounceTimer invalidate];
    self.suggestionDebounceTimer = nil;
    self.isShowingSuggestions = NO;

    [self transitionToState:XCSearchStateResults animated:YES];
    [self performSearchWithQuery:query];
}

#pragma mark - UISearchResultsUpdating

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *query = searchController.searchBar.text ?: @"";

    if (query.length == 0) {
        // 清空文字：回到预测页（显示历史 + 热搜）
        self.isShowingSuggestions = NO;
        self.currentSuggestions = @[];
        [self.predictiveTableView reloadData];
        [self transitionToState:XCSearchStatePredictive animated:NO];
        return;
    }

    // 输入中：停留在预测页，防抖获取实时建议
    [self transitionToState:XCSearchStatePredictive animated:NO];
    [self loadSuggestionsForQuery:query];
}

#pragma mark - Song Menu

/// 为歌曲创建 UIMenu
- (UIMenu *)createSongMenuForSong:(XC_YYSongData *)song {
    NSMutableArray<UIMenuElement *> *actions = [NSMutableArray array];
    
    // 1. 添加到播放列表（子菜单）
    UIMenu *playlistsMenu = [self createPlaylistsSubmenuForSong:song];
    [actions addObject:playlistsMenu];
    
    // 2. 添加到喜爱的歌曲
    XCPlaylistDatabaseManager *db = [XCPlaylistDatabaseManager sharedInstance];
    BOOL isInFavorites = [db isSong:song.songId inPlaylist:@"favorites"];
    
    if (isInFavorites) {
        UIAction *removeFromFavorites = [UIAction actionWithTitle:@"从喜爱的歌曲中移除"
                                                            image:[UIImage systemImageNamed:@"heart.slash"]
                                                       identifier:nil
                                                          handler:^(__kindof UIAction * _Nonnull action) {
            [self removeSongFromFavorites:song];
        }];
        removeFromFavorites.attributes = UIMenuElementAttributesDestructive;
        [actions addObject:removeFromFavorites];
    } else {
        UIAction *addToFavorites = [UIAction actionWithTitle:@"添加到喜爱的歌曲"
                                                         image:[UIImage systemImageNamed:@"heart"]
                                                    identifier:nil
                                                       handler:^(__kindof UIAction * _Nonnull action) {
            [self addSongToFavorites:song];
        }];
        [actions addObject:addToFavorites];
    }
    
    // 3. 分隔线后是播放相关
    [actions addObject:[UIMenu menuWithTitle:@""
                                       image:nil
                                  identifier:nil
                                     options:UIMenuOptionsDisplayInline
                                    children:@[
        [UIAction actionWithTitle:@"下一首播放"
                            image:[UIImage systemImageNamed:@"text.line.first.and.arrowtriangle.forward"]
                       identifier:nil
                          handler:^(__kindof UIAction * _Nonnull action) {
            [self playSongNext:song];
        }],
        [UIAction actionWithTitle:@"添加到播放队列"
                            image:[UIImage systemImageNamed:@"text.badge.plus"]
                       identifier:nil
                          handler:^(__kindof UIAction * _Nonnull action) {
            [self addSongToQueue:song];
        }]
    ]]];
    
    // 4. 分享
    [actions addObject:[UIAction actionWithTitle:@"分享"
                                           image:[UIImage systemImageNamed:@"square.and.arrow.up"]
                                      identifier:nil
                                         handler:^(__kindof UIAction * _Nonnull action) {
        [self shareSong:song];
    }]];
    
    return [UIMenu menuWithTitle:@"" children:actions];
}

/// 创建播放列表子菜单
- (UIMenu *)createPlaylistsSubmenuForSong:(XC_YYSongData *)song {
    XCPlaylistDatabaseManager *db = [XCPlaylistDatabaseManager sharedInstance];
    NSArray<XC_YYAlbumData *> *playlists = [db getAllPlaylistsSortedBy:XCPlaylistSortByUpdateTime];
    
    NSMutableArray<UIAction *> *playlistActions = [NSMutableArray array];
    
    for (XC_YYAlbumData *playlist in playlists) {
        // 跳过"喜爱的歌曲"，因为已经单独处理了
        if (playlist.isFavorites) continue;
        
        BOOL isInPlaylist = [db isSong:song.songId inPlaylist:playlist.albumId];
        UIImage *image = isInPlaylist ? [UIImage systemImageNamed:@"checkmark"] : [UIImage systemImageNamed:@"music.note.list"];
        UIMenuElementState state = isInPlaylist ? UIMenuElementStateOn : UIMenuElementStateOff;
        
        UIAction *action = [UIAction actionWithTitle:playlist.name
                                               image:image
                                          identifier:nil
                                             handler:^(__kindof UIAction * _Nonnull action) {
            if (isInPlaylist) {
                [self removeSong:song fromPlaylist:playlist];
            } else {
                [self addSong:song toPlaylist:playlist];
            }
        }];
        action.state = state;
        [playlistActions addObject:action];
    }
    
    // 如果没有播放列表，显示提示
    if (playlistActions.count == 0) {
        UIAction *emptyAction = [UIAction actionWithTitle:@"暂无播放列表"
                                                    image:[UIImage systemImageNamed:@"exclamationmark.circle"]
                                               identifier:nil
                                                  handler:^(__kindof UIAction * _Nonnull action) {}];
        emptyAction.attributes = UIMenuElementAttributesDisabled;
        [playlistActions addObject:emptyAction];
    }
    
    // 添加"新建播放列表"选项
    [playlistActions addObject:[UIAction actionWithTitle:@"新建播放列表..."
                                                   image:[UIImage systemImageNamed:@"plus"]
                                              identifier:nil
                                                 handler:^(__kindof UIAction * _Nonnull action) {
        [self showCreatePlaylistAlertForSong:song];
    }]];
    
    return [UIMenu menuWithTitle:@"添加到播放列表"
                           image:[UIImage systemImageNamed:@"text.badge.plus"]
                      identifier:nil
                         options:0
                        children:playlistActions];
}

#pragma mark - Menu Actions

- (void)addSongToFavorites:(XC_YYSongData *)song {
    XCPlaylistDatabaseManager *db = [XCPlaylistDatabaseManager sharedInstance];
    BOOL success = [db addSong:song toPlaylist:@"favorites"];
    if (success) {
        [self showToast:@"已添加到喜爱的歌曲"];
        // 刷新当前行以更新菜单状态
        [self refreshCurrentSongCellIfNeeded];
    } else {
        [self showToast:@"歌曲已在喜爱的歌曲中"];
    }
}

- (void)removeSongFromFavorites:(XC_YYSongData *)song {
    XCPlaylistDatabaseManager *db = [XCPlaylistDatabaseManager sharedInstance];
    BOOL success = [db removeSong:song.songId fromPlaylist:@"favorites"];
    if (success) {
        [self showToast:@"已从喜爱的歌曲中移除"];
        [self refreshCurrentSongCellIfNeeded];
    }
}

- (void)addSong:(XC_YYSongData *)song toPlaylist:(XC_YYAlbumData *)playlist {
    XCPlaylistDatabaseManager *db = [XCPlaylistDatabaseManager sharedInstance];
    BOOL success = [db addSong:song toPlaylist:playlist.albumId];
    if (success) {
        [self showToast:[NSString stringWithFormat:@"已添加到\"%@\"", playlist.name]];
    } else {
        [self showToast:@"歌曲已在此播放列表中"];
    }
}

- (void)removeSong:(XC_YYSongData *)song fromPlaylist:(XC_YYAlbumData *)playlist {
    XCPlaylistDatabaseManager *db = [XCPlaylistDatabaseManager sharedInstance];
    BOOL success = [db removeSong:song.songId fromPlaylist:playlist.albumId];
    if (success) {
        [self showToast:[NSString stringWithFormat:@"已从\"%@\"中移除", playlist.name]];
    }
}

- (void)playSongNext:(XC_YYSongData *)song {
    XCMusicPlayerModel *player = [XCMusicPlayerModel sharedInstance];
    NSInteger currentIndex = [player.playerlist indexOfObject:player.nowPlayingSong];
    if (currentIndex == NSNotFound) {
        currentIndex = -1;
    }
    [player.playerlist insertObject:song atIndex:currentIndex + 1];
    [self showToast:@"已添加到下一首"];
}

- (void)addSongToQueue:(XC_YYSongData *)song {
    XCMusicPlayerModel *player = [XCMusicPlayerModel sharedInstance];
    [player.playerlist addObject:song];
    [self showToast:@"已添加到播放队列"];
}

- (void)shareSong:(XC_YYSongData *)song {
    NSString *shareText = [NSString stringWithFormat:@"分享歌曲：%@ - %@", song.name, song.artist];
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[shareText] applicationActivities:nil];
    [self presentViewController:activityVC animated:YES completion:nil];
}

- (void)showCreatePlaylistAlertForSong:(XC_YYSongData *)song {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"新建播放列表"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"播放列表名称";
    }];
    
    UIAlertAction *createAction = [UIAlertAction actionWithTitle:@"创建"
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * _Nonnull action) {
        NSString *name = alert.textFields.firstObject.text;
        if (name.length > 0) {
            XCPlaylistDatabaseManager *db = [XCPlaylistDatabaseManager sharedInstance];
            XC_YYAlbumData *newPlaylist = [db createPlaylistWithName:name];
            if (newPlaylist) {
                [db addSong:song toPlaylist:newPlaylist.albumId];
                [self showToast:[NSString stringWithFormat:@"已创建并添加歌曲到\"%@\"", name]];
            }
        }
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    
    [alert addAction:createAction];
    [alert addAction:cancelAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)refreshCurrentSongCellIfNeeded {
    // 刷新表格以更新菜单状态
    [self.resultTableView reloadData];
}

- (void)showToast:(NSString *)message {
    // 简单的 Toast 提示
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:alert animated:YES completion:nil];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [alert dismissViewControllerAnimated:YES completion:nil];
    });
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (tableView.tag == kPredictiveTableTag) {
        return 2; // Section 0: 历史/建议, Section 1: 热搜
    }
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (tableView.tag == kPredictiveTableTag) {
        if (section == 0) {
            return self.isShowingSuggestions
                ? (NSInteger)self.currentSuggestions.count
                : (NSInteger)self.recentSearches.count;
        }
        return (NSInteger)self.hotSearchTerms.count;
    }

    // 结果表：按分段
    switch (self.selectedSegmentIndex) {
        case 0: return (NSInteger)self.songResults.count;
        case 1: return (NSInteger)self.albumResults.count;
        case 2: return (NSInteger)self.artistResults.count;
        default: return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    // ---- 预测表 ----
    if (tableView.tag == kPredictiveTableTag) {
        XCSearchSuggestionCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SuggestionCell"];
        if (!cell) {
            cell = [[XCSearchSuggestionCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"SuggestionCell"];
        }
        if (indexPath.section == 0) {
            NSString *term = self.isShowingSuggestions
                ? self.currentSuggestions[indexPath.row]
                : self.recentSearches[indexPath.row];
            XCSuggestionType type = self.isShowingSuggestions ? XCSuggestionTypeSuggestion : XCSuggestionTypeRecent;
            [cell configureWithText:term type:type];
        } else {
            NSString *term = self.hotSearchTerms[indexPath.row];
            [cell configureWithText:term type:XCSuggestionTypeHot];
        }
        return cell;
    }

    // ---- 结果表：使用统一的新 Cell ----
    XCSearchResultCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SearchResultCell"];
    if (!cell) {
        cell = [[XCSearchResultCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"SearchResultCell"];
    }
    
    __weak typeof(self) weakSelf = self;
    
    // 歌曲（segment 0）
    if (self.selectedSegmentIndex == 0) {
        XC_YYSongData *song = self.songResults[indexPath.row];
        [cell configureWithSong:song];
        // 配置菜单
        [cell configureActionMenuWithProvider:^UIMenu *(XC_YYSongData *song) {
            return [weakSelf createSongMenuForSong:song];
        }];
        return cell;
    }

    // 专辑（segment 1）
    if (self.selectedSegmentIndex == 1) {
        XC_YYAlbumData *album = self.albumResults[indexPath.row];
        [cell configureWithAlbum:album];
        cell.actionButton.menu = nil;
        return cell;
    }

    // 艺人（segment 2）
    NSDictionary *artist = self.artistResults[indexPath.row];
    [cell configureWithArtist:artist];
    cell.actionButton.menu = nil;
    return cell;
}

- (nullable UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (tableView.tag != kPredictiveTableTag) return nil;

    UIView *header = [[UIView alloc] init];
    header.backgroundColor = [UIColor systemBackgroundColor];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    titleLabel.textColor = [UIColor labelColor];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:titleLabel];

    if (section == 0) {
        // 输入中显示"搜索建议"，未输入显示"最近搜索"
        titleLabel.text = self.isShowingSuggestions ? @"搜索建议" : @"最近搜索";

        if (!self.isShowingSuggestions && self.recentSearches.count > 0) {
            UIButton *clearBtn = [UIButton buttonWithType:UIButtonTypeSystem];
            [clearBtn setTitle:@"清除全部" forState:UIControlStateNormal];
            [clearBtn setTitleColor:[UIColor systemRedColor] forState:UIControlStateNormal];
            clearBtn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
            [clearBtn addTarget:self action:@selector(clearRecentSearches) forControlEvents:UIControlEventTouchUpInside];
            clearBtn.translatesAutoresizingMaskIntoConstraints = NO;
            [header addSubview:clearBtn];

            [NSLayoutConstraint activateConstraints:@[
                [titleLabel.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:20],
                [titleLabel.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
                [clearBtn.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-20],
                [clearBtn.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
            ]];
        } else {
            [NSLayoutConstraint activateConstraints:@[
                [titleLabel.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:20],
                [titleLabel.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
            ]];
        }
    } else {
        titleLabel.text = @"🔥 热门搜索";
        [NSLayoutConstraint activateConstraints:@[
            [titleLabel.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:20],
            [titleLabel.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
        ]];
    }

    return header;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (tableView.tag != kPredictiveTableTag) return 0;
    // 热搜还未加载时不显示 Section 1 标题
    if (section == 1 && self.hotSearchTerms.count == 0) return 0.001;
    // Section 0 如果没有内容也不显示
    if (section == 0) {
        if (self.isShowingSuggestions && self.currentSuggestions.count == 0) return 0.001;
        if (!self.isShowingSuggestions && self.recentSearches.count == 0) return 0.001;
    }
    return 48;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    // 结果表统一行高
    if (tableView.tag == kResultTableTag) {
        return 76.0;
    }
    // 预测表行高
    return 52.0;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    // ---- 预测表点击 ----
    if (tableView.tag == kPredictiveTableTag) {
        NSString *term;
        if (indexPath.section == 0) {
            term = self.isShowingSuggestions
                ? self.currentSuggestions[indexPath.row]
                : self.recentSearches[indexPath.row];
        } else {
            term = self.hotSearchTerms[indexPath.row];
        }
        self.searchController.searchBar.text = term;
        [self saveRecentSearch:term];

        [self.suggestionDebounceTimer invalidate];
        self.suggestionDebounceTimer = nil;
        self.isShowingSuggestions = NO;

        [self transitionToState:XCSearchStateResults animated:YES];
        [self performSearchWithQuery:term];
        return;
    }

    // ---- 结果表点击 ----
    if (self.selectedSegmentIndex == 0 && self.songResults.count > 0) {
        XC_YYSongData *song = self.songResults[indexPath.row];
        XCMusicPlayerModel *player = [XCMusicPlayerModel sharedInstance];
        player.playerlist = [NSMutableArray arrayWithArray:self.songResults];
        player.nowPlayingSong = song;
        [player playMusicWithId:song.songId];
        return;
    }

    if (self.selectedSegmentIndex == 1 && self.albumResults.count > 0) {
        XC_YYAlbumData *album = self.albumResults[indexPath.row];
        NSLog(@"[Search] 选中专辑: %@ (%@)", album.name, album.albumId);
        // TODO: push XCALbumDetailViewController
    }

    if (self.selectedSegmentIndex == 2 && self.artistResults.count > 0) {
        NSDictionary *artist = self.artistResults[indexPath.row];
        NSLog(@"[Search] 选中艺人: %@", artist[@"name"]);
        // TODO: push 艺人详情页
    }
}

#pragma mark - Getters

- (UIScrollView *)scrollView {
    if (!_scrollView) {
        _scrollView = [[UIScrollView alloc] init];
        _scrollView.showsVerticalScrollIndicator = NO;
        _scrollView.alwaysBounceVertical = YES;
    }
    return _scrollView;
}

- (UIView *)contentView {
    if (!_contentView) {
        _contentView = [[UIView alloc] init];
    }
    return _contentView;
}

- (UILabel *)sectionTitleLabel {
    if (!_sectionTitleLabel) {
        _sectionTitleLabel = [[UILabel alloc] init];
        _sectionTitleLabel.text = @"浏览全部";
        _sectionTitleLabel.font = [UIFont systemFontOfSize:26 weight:UIFontWeightBold];
        _sectionTitleLabel.textColor = [UIColor labelColor];
        _sectionTitleLabel.hidden = NO;
    }
    return _sectionTitleLabel;
}

- (UICollectionView *)categoryCollectionView {
    if (!_categoryCollectionView) {
        UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
        layout.minimumLineSpacing = 12;
        layout.minimumInteritemSpacing = 12;

        _categoryCollectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
        _categoryCollectionView.backgroundColor = UIColor.clearColor;
        _categoryCollectionView.scrollEnabled = NO;
        _categoryCollectionView.dataSource = self;
        _categoryCollectionView.delegate = self;
        [_categoryCollectionView registerClass:[XCCategoryCell class] forCellWithReuseIdentifier:@"CategoryCell"];
    }
    return _categoryCollectionView;
}

- (UISearchController *)searchController {
    if (!_searchController) {
        UISearchController *sc = [[UISearchController alloc] initWithSearchResultsController:nil];
        sc.searchBar.delegate = self;
        sc.searchBar.placeholder = @"艺人、歌曲、歌词以及更多内容";
        sc.searchBar.searchBarStyle = UISearchBarStyleMinimal;
        sc.hidesNavigationBarDuringPresentation = NO;
        sc.automaticallyShowsCancelButton = YES;
        sc.searchResultsUpdater = self;
        _searchController = sc;
    }
    return _searchController;
}

- (UITableView *)resultTableView {
    if (!_resultTableView) {
        _resultTableView = [[UITableView alloc] init];
        _resultTableView.tag = kResultTableTag;
        _resultTableView.backgroundColor = [UIColor systemBackgroundColor];
        _resultTableView.dataSource = self;
        _resultTableView.delegate = self;
        _resultTableView.tableFooterView = [[UIView alloc] init];
        // 使用现代风格的分隔线
        _resultTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        // 注册搜索结果单元格
        [_resultTableView registerClass:[XCSearchResultCell class] forCellReuseIdentifier:@"SearchResultCell"];
    }
    return _resultTableView;
}

- (UITableView *)predictiveTableView {
    if (!_predictiveTableView) {
        _predictiveTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
        _predictiveTableView.tag = kPredictiveTableTag;
        _predictiveTableView.backgroundColor = [UIColor systemBackgroundColor];
        _predictiveTableView.dataSource = self;
        _predictiveTableView.delegate = self;
        _predictiveTableView.tableFooterView = [[UIView alloc] init];
        // 隐藏分隔线，使用 Cell 内部的高亮效果
        _predictiveTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        // 设置 section 间距
        _predictiveTableView.sectionHeaderTopPadding = 8;
        // 注册搜索建议单元格
        [_predictiveTableView registerClass:[XCSearchSuggestionCell class] forCellReuseIdentifier:@"SuggestionCell"];
    }
    return _predictiveTableView;
}

@end
