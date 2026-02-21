//
//  XCPersonalViewController.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/1.
//

#import "XCPersonalViewController.h"

// 使用相对路径导入同模块内的文件
#import "../View/cells/XCPersonalGridCell.h"
#import "../View/cells/XCPersonalListCell.h"
#import "../View/views/XCCreatePlaylistView.h"
#import "../View/views/XCPlaylistSortMenu.h"

// 使用项目路径导入其他模块的文件
// 注意：如果编译失败，请在 Build Settings > Header Search Paths 中添加：
// $(SRCROOT)/Spotify - clone/详细页面
// $(SRCROOT)/Spotify - clone/6. 网络请求部分
#import "XCALbumDetailViewController.h"
#import "XCNetworkManager.h"

#import <Masonry/Masonry.h>

#pragma mark - 常量定义
static NSString* const kGridCellIdentifier = @"XCPersonalGridCell";
static NSString* const kListCellIdentifier = @"XCPersonalListCell";

@interface XCPersonalViewController ()

#pragma mark - 内部属性
@property (nonatomic, strong, readwrite) XCPersonalModel* model;
@property (nonatomic, strong, readwrite) XCPersonalView* mainView;
@property (nonatomic, strong, readwrite) UISearchController* searchController;
@property (nonatomic, strong, readwrite) UIBarButtonItem* createButton;
@property (nonatomic, strong, readwrite) UIBarButtonItem* filterButton;
@property (nonatomic, strong, readwrite) UIBarButtonItem* viewModeButton;

@end

@implementation XCPersonalViewController

#pragma mark - 生命周期
- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.title = @"音乐库";
    
    // 1. 初始化 Model
    [self setupModel];
    
    // 2. 初始化 View
    [self setupView];
    
    // 3. 设置导航栏
    [self setupNavigationBar];
    
    // 4. 注册通知
    [self registerNotifications];
    
    // 5. 加载数据
    [self loadData];
    
    // 6. 检查登录状态（预留）
    [self checkLoginStatus];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // 刷新数据
    [self.mainView reloadData];
    
    // 更新空状态显示
    [self updateEmptyViewVisibility];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[XCLoginManager sharedManager] removeObserver:self];
}

#pragma mark - 初始化方法
- (void)setupModel {
    // 获取 Model 单例
    self.model = [XCPersonalModel sharedInstance];
}

- (void)setupView {
    // 创建主视图
    self.mainView = [[XCPersonalView alloc] init];
    self.mainView.delegate = self;
    [self.view addSubview:self.mainView];
    
    [self.mainView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    
    // 注册 Cells
    [self.mainView.collectionView registerClass:[XCPersonalGridCell class] 
                     forCellWithReuseIdentifier:kGridCellIdentifier];
    [self.mainView.collectionView registerClass:[XCPersonalListCell class] 
                     forCellWithReuseIdentifier:kListCellIdentifier];
    
    // 设置 CollectionView 数据源和代理
    self.mainView.collectionView.dataSource = self;
    self.mainView.collectionView.delegate = self;
    
    // 添加长按手势
    UILongPressGestureRecognizer* longPress = [[UILongPressGestureRecognizer alloc] 
                                               initWithTarget:self 
                                               action:@selector(handleLongPress:)];
    [self.mainView.collectionView addGestureRecognizer:longPress];
}

- (void)setupNavigationBar {
    // 创建按钮
    self.createButton = [[UIBarButtonItem alloc] 
        initWithImage:[UIImage systemImageNamed:@"plus.circle.fill"]
                style:UIBarButtonItemStylePlain
               target:self
               action:@selector(createButtonTapped:)];
    self.createButton.tintColor = [UIColor systemGreenColor];
    
    // 筛选按钮
    self.filterButton = [[UIBarButtonItem alloc]
        initWithImage:[UIImage systemImageNamed:@"line.3.horizontal.decrease.circle"]
                style:UIBarButtonItemStylePlain
               target:self
               action:@selector(filterButtonTapped:)];
    
    // 视图切换按钮
    NSString* viewModeIcon = (self.mainView.currentViewMode == XCPlaylistViewModeGrid) ? 
                             @"list.bullet" : @"square.grid.2x2";
    self.viewModeButton = [[UIBarButtonItem alloc]
        initWithImage:[UIImage systemImageNamed:viewModeIcon]
                style:UIBarButtonItemStylePlain
               target:self
               action:@selector(viewModeButtonTapped:)];
    
    self.navigationItem.leftBarButtonItems = @[self.createButton, self.filterButton, self.viewModeButton];
    
    // 搜索控制器
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.searchController.searchBar.placeholder = @"搜索播放列表";
    self.navigationItem.searchController = self.searchController;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    
    // 添加测试按钮（DEBUG 模式）
#ifdef DEBUG
    UIBarButtonItem* testButton = [[UIBarButtonItem alloc] 
        initWithTitle:@"测试" 
        style:UIBarButtonItemStylePlain 
        target:self 
        action:@selector(showTestMenu:)];
    testButton.tintColor = [UIColor systemOrangeColor];
    self.navigationItem.rightBarButtonItem = testButton;
#endif
}

- (void)registerNotifications {
    // 监听数据变化通知
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleDataChanged:)
                                                 name:XCPlaylistDataChangedNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handlePlaylistCreated:)
                                                 name:XCPlaylistCreatedNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handlePlaylistDeleted:)
                                                 name:XCPlaylistDeletedNotification
                                               object:nil];
}

