//
//  HomePageViewController.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/11/22.
//
#import <Masonry/Masonry.h>

#import "HomePageViewController.h"
#import "XCAudioCacheTestRunner.h"

#import "HomePageViewCollectionViewTableViewCell.h"

#import "HomePageViewCollectionViewCell.h"
#import "XCNetworkManager.h"

#import "XCALbumDetailViewController.h"

#import "XCMusicPlayerAccessoryView.h"
@interface HomePageViewController ()
@end

@implementation HomePageViewController
- (instancetype) init {
  self = [super init];
  if (self) {
    self.model = [[HomePageViewModel alloc] init];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(homePageDataLoaded:) name:@"HomePageDataLoaded" object:nil];
  }
  return self;
}
- (void)homePageDataLoaded:(NSNotification*)notification {
  dispatch_async(dispatch_get_main_queue(), ^{
    [self.mainView.mainTableView.refreshControl endRefreshing];
    [self.mainView.mainTableView reloadData];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
      for (int i = 0; i < self.model.dataOfAllAlbums.count; i++) {
        HomePageViewCollectionViewTableViewCell* cell = [self.mainView.mainTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:i]];
        if (cell && cell.collectionView) {
          [cell.collectionView reloadData];
        }
      }
    });
  });
}

- (void)refreshData:(UIRefreshControl *)refreshControl {
  NSLog(@"开始刷新");
  [self.model getDataOfAllAlbumsWithCompletion:^(BOOL success) {
    if (success) {
      NSLog(@"刷新到数据");
      [[NSNotificationCenter defaultCenter] postNotificationName:@"HomePageDataLoaded" object:nil];
      dispatch_async(dispatch_get_main_queue(), ^{
        [refreshControl endRefreshing];
      });
    }
  }];
}

- (void) dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}
- (void)viewDidLoad {
  [super viewDidLoad];
  // Do any additional setup after loading the view.

  // self.model = [[HomePageViewModel alloc] init];

  UIImageSymbolConfiguration *symbolConfig = [UIImageSymbolConfiguration configurationWithPointSize:25.0
                                                                                             weight:UIImageSymbolWeightMedium];
  // 设置导航栏上的按钮，左按钮
  UIButton* myImagePhotoBtn = [[UIButton alloc] init];

  [myImagePhotoBtn setImage:[UIImage systemImageNamed:@"person"] forState:UIControlStateNormal];
  myImagePhotoBtn.tintColor = [UIColor systemGreenColor];

  [myImagePhotoBtn setPreferredSymbolConfiguration:symbolConfig forImageInState:UIControlStateNormal];
  UIBarButtonItem* myImagePhotoButtonItem = [[UIBarButtonItem alloc]initWithCustomView:myImagePhotoBtn];

  NSArray* titleArr = @[@"All",@"Music",@"Podcast",@"Audiobooks"];

  NSMutableArray* btnArr = [[NSMutableArray alloc] init];
  [btnArr addObject:myImagePhotoButtonItem];

//  UIBarButtonItem *fixedSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
// 设置tag
  for (int index = 0; index < titleArr.count - 1; index++) {
    NSString *title = titleArr[index];
    UIBarButtonItem* btnItem = [[UIBarButtonItem alloc] initWithTitle:title style:UIBarButtonItemStylePlain target:self action:@selector(pressBtn:)];
    if (index == 0) {
      btnItem.tintColor = [UIColor systemGreenColor];
    }

    btnItem.tag = index + 100;
    [btnArr addObject:btnItem];

  }
  // 全部

  // 音乐

  // 博客

  // 有声书
  self.navigationItem.leftBarButtonItems = btnArr;
//  self.navigationItem.title = @"主页";


  // 设置View
  self.mainView = [[HomePageView alloc] initWithFrame:self.view.bounds];
  // 统一使用系统背景色，保持整体简洁
  self.view.backgroundColor = [UIColor systemBackgroundColor];

  self.mainView.mainTableView.delegate = self;
  self.mainView.mainTableView.dataSource = self;
  self.mainView.mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
  self.mainView.mainTableView.showsVerticalScrollIndicator = NO;
  self.mainView.mainTableView.estimatedRowHeight = 200;
  self.mainView.mainTableView.rowHeight = UITableViewAutomaticDimension;

  UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
  [refreshControl addTarget:self action:@selector(refreshData:) forControlEvents:UIControlEventValueChanged];
  self.mainView.mainTableView.refreshControl = refreshControl;

  [self.mainView.mainTableView registerClass:[HomePageViewCollectionViewTableViewCell class] forCellReuseIdentifier:@"HomePageViewCollectionViewTableViewCell"];
  
  [self.view addSubview:self.mainView];
  
  [self.model getDataOfAllAlbumsWithCompletion:^(BOOL success) {
    if (success) {
      NSLog(@"初始数据加载成功");
      [[NSNotificationCenter defaultCenter] postNotificationName:@"HomePageDataLoaded" object:nil];
    }
  }];
  // // 测试播放器页面展示
  // XCMusicPayerAccessoryView* musicPayerAccessoryView = [[XCMusicPayerAccessoryView alloc] initWithFrame:CGRectMake(20, 20, self.view.bounds.size.width - 40, 40) withImage:[UIImage imageNamed:@"1.jpeg"] andTitle:@"测试歌曲" withSonger:@"测试歌手" withCondition:NO];
  // [self.view addSubview:musicPayerAccessoryView];
  // [musicPayerAccessoryView mas_makeConstraints:^(MASConstraintMaker *make) {
  //   make.left.equalTo(self.view).offset(20);
  //   make.right.equalTo(self.view).offset(-20);
  //   make.centerY.equalTo(self.view);
  // }];

}

