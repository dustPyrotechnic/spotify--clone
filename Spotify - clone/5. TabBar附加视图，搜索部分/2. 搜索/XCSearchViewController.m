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
#import <Masonry/Masonry.h>

@interface XCSearchViewController () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UISearchBarDelegate, UISearchResultsUpdating, UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;

@property (nonatomic, strong) UILabel *sectionTitleLabel;
@property (nonatomic, strong) UICollectionView *categoryCollectionView;
@property (nonatomic, strong) NSArray<XCCategoryModel *> *categories;
@property (nonatomic, strong) UISearchController *searchController;

@property (nonatomic, strong) UITableView *resultTableView;
@property (nonatomic, strong) NSMutableArray *searchResults;

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
    
    // 设置搜索控制器
    self.definesPresentationContext = YES;
    self.navigationItem.searchController = self.searchController;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    
    // iOS 18+ 设置搜索栏位置
    if (@available(iOS 18.0, *)) {
        self.navigationItem.preferredSearchBarPlacement = UINavigationItemSearchBarPlacementStacked;
    }
    
    // 初始化数据
    [self setupData];
    
    // 设置 UI
    [self setupUI];
    [self setupConstraints];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // 确保搜索控制器处于非激活状态
    if (self.searchController.active) {
        [self.searchController setActive:NO];
    }
}

#pragma mark - Data

- (void)setupData {
    self.categories = [XCCategoryModel defaultCategories];
    self.searchResults = [NSMutableArray array];
    
    // TODO: 可以在这里预加载分类封面图
    // [self fetchCategoryPreviews];
}

#pragma mark - UI Setup

- (void)setupUI {
    [self.view addSubview:self.scrollView];
    [self.scrollView addSubview:self.contentView];
    [self.contentView addSubview:self.sectionTitleLabel];
    [self.contentView addSubview:self.categoryCollectionView];
    
    // 搜索结果表格（初始隐藏）
    [self.view addSubview:self.resultTableView];
    self.resultTableView.hidden = YES;
    
    [_resultTableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.view.mas_safeAreaLayoutGuideTop);
        make.left.right.bottom.equalTo(self.view);
    }];
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
    NSInteger rows = (self.categories.count + 1) / 2;  // 2列，向上取整
    CGFloat itemHeight = 110;
    CGFloat lineSpacing = 12;
    return rows * itemHeight + (rows - 1) * lineSpacing;
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
    XCCategoryModel *model = self.categories[indexPath.item];
    NSLog(@"选中分类: %@", model.name);
    
    // TODO: 跳转到分类详情页，展示该分类的歌单
    // XCPlaylistViewController *vc = [[XCPlaylistViewController alloc] initWithCategoryModel:model];
    // [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat width = (collectionView.bounds.size.width - 12) / 2;  // 2列，间距12
    return CGSizeMake(width, 110);
}

#pragma mark - UISearchBarDelegate

- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar {
  //TODO: 这里进行展示搜索预测栏部分
  NSLog(@"搜索框被点击，准备进入编辑状态");
  return YES;  // YES 表示允许编辑，NO 表示禁止编辑
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    NSLog(@"搜索框开始编辑");
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    // 取消搜索，恢复显示分类网格
    [self showCategoryView:YES];
}

#pragma mark - UISearchResultsUpdating

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *query = searchController.searchBar.text ?: @"";
    
    if (query.length == 0) {
        [self.searchResults removeAllObjects];
        [self.resultTableView reloadData];
        [self showCategoryView:YES];
        return;
    }
    
    // 有搜索内容，显示结果表格
    [self showCategoryView:NO];
    
    // 执行搜索
    [self performSearchWithQuery:query];
}

- (void)showCategoryView:(BOOL)show {
    self.scrollView.hidden = !show;
    self.resultTableView.hidden = show;
}

- (void)performSearchWithQuery:(NSString *)query {
    // TODO: 调用网络请求搜索
    // 这里先模拟一些数据
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (query.length > 0) {
            self.searchResults = [NSMutableArray arrayWithArray:@[
                @{@"type": @"song", @"title": [NSString stringWithFormat:@"歌曲: %@", query], @"subtitle": @"艺人名称"},
                @{@"type": @"album", @"title": [NSString stringWithFormat:@"专辑: %@", query], @"subtitle": @"专辑艺人"},
                @{@"type": @"artist", @"title": [NSString stringWithFormat:@"艺人: %@", query], @"subtitle": @"艺人介绍"}
            ]];
            [self.resultTableView reloadData];
        }
    });
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.searchResults.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"SearchResultCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
        cell.backgroundColor = [UIColor systemBackgroundColor];
        cell.textLabel.textColor = [UIColor labelColor];
        cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    }
    
    NSDictionary *item = self.searchResults[indexPath.row];
    cell.textLabel.text = item[@"title"];
    cell.detailTextLabel.text = item[@"subtitle"];
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSLog(@"选中搜索结果: %@", self.searchResults[indexPath.row]);
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
        _sectionTitleLabel.font = [UIFont boldSystemFontOfSize:24];
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
        _categoryCollectionView.scrollEnabled = NO;  // 网格不滚动，由外层 ScrollView 控制
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
        _resultTableView.backgroundColor = [UIColor systemBackgroundColor];
        _resultTableView.dataSource = self;
        _resultTableView.delegate = self;
        _resultTableView.tableFooterView = [[UIView alloc] init];
        _resultTableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
        _resultTableView.separatorInset = UIEdgeInsetsMake(0, 16, 0, 16);
    }
    return _resultTableView;
}

@end