#pragma mark - 数据加载
- (void)loadData {
    [self.mainView showLoading:YES];
    
    __weak typeof(self) weakSelf = self;
    [self.model loadPlaylistsFromLocalWithCompletion:^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.mainView showLoading:NO];
            [weakSelf.mainView reloadData];
            [weakSelf updateEmptyViewVisibility];
            [weakSelf updateViewModeButtonIcon];
        });
    }];
}

- (void)updateEmptyViewVisibility {
    BOOL isEmpty = (self.model.filteredPlaylists.count == 0);
    [self.mainView showEmptyView:isEmpty];
}

- (void)updateViewModeButtonIcon {
    NSString* iconName = (self.mainView.currentViewMode == XCPlaylistViewModeGrid) ? 
                         @"list.bullet" : @"square.grid.2x2";
    self.viewModeButton.image = [UIImage systemImageNamed:iconName];
}

#pragma mark - 登录状态检查（预留）
- (void)checkLoginStatus {
    // 目前直接显示内容，登录功能日后完善
    self.mainView.loginStatus = XCLoginStatusLoggedIn;
    
    // 如需启用登录检查，取消下面的注释
    /*
    [[XCLoginManager sharedManager] checkLoginStatusWithCompletion:^(XCLoginStatus status) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.mainView.loginStatus = status;
            if (status == XCLoginStatusLoggedIn) {
                [self loadData];
            }
        });
    }];
    
    // 添加登录状态监听
    [[XCLoginManager sharedManager] addObserver:self];
    */
}

#pragma mark - 按钮事件处理
- (void)createButtonTapped:(id)sender {
    // 显示创建弹窗
    XCCreatePlaylistView* createView = [[XCCreatePlaylistView alloc] init];
    
    __weak typeof(self) weakSelf = self;
    createView.createHandler = ^(NSString* name) {
        [weakSelf.model createPlaylistWithName:name completion:^(BOOL success, NSString* playlistId) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) {
                    [weakSelf.mainView reloadData];
                    [weakSelf updateEmptyViewVisibility];
                    
                    // 滚动到新创建的播放列表
                    [weakSelf.mainView scrollToItemAtIndex:0 animated:YES];
                }
            });
        }];
    };
    
    [createView showInView:self.view];
}

- (void)filterButtonTapped:(id)sender {
    // 显示排序菜单
    [XCPlaylistSortMenu showInView:self.view
                   currentSortType:self.model.currentSortType
                           handler:^(XCPlaylistSortType sortType) {
        [self.model sortPlaylistsByType:sortType];
        [self.mainView reloadData];
    }];
}

- (void)viewModeButtonTapped:(id)sender {
    [self.mainView toggleViewModeAnimated:YES];
    [self updateViewModeButtonIcon];
}

