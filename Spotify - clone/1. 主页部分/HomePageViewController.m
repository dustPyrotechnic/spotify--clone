//
//  HomePageViewController.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/11/22.
//
#import <Masonry/Masonry.h>

#import "HomePageViewController.h"

#import "HomePageViewCollectionViewTableViewCell.h"

#import "HomePageViewCollectionViewCell.h"
#import "XCNetworkManager.h"

#import "XCMusicPlayerAccessoryView.h"
@interface HomePageViewController ()
@end

@implementation HomePageViewController
- (instancetype) init {
  self = [super init];
  if (self) {
    self.model = [[HomePageViewModel alloc] init];
    [[XCNetworkManager sharedInstance] getTokenWithCompletion:^(BOOL success) {
      [self.model getDataOfAllAlbums];
    }];
//    [self.model getDataOfAllAlbums];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(homePageDataLoaded:) name:@"HomePageDataLoaded" object:nil];
  }
  return self;
}
- (void) homePageDataLoaded:(NSNotification*)notification {
//  NSLog(@"首页数据加载完成");
  
  // 打印数据统计信息用于调试
//  NSLog(@"数据统计: 共有 %lu 组数据", (unsigned long)self.model.dataOfAllAlbums.count);
  for (int i = 0; i < self.model.dataOfAllAlbums.count; i++) {
    NSArray *group = self.model.dataOfAllAlbums[i];
//    NSLog(@"第 %d 组: %lu 个元素", i, (unsigned long)(group ? group.count : 0));
  }
  
  // 在主线程刷新UI
  dispatch_async(dispatch_get_main_queue(), ^{
    // 刷新UITableView
    [self.mainView.mainTableView reloadData];
    
    // 刷新UICollectionView（延迟一点确保tableView已刷新）
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
      for (int i = 0; i < 5 && i < self.model.dataOfAllAlbums.count; i++) {
        HomePageViewCollectionViewTableViewCell* cell = [self.mainView.mainTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:i]];
        if (cell && cell.collectionView) {
          [cell.collectionView reloadData];
        }
      }
    });
  });
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

  // tableView相关部分
  self.mainView.mainTableView.delegate = self;
  self.mainView.mainTableView.dataSource = self;
  // 隐藏灰色分割线
  self.mainView.mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
  // 隐藏滚动条
  self.mainView.mainTableView.showsVerticalScrollIndicator = NO;
  // 高度自适应
  self.mainView.mainTableView.estimatedRowHeight = 200;
  self.mainView.mainTableView.rowHeight = UITableViewAutomaticDimension;

  [self.mainView.mainTableView registerClass:[HomePageViewCollectionViewTableViewCell class] forCellReuseIdentifier:@"HomePageViewCollectionViewTableViewCell"];
  
  [self.view addSubview:self.mainView];
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
  // 给一个大标题，左侧对齐，字体大小根据不同的节大小不同，并且内容不同
  // 使用自动布局来约束
  UIView* headView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, (CGFloat)[heightArray[section] integerValue])];
  // 创建标题
  UILabel* titleLabel = [[UILabel alloc] init];
  titleLabel.text = titleArray[section];
  titleLabel.font = [UIFont systemFontOfSize:[heightArray[section] integerValue] weight:UIFontWeightSemibold];
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
  return (CGFloat)[heightArray[section] integerValue];
}
- (CGFloat) tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
  return 5;
}
#pragma mark -UICollectionView
- (NSInteger) numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
  return 1;
}
- (NSInteger) collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    // 根据实际数据返回数量，避免访问空数据
    NSInteger index = collectionView.tag - 100;
    if (index >= 0 && index < self.model.dataOfAllAlbums.count) {
        NSArray *dataArray = self.model.dataOfAllAlbums[index];
        if (dataArray && dataArray.count > 0) {
            return dataArray.count;
        }
    }
    return 0; // 数据未加载时返回0
}

- (UICollectionViewCell*) collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
  HomePageViewCollectionViewCell* cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"HomePageViewCollectionViewCell" forIndexPath:indexPath];
  
  // 安全获取数据索引
  NSInteger dataIndex = collectionView.tag - 100;
  
  // 安全检查：确保索引有效且数据已加载
  if (dataIndex < 0 || dataIndex >= self.model.dataOfAllAlbums.count) {
    NSLog(@"⚠️ 数据索引越界: tag=%ld, dataIndex=%ld, 数组长度=%lu", 
          (long)collectionView.tag, (long)dataIndex, (unsigned long)self.model.dataOfAllAlbums.count);
    return cell;
  }
  
  NSArray* dataArray = self.model.dataOfAllAlbums[dataIndex];
  
  // 安全检查：确保数组存在且索引有效
  if (!dataArray || dataArray.count == 0) {
    NSLog(@"⚠️ 数据数组为空: dataIndex=%ld", (long)dataIndex);
    return cell;
  }
  
  if (indexPath.row >= dataArray.count) {
    NSLog(@"⚠️ 数组索引越界: row=%ld, 数组长度=%lu", (long)indexPath.row, (unsigned long)dataArray.count);
    return cell;
  }
  
  XCAlbumSimpleData* album = dataArray[indexPath.row];
  
  // 安全检查：确保album对象有效
  if (!album) {
    NSLog(@"⚠️ album对象为空: dataIndex=%ld, row=%ld", (long)dataIndex, (long)indexPath.row);
    return cell;
  }
  
  cell.data = album;
  [cell getDataAndLayout];
  
  return cell;
}

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

@end
