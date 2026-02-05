//
//  XCPersonalViewController.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/1.
//

#import "XCPersonalViewController.h"


#import <Masonry/Masonry.h>
#import <SDWebImage/SDWebImage.h>

@interface XCPersonalViewController ()

@end

@implementation XCPersonalViewController
- (instancetype) init {
  self = [super init];
  if (self) {
    self.model = [[XCPersonalModel alloc] init];
  }
  return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
  self.mainView = [[XCPersonalView alloc] init];

  self.mainView.tableView.delegate = self;
  self.mainView.tableView.dataSource = self;
  [self.mainView.tableView registerClass:[XCPersonalTableViewCell class] forCellReuseIdentifier:@"XCPersonalTableViewCell"];

  [self.view addSubview:self.mainView];
  [self.mainView mas_makeConstraints:^(MASConstraintMaker *make) {
    make.size.mas_equalTo(self.view);
    make.center.mas_equalTo(self.view);
  }];

//  self.navigationItem.title = @"播放列表";




}
#pragma mark TableView
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return 1;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  // 测试数字
  return 20;
//  return self.model.personalAlbumArray.count;
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
  return 100;
}
- (UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  XCPersonalTableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"XCPersonalTableViewCell"];
  cell.titleLabel.text = @"喜爱的歌曲";
  cell.mainImageView.image = [UIImage imageNamed:@"testImage.jpg"];

  cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
  return cell;
}
- (UIView*) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
  NSArray* heightArray = @[@50,@40,@30,@30,@40];
  NSArray* titleArray = @[@"播放列表",
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
  NSArray* heightArray = @[@40,@40,@30,@30,@40];
  NSInteger safeSection = MIN(section, heightArray.count - 1);
  return (CGFloat)[heightArray[safeSection] integerValue];
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
