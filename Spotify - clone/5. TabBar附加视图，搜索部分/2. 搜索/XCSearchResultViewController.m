//
//  XCSearchResultViewController.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/22.
//

#import "XCSearchResultViewController.h"
#import <Masonry/Masonry.h>

@interface XCSearchResultViewController ()

@property (nonatomic, strong) NSMutableArray *searchResults;
@property (nonatomic, strong) UISearchController *searchController;

@end

@implementation XCSearchResultViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.title = @"搜索";
    
    // 设置搜索控制器
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.searchBar.placeholder = @"艺人、歌曲、歌词以及更多内容";
    self.searchController.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.searchController.hidesNavigationBarDuringPresentation = NO;
    self.searchController.automaticallyShowsCancelButton = YES;
    
    self.navigationItem.searchController = self.searchController;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.definesPresentationContext = YES;
    
    // 初始化数据
    self.searchResults = [NSMutableArray array];
    
    // 设置 UI
    [self setupUI];
    
    // 自动聚焦搜索框
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.searchController.searchBar becomeFirstResponder];
    });
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // 设置导航栏返回按钮
    self.navigationController.navigationBar.tintColor = [UIColor systemGreenColor];
}

- (void)setupUI {
    // 结果表格
    _resultTableView = [[UITableView alloc] init];
    _resultTableView.backgroundColor = [UIColor systemBackgroundColor];
    _resultTableView.dataSource = self;
    _resultTableView.delegate = self;
    _resultTableView.tableFooterView = [[UIView alloc] init];
    _resultTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [_resultTableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"ResultCell"];
    [self.view addSubview:_resultTableView];
    
    [_resultTableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
}

#pragma mark - UISearchResultsUpdating

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *query = searchController.searchBar.text ?: @"";
    self.searchQuery = query;
    
    if (query.length == 0) {
        [self.searchResults removeAllObjects];
        [self.resultTableView reloadData];
        return;
    }
    
    // 执行搜索请求
    [self performSearchWithQuery:query];
}

- (void)performSearchWithQuery:(NSString *)query {
    // TODO: 调用网络请求搜索歌曲/专辑/艺人
    // 这里先模拟一些数据
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (query.length > 0) {
            [self.searchResults removeAllObjects];
            [self.searchResults addObjectsFromArray:@[
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
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ResultCell" forIndexPath:indexPath];
    
    NSDictionary *item = self.searchResults[indexPath.row];
    cell.textLabel.text = item[@"title"];
    cell.detailTextLabel.text = item[@"subtitle"];
    cell.backgroundColor = [UIColor systemBackgroundColor];
    cell.textLabel.textColor = [UIColor labelColor];
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    // TODO: 跳转到歌曲详情/专辑详情/艺人详情页
    NSLog(@"选中搜索结果: %@", self.searchResults[indexPath.row]);
}

@end
