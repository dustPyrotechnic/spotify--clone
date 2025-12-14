//
//  XCALbumDetailViewController.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/12/9.
//

#import "XCALbumDetailViewController.h"

#import <Masonry/Masonry.h>

@interface XCALbumDetailViewController () <UITableViewDelegate, UITableViewDataSource>

@end

@implementation XCALbumDetailViewController
- (instancetype) init {
  self = [super init];
  if (self) {
    self.model = [[XCALbumDetailModel alloc] init];
  }
  return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
  self.view.backgroundColor = [UIColor systemBackgroundColor];
  
  self.mainView = [[XCALbumDetailView alloc] init];
  [self.view addSubview:self.mainView];
  
  // 设置 tableView 代理和数据源
  self.mainView.tableView.delegate = self;
  self.mainView.tableView.dataSource = self;
  
  // 设置约束 - 填充整个视图
  [self.mainView mas_makeConstraints:^(MASConstraintMaker *make) {
    make.edges.equalTo(self.view);
  }];

}

- (void) testView {
  self.mainView.albumImageView.image = [UIImage imageNamed:@"testImage2.jpg"];
}

#pragma mark - UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  // TODO: 返回实际歌曲数量
  return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  // TODO: 创建并配置歌曲列表 cell
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TrackCell"];
  if (!cell) {
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"TrackCell"];
    cell.backgroundColor = [UIColor clearColor];
    cell.textLabel.textColor = [UIColor labelColor];
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
  }
  return cell;
}

#pragma mark - UITableViewDelegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  [tableView deselectRowAtIndexPath:indexPath animated:YES];
  // TODO: 处理歌曲点击事件，开始播放
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