- (void)handleLongPress:(UILongPressGestureRecognizer*)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    
    CGPoint point = [gesture locationInView:self.mainView.collectionView];
    NSIndexPath* indexPath = [self.mainView.collectionView indexPathForItemAtPoint:point];
    if (!indexPath) return;
    
    XC_YYAlbumData* playlist = self.model.filteredPlaylists[indexPath.row];
    
    // 显示操作菜单
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:playlist.name
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    // 编辑按钮
    [alert addAction:[UIAlertAction actionWithTitle:@"编辑名称" 
                                              style:UIAlertActionStyleDefault 
                                            handler:^(UIAlertAction * _Nonnull action) {
        [self showEditAlertForPlaylist:playlist];
    }]];
    
    // 删除按钮（系统播放列表不能删除）
    XCLocalPlaylistInfo* info = [self.model infoForPlaylist:playlist.albumId];
    if (info && info.playlistType != XCPlaylistTypeSystem) {
        [alert addAction:[UIAlertAction actionWithTitle:@"删除" 
                                                  style:UIAlertActionStyleDestructive 
                                                handler:^(UIAlertAction * _Nonnull action) {
            [self deletePlaylist:playlist];
        }]];
    }
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" 
                                              style:UIAlertActionStyleCancel 
                                            handler:nil]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showEditAlertForPlaylist:(XC_YYAlbumData*)playlist {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"编辑播放列表"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.text = playlist.name;
        textField.placeholder = @"播放列表名称";
    }];
    
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" 
                                              style:UIAlertActionStyleDefault 
                                            handler:^(UIAlertAction * _Nonnull action) {
        NSString* newName = alert.textFields.firstObject.text;
        if (newName.length > 0) {
            [weakSelf.model updatePlaylistWithId:playlist.albumId 
                                            name:newName 
                                      completion:^(BOOL success) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakSelf.mainView reloadData];
                });
            }];
        }
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" 
                                              style:UIAlertActionStyleCancel 
                                            handler:nil]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)deletePlaylist:(XC_YYAlbumData*)playlist {
    __weak typeof(self) weakSelf = self;
    [self.model deletePlaylistWithId:playlist.albumId completion:^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.mainView reloadData];
            [weakSelf updateEmptyViewVisibility];
        });
    }];
}

#pragma mark - 通知处理
- (void)handleDataChanged:(NSNotification*)notification {
    [self.mainView reloadData];
    [self updateEmptyViewVisibility];
}

- (void)handlePlaylistCreated:(NSNotification*)notification {
    NSString* name = notification.userInfo[@"playlistName"];
    NSLog(@"播放列表创建成功: %@", name);
}

- (void)handlePlaylistDeleted:(NSNotification*)notification {
    NSString* playlistId = notification.userInfo[@"playlistId"];
    NSLog(@"播放列表删除成功: %@", playlistId);
}

#pragma mark - UISearchResultsUpdating
- (void)updateSearchResultsForSearchController:(UISearchController*)searchController {
    NSString* searchText = searchController.searchBar.text;
    [self.model filterPlaylistsWithSearchText:searchText];
    [self.mainView reloadData];
    [self updateEmptyViewVisibility];
}

#pragma mark - UICollectionViewDataSource
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView*)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView*)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.model.filteredPlaylists.count;
}

- (UICollectionViewCell*)collectionView:(UICollectionView*)collectionView 
                 cellForItemAtIndexPath:(NSIndexPath*)indexPath {
    
    XC_YYAlbumData* playlist = self.model.filteredPlaylists[indexPath.row];
    XCLocalPlaylistInfo* info = [self.model infoForPlaylist:playlist.albumId];
    
    if (self.mainView.currentViewMode == XCPlaylistViewModeGrid) {
        XCPersonalGridCell* cell = [collectionView dequeueReusableCellWithReuseIdentifier:kGridCellIdentifier 
                                                                             forIndexPath:indexPath];
        [cell configureWithPlaylist:playlist info:info];
        return cell;
    } else {
        XCPersonalListCell* cell = [collectionView dequeueReusableCellWithReuseIdentifier:kListCellIdentifier 
                                                                             forIndexPath:indexPath];
        [cell configureWithPlaylist:playlist info:info];
        return cell;
    }
}

#pragma mark - UICollectionViewDelegate
- (void)collectionView:(UICollectionView*)collectionView didSelectItemAtIndexPath:(NSIndexPath*)indexPath {
    XC_YYAlbumData* playlist = self.model.filteredPlaylists[indexPath.row];
    
    // 跳转到详细页面
    XCALbumDetailViewController* detailVC = [[XCALbumDetailViewController alloc] init];
    detailVC.model.mainImaUrl = playlist.coverImgUrl;
    detailVC.model.playerlistName = playlist.name;
    
    // 显示加载
    [self.mainView showLoading:YES];
    
    __weak typeof(self) weakSelf = self;
    [[XCNetworkManager sharedInstance] getDetailOfAlbumFromWY:detailVC.model.playerList 
                                                    ofAlbumId:playlist.albumId 
                                               withCompletion:^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.mainView showLoading:NO];
            if (success) {
                [weakSelf.navigationController pushViewController:detailVC animated:YES];
            } else {
                // 显示错误提示
                UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"加载失败"
                                                                               message:@"无法加载播放列表详情"
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
                [weakSelf presentViewController:alert animated:YES completion:nil];
            }
        });
    }];
}

