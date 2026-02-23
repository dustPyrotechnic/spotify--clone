//
//  XCPersonalViewController.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/1.
//

#import "XCPersonalViewController.h"
#import "XCPersonalCollectionViewCell.h"
#import "XCPlaylistDatabaseManager.h"
#import "XCALbumDetailViewController.h"

#import <Masonry/Masonry.h>
#import <SDWebImage/SDWebImage.h>

static NSString *const kViewModeKey = @"XCPersonalViewMode";

/// 0 = 列表模式，1 = 封面 Grid 模式
typedef NS_ENUM(NSInteger, XCPersonalViewMode) {
    XCPersonalViewModeList = 0,
    XCPersonalViewModeGrid = 1,
};

@interface XCPersonalViewController () <UITableViewDelegate,
                                        UITableViewDataSource,
                                        UICollectionViewDelegate,
                                        UICollectionViewDataSource,
                                        UICollectionViewDelegateFlowLayout>

@property (nonatomic, assign) XCPersonalViewMode viewMode;
@property (nonatomic, assign) XCPlaylistSortType sortType;

@end

@implementation XCPersonalViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        self.model = [XCPersonalModel sharedInstance];
        _viewMode = (XCPersonalViewMode)[[NSUserDefaults standardUserDefaults]
                                          integerForKey:kViewModeKey];
        _sortType = XCPlaylistSortByUpdateTime;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.mainView = [[XCPersonalView alloc] init];
    [self.view addSubview:self.mainView];
    [self.mainView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];

    [self setupTableView];
    [self setupCollectionView];
    [self setupNavigationBar];
    [self applyViewMode:self.viewMode animated:NO];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.model loadPlaylists];
    [self.mainView.tableView reloadData];
    [self.mainView.collectionView reloadData];
}

#pragma mark - Setup

- (void)setupTableView {
    self.mainView.tableView.delegate = self;
    self.mainView.tableView.dataSource = self;
    [self.mainView.tableView registerClass:[XCPersonalTableViewCell class]
                    forCellReuseIdentifier:@"XCPersonalTableViewCell"];
}

- (void)setupCollectionView {
    self.mainView.collectionView.delegate = self;
    self.mainView.collectionView.dataSource = self;
    [self.mainView.collectionView registerClass:[XCPersonalCollectionViewCell class]
                     forCellWithReuseIdentifier:@"XCPersonalCollectionViewCell"];
}

- (void)setupNavigationBar {
    self.navigationItem.title = @"播放列表";

    // + 新建
    UIBarButtonItem *addButton = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                             target:self
                             action:@selector(addPlaylistTapped)];

    // ☰/⊞ 切换视图
    NSString *toggleImageName = (self.viewMode == XCPersonalViewModeList)
        ? @"rectangle.grid.2x2" : @"list.bullet";
    UIBarButtonItem *toggleButton = [[UIBarButtonItem alloc]
        initWithImage:[UIImage systemImageNamed:toggleImageName]
                style:UIBarButtonItemStylePlain
               target:self
               action:@selector(toggleViewModeTapped)];
    toggleButton.tag = 100;

    // ↑↓ 排序
    UIBarButtonItem *sortButton = [[UIBarButtonItem alloc]
        initWithImage:[UIImage systemImageNamed:@"arrow.up.arrow.down"]
                 menu:[self buildSortMenu]];

    self.navigationItem.rightBarButtonItems = @[addButton, toggleButton, sortButton];
}

#pragma mark - Navigation Bar Actions

- (void)addPlaylistTapped {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"新建播放列表"
                         message:nil
                  preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"播放列表名称";
    }];

    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"创建"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *action) {
        NSString *name = alert.textFields.firstObject.text;
        if (name.length > 0) {
            [weakSelf.model createPlaylistWithName:name];
            [weakSelf.mainView.tableView reloadData];
            [weakSelf.mainView.collectionView reloadData];
        }
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"取消"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)toggleViewModeTapped {
    XCPersonalViewMode newMode = (self.viewMode == XCPersonalViewModeList)
        ? XCPersonalViewModeGrid : XCPersonalViewModeList;
    [self applyViewMode:newMode animated:YES];
    [[NSUserDefaults standardUserDefaults] setInteger:newMode forKey:kViewModeKey];

    // 更新按钮图标
    NSString *imageName = (newMode == XCPersonalViewModeList)
        ? @"rectangle.grid.2x2" : @"list.bullet";
    UIBarButtonItem *toggleBtn = [self barButtonWithTag:100];
    toggleBtn.image = [UIImage systemImageNamed:imageName];
}