#pragma mark -UITableView相关内容
- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
  return 5;
}
- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return 1;
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
  // 根据 collectionViewCell 中 itemSize(高度 230) 预留空间，避免封面圆角和标题被截断
  return 250;
}

- (UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  
  HomePageViewCollectionViewTableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"HomePageViewCollectionViewTableViewCell"];
  if (!cell) {
    cell = [[HomePageViewCollectionViewTableViewCell alloc] initWithFrame:tableView.bounds];

  }
  // 设置代理
  cell.collectionView.delegate = self;
  cell.collectionView.dataSource = self;

  cell.collectionView.tag = indexPath.section + 100; // 三个collectionView，tag分别为100，101，102
  return cell;
}




- (UIView*) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
  NSArray* heightArray = @[@50,@40,@30,@30,@40];
  NSArray* titleArray = @[@"Picks",
                          @"Radio",
                          @"For You",
                          @"Popular",
                          @"Hot Mixes"];
  NSInteger safeSection = MIN(section, heightArray.count - 1);
  UIView* headView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, (CGFloat)[heightArray[safeSection] integerValue])];
  UILabel* titleLabel = [[UILabel alloc] init];
  titleLabel.text = safeSection < titleArray.count ? titleArray[safeSection] : @"";
  titleLabel.font = [UIFont systemFontOfSize:[heightArray[safeSection] integerValue] weight:UIFontWeightSemibold];
  titleLabel.textColor = [UIColor labelColor];
  titleLabel.textAlignment = NSTextAlignmentLeft;
  [headView addSubview:titleLabel];
  [titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
    make.left.equalTo(headView).offset(16);
    make.centerY.equalTo(headView);
  }];
  return headView;
}
- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
  NSArray* heightArray = @[@50,@40,@30,@30,@40];
  NSInteger safeSection = MIN(section, heightArray.count - 1);
  return (CGFloat)[heightArray[safeSection] integerValue];
}
- (CGFloat) tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
  return 5;
}

#pragma mark -UICollectionView
- (NSInteger) numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
  return 1;
}
- (NSInteger) collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
  return 10;
}

- (UICollectionViewCell*) collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
  HomePageViewCollectionViewCell* cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"HomePageViewCollectionViewCell" forIndexPath:indexPath];

  NSInteger dataIndex = collectionView.tag - 100;
  // dataIndex * 10 + row
  XC_YYAlbumData* album = self.model.dataOfAllAlbums[dataIndex * 10 + indexPath.row];
  // 安全检查：确保album对象有效
  if (!album) {
    NSLog(@"album对象为空: dataIndex=%ld, row=%ld", (long)dataIndex, (long)indexPath.row);
    return cell;
  }
  
  cell.data = album;
  [cell getDataAndLayout];
  
  return cell;
}

- (void) collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
  NSLog(@"[主页控制器]：点击了标签%ld的collectionView的第%ld个",collectionView.tag,(long)indexPath.row);
  // 点击之后，先去找这个专辑所有的数据，先进行一个网络请求，请求到歌曲的所有名字
  //  取出cell内存储的id信息
  HomePageViewCollectionViewCell* cell = [collectionView cellForItemAtIndexPath:indexPath];
  NSString* albumId = cell.data.albumId;
  NSString* imageURL = cell.data.coverImgUrl;
  XCALbumDetailViewController* detailViewController = [[XCALbumDetailViewController alloc] init];
  // 获取数据
  detailViewController.model.mainImaUrl = imageURL;
  detailViewController.model.playerlistName = cell.titleLable.text;
  [[XCNetworkManager sharedInstance] getDetailOfAlbumFromWY:detailViewController.model.playerList ofAlbumId:albumId withCompletion:^(BOOL success) {
    // 弹出这个页面
    [self.navigationController pushViewController:detailViewController animated:YES];
  }];
  NSLog(@"[主页控制器]：弹出详细视图");

}

- (void) collectionView:(UICollectionView *)collectionView prefetchItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths {
  // TODO: 使用多线程实现图片的下载内容

}

#pragma mark 其余部分内容
- (void) pressBtn:(UIBarButtonItem*)sender {
  NSLog(@"%@按钮被点击",sender.title);
  // 在按下后，将颜色改为绿色，并遍历属性数组，恢复其他的颜色
  sender.tintColor = [UIColor systemGreenColor];
  for (UIBarButtonItem* item in self.navigationItem.leftBarButtonItems) {
    if (item.tag != sender.tag) {
      item.tintColor = [UIColor labelColor];
    }
  }
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

#pragma mark - 缓存测试
#ifdef DEBUG
- (void)showCacheTestMenu:(id)sender {
  [XCAudioCacheTestRunner showTestMenuFromViewController:self];
}
#endif

@end