#pragma mark - XCPersonalViewDelegate
- (void)personalView:(UIView*)view didSelectPlaylistAtIndex:(NSInteger)index {
    // 已由 collectionView:didSelectItemAtIndexPath: 处理
}

- (void)personalViewDidTapCreateButton:(UIView*)view {
    [self createButtonTapped:nil];
}

- (void)personalViewDidTapLoginButton:(UIView*)view {
    // 预留登录按钮点击处理
    NSLog(@"登录按钮被点击（功能预留）");
    
    // 日后实现：
    // [[XCLoginManager sharedManager] loginWithAccount:... password:... completion:...];
}

- (void)personalView:(UIView*)view didChangeViewMode:(XCPlaylistViewMode)mode {
    [self updateViewModeButtonIcon];
}

#pragma mark - XCLoginStatusObserver（预留）
- (void)loginStatusDidChange:(XCLoginStatus)status {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.mainView.loginStatus = status;
        if (status == XCLoginStatusLoggedIn) {
            [self loadData];
        }
    });
}

- (void)userInfoDidUpdate:(XCUserInfo*)userInfo {
    // 用户信息更新，刷新 UI
    NSLog(@"用户信息更新: %@", userInfo.displayName);
}

- (void)loginDidExpire {
    // 登录过期处理
    self.mainView.loginStatus = XCLoginStatusLoginExpired;
}

#pragma mark - DEBUG 测试方法
#ifdef DEBUG
- (void)showTestMenu:(id)sender {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"测试菜单"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"添加5条测试数据" 
                                              style:UIAlertActionStyleDefault 
                                            handler:^(UIAlertAction * _Nonnull action) {
        [self addTestDataForDebugging];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"添加20条测试数据" 
                                              style:UIAlertActionStyleDefault 
                                            handler:^(UIAlertAction * _Nonnull action) {
        [self.model addTestDataForTesting:20];
        [self.mainView reloadData];
        [self updateEmptyViewVisibility];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"清除所有数据" 
                                              style:UIAlertActionStyleDestructive 
                                            handler:^(UIAlertAction * _Nonnull action) {
        [self clearAllDataForDebugging];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"切换视图模式" 
                                              style:UIAlertActionStyleDefault 
                                            handler:^(UIAlertAction * _Nonnull action) {
        [self.mainView toggleViewModeAnimated:YES];
        [self updateViewModeButtonIcon];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"测试登录视图" 
                                              style:UIAlertActionStyleDefault 
                                            handler:^(UIAlertAction * _Nonnull action) {
        self.mainView.loginStatus = XCLoginStatusNotLoggedIn;
        [self.mainView showLoginView:YES];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" 
                                              style:UIAlertActionStyleCancel 
                                            handler:nil]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)addTestDataForDebugging {
    [self.model addTestDataForTesting:5];
    [self.mainView reloadData];
    [self updateEmptyViewVisibility];
    
    // 显示提示
    UIAlertController* toast = [UIAlertController alertControllerWithTitle:nil
                                                                   message:@"已添加5条测试数据"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:toast animated:YES completion:nil];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [toast dismissViewControllerAnimated:YES completion:nil];
    });
}

- (void)clearAllDataForDebugging {
    UIAlertController* confirm = [UIAlertController alertControllerWithTitle:@"确认清除"
                                                                     message:@"将删除所有播放列表数据"
                                                              preferredStyle:UIAlertControllerStyleAlert];
    
    __weak typeof(self) weakSelf = self;
    [confirm addAction:[UIAlertAction actionWithTitle:@"清除" 
                                                style:UIAlertActionStyleDestructive 
                                              handler:^(UIAlertAction * _Nonnull action) {
        [weakSelf.model clearAllDataForTesting];
        [weakSelf.mainView reloadData];
        [weakSelf updateEmptyViewVisibility];
    }]];
    
    [confirm addAction:[UIAlertAction actionWithTitle:@"取消" 
                                                style:UIAlertActionStyleCancel 
                                              handler:nil]];
    
    [self presentViewController:confirm animated:YES completion:nil];
}
#endif

@end