- (UIMenu *)buildSortMenu {
    __weak typeof(self) weakSelf = self;
    UIAction *byUpdateTime = [UIAction actionWithTitle:@"最近更新" image:nil identifier:nil handler:^(__kindof UIAction *_) {
        weakSelf.sortType = XCPlaylistSortByUpdateTime;
        [weakSelf reloadWithSort];
    }];
    UIAction *byCreateTime = [UIAction actionWithTitle:@"最近创建" image:nil identifier:nil handler:^(__kindof UIAction *_) {
        weakSelf.sortType = XCPlaylistSortByCreateTime;
        [weakSelf reloadWithSort];
    }];
    UIAction *byName = [UIAction actionWithTitle:@"名称 A-Z" image:nil identifier:nil handler:^(__kindof UIAction *_) {
        weakSelf.sortType = XCPlaylistSortByName;
        [weakSelf reloadWithSort];
    }];
    return [UIMenu menuWithTitle:@"排序方式" image:nil identifier:nil options:0
                        children:@[byUpdateTime, byCreateTime, byName]];
}

- (void)reloadWithSort {
    NSArray *result = [[XCPlaylistDatabaseManager sharedInstance]
                       getAllPlaylistsSortedBy:self.sortType];
    self.model.playlists = result ? [result mutableCopy] : [NSMutableArray array];
    [self.mainView.tableView reloadData];
    [self.mainView.collectionView reloadData];
}

#pragma mark - View Mode

- (void)applyViewMode:(XCPersonalViewMode)mode animated:(BOOL)animated {
    self.viewMode = mode;
    CGFloat tablealpha = (mode == XCPersonalViewModeList) ? 1.0 : 0.0;
    CGFloat collectionAlpha = (mode == XCPersonalViewModeGrid) ? 1.0 : 0.0;

    if (animated) {
        [UIView animateWithDuration:0.2 animations:^{
            self.mainView.tableView.alpha = tablealpha;
            self.mainView.collectionView.alpha = collectionAlpha;
        }];
    } else {
        self.mainView.tableView.alpha = tablealpha;
        self.mainView.collectionView.alpha = collectionAlpha;
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.model.playlists.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 72;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    XCPersonalTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"XCPersonalTableViewCell"
                                                                    forIndexPath:indexPath];
    XC_YYAlbumData *playlist = self.model.playlists[indexPath.row];
    [self configureTableCell:cell withPlaylist:playlist];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)configureTableCell:(XCPersonalTableViewCell *)cell withPlaylist:(XC_YYAlbumData *)playlist {
    cell.titleLabel.text = playlist.name;
    cell.subtitleLabel.text = [NSString stringWithFormat:@"歌单 · %ld 首歌", (long)playlist.songCount];

    // 清理旧的 gradient layer 和心形图标（防止复用问题）
    [self clearGradientFromView:cell.mainImageView];
    [cell.mainImageView.subviews enumerateObjectsUsingBlock:^(UIView *v, NSUInteger i, BOOL *stop) {
        if (v.tag == 999) [v removeFromSuperview];
    }];
    // 取消之前的图片下载
    [cell.mainImageView sd_cancelCurrentImageLoad];

    if (playlist.isFavorites) {
        // 喜爱的歌曲：心形图标 + 紫粉渐变背景
        cell.mainImageView.image = nil;
        cell.mainImageView.backgroundColor = [UIColor clearColor];
        [self applyGradientToView:cell.mainImageView];
        UIImage *heart = [UIImage systemImageNamed:@"heart.fill"];
        UIImageView *heartView = [[UIImageView alloc] initWithImage:heart];
        heartView.tintColor = [UIColor whiteColor];
        heartView.contentMode = UIViewContentModeScaleAspectFit;
        heartView.tag = 999;
        [cell.mainImageView addSubview:heartView];
        heartView.frame = CGRectInset(cell.mainImageView.bounds, 10, 10);
        heartView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    } else {
        cell.mainImageView.image = nil;
        cell.mainImageView.backgroundColor = [UIColor systemGray5Color];
        if (playlist.coverImgUrl.length > 0) {
            NSURL *url = [NSURL URLWithString:playlist.coverImgUrl];
            [cell.mainImageView sd_setImageWithURL:url];
        }
    }
}

- (void)applyGradientToView:(UIView *)view {
    // 先清理旧的 gradient layer
    [self clearGradientFromView:view];
    
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = CGRectMake(0, 0, 56, 56);
    gradient.colors = @[
        (id)[UIColor systemPurpleColor].CGColor,
        (id)[UIColor systemPinkColor].CGColor
    ];
    gradient.startPoint = CGPointMake(0, 0);
    gradient.endPoint = CGPointMake(1, 1);
    gradient.cornerRadius = 4;
    [view.layer insertSublayer:gradient atIndex:0];
}

- (void)clearGradientFromView:(UIView *)view {
    // 删除所有 gradient layer
    for (CALayer *layer in [view.layer.sublayers copy]) {
        if ([layer isKindOfClass:[CAGradientLayer class]]) {
            [layer removeFromSuperlayer];
        }
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UIView *header = [[UIView alloc] init];
    header.backgroundColor = [UIColor systemBackgroundColor];
    UILabel *label = [[UILabel alloc] init];
    label.text = @"播放列表";
    label.font = [UIFont systemFontOfSize:28 weight:UIFontWeightBold];
    label.textColor = [UIColor labelColor];
    [header addSubview:label];
    [label mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(header).offset(16);
        make.centerY.equalTo(header);
    }];
    return header;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 48;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self pushDetailForPlaylist:self.model.playlists[indexPath.row]];
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.model.playlists.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    XCPersonalCollectionViewCell *cell =
        [collectionView dequeueReusableCellWithReuseIdentifier:@"XCPersonalCollectionViewCell"
                                                  forIndexPath:indexPath];
    XC_YYAlbumData *playlist = self.model.playlists[indexPath.item];
    cell.nameLabel.text = playlist.name;

    // 清理旧的 gradient layer（防止复用问题）
    [self clearGradientFromView:cell.coverImageView];
    // 取消之前的图片下载
    [cell.coverImageView sd_cancelCurrentImageLoad];

    if (playlist.isFavorites) {
        cell.coverImageView.image = nil;
        [self applyGradientToCollectionCell:cell];
    } else {
        cell.coverImageView.image = nil;
        cell.coverImageView.backgroundColor = [UIColor systemGray5Color];
        if (playlist.coverImgUrl.length > 0) {
            NSURL *url = [NSURL URLWithString:playlist.coverImgUrl];
            [cell.coverImageView sd_setImageWithURL:url];
        }
    }
    return cell;
}

- (void)applyGradientToCollectionCell:(XCPersonalCollectionViewCell *)cell {
    // 先清理旧的 gradient layer
    [self clearGradientFromView:cell.coverImageView];
    
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = cell.coverImageView.bounds;
    gradient.colors = @[
        (id)[UIColor systemPurpleColor].CGColor,
        (id)[UIColor systemPinkColor].CGColor
    ];
    gradient.startPoint = CGPointMake(0, 0);
    gradient.endPoint = CGPointMake(1, 1);
    gradient.cornerRadius = 6;
    [cell.coverImageView.layer insertSublayer:gradient atIndex:0];
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat totalWidth = collectionView.bounds.size.width - 16 * 2 - 12;
    CGFloat itemWidth = floor(totalWidth / 2);
    return CGSizeMake(itemWidth, itemWidth + 44);
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    [self pushDetailForPlaylist:self.model.playlists[indexPath.item]];
}

#pragma mark - Navigation

- (void)pushDetailForPlaylist:(XC_YYAlbumData *)playlist {
    XCALbumDetailViewController *detailVC = [[XCALbumDetailViewController alloc] init];
    detailVC.model.playerlistName = playlist.name;
    detailVC.model.mainImaUrl = playlist.coverImgUrl ?: @"";
    detailVC.model.timeStr = @"最近更新";
    detailVC.model.playerList =
        [[XCPlaylistDatabaseManager sharedInstance] getSongsOfPlaylist:playlist.albumId];
    [self.navigationController pushViewController:detailVC animated:YES];
}

#pragma mark - Helper

- (UIBarButtonItem *)barButtonWithTag:(NSInteger)tag {
    for (UIBarButtonItem *item in self.navigationItem.rightBarButtonItems) {
        if (item.tag == tag) return item;
    }
    return nil;
}

@end
