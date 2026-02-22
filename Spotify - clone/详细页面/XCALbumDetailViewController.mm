//
//  XCALbumDetailViewController.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/12/9.
//

#import "XCALbumDetailViewController.h"

#import "XCAlbumDetailCell.h"
#import "XCAlbumHeadCell.h"

#import "XCMusicPlayerModel.h"
#import "XCPlaylistDatabaseManager.h"

#import <Masonry/Masonry.h>
#import <SDWebImage/SDWebImage.h>

@interface XCALbumDetailViewController () <UITableViewDelegate, UITableViewDataSource>

@end

@implementation XCALbumDetailViewController
#pragma mark - lifeCycle
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
  //设置封面图
//  NSURL* url = [NSURL URLWithString:self.model.mainImaUrl];
//  [self.mainView.albumImageView sd_setImageWithURL:url];


  [self.view addSubview:self.mainView];

  // 设置 tableView 代理和数据源
  self.mainView.tableView.delegate = self;
  self.mainView.tableView.dataSource = self;

  // 注册cell
  [self.mainView.tableView registerClass:[XCAlbumHeadCell class] forCellReuseIdentifier:@"XCAlbumHeadCell"];
  [self.mainView.tableView registerClass:[XCAlbumDetailCell class] forCellReuseIdentifier:@"XCAlbumDetailCell"];

  // 设置约束 - 填充整个视图
  [self.mainView mas_makeConstraints:^(MASConstraintMaker *make) {
    make.edges.equalTo(self.view);
  }];

}


#pragma mark - UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return self.model.playerList.count + 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

  if (indexPath.row == 0) {
    XCAlbumHeadCell* cell = [tableView dequeueReusableCellWithIdentifier:@"XCAlbumHeadCell"];
    NSURL* url = [NSURL URLWithString:self.model.mainImaUrl];
    [cell.albumImageView sd_setImageWithURL:url
                          placeholderImage:nil
                                   options:SDWebImageRetryFailed | SDWebImageLowPriority
                                 completed:^(UIImage * _Nullable image, NSError * _Nullable error, SDImageCacheType cacheType, NSURL * _Nullable imageURL) {
      if (image) {
        cell.albumImageView.image = image;
      }
    }];
    cell.titleLabel.text = self.model.playerlistName;
    cell.refreshDateLabel.text = self.model.timeStr;
    // 测试
    cell.refreshDateLabel.text = @"一周前";
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
  } else {
    XCAlbumDetailCell *cell = [tableView dequeueReusableCellWithIdentifier:@"XCAlbumDetailCell"];
    if (cell) {
      [self giveData:self.model.playerList[indexPath.row - 1] ToCell:cell];
    }
    return cell;
  }
}

- (void)giveData: (XC_YYSongData*) song ToCell: (XCAlbumDetailCell*) cell {
  NSURL* url = [NSURL URLWithString:song.mainIma];
  [cell.mainImageView sd_setImageWithURL:url
                        placeholderImage:nil
                                 options:SDWebImageRetryFailed | SDWebImageLowPriority
                               completed:^(UIImage * _Nullable image, NSError * _Nullable error, SDImageCacheType cacheType, NSURL * _Nullable imageURL) {
    if (image) {
      cell.mainImageView.image = image;
    }
  }];
  cell.songId = song.songId;
  cell.songLabel.text = song.name;
  cell.authorLabel.text = song.artist;
  cell.durationLabel.text = song.durationText;

  // 菜单按钮回调
  __weak typeof(self) weakSelf = self;
  cell.menuButtonBlock = ^(NSString *songId) {
      [weakSelf showMenuForSong:song];
  };
}

- (void)showMenuForSong:(XC_YYSongData *)song {
    UIAlertController *sheet = [UIAlertController
        alertControllerWithTitle:song.name
                         message:nil
                  preferredStyle:UIAlertControllerStyleActionSheet];

    BOOL isLiked = [[XCPlaylistDatabaseManager sharedInstance]
                    isSong:song.songId inPlaylist:@"favorites"];
    NSString *likeTitle = isLiked ? @"从喜爱的歌曲移除" : @"加入喜爱的歌曲";

    [sheet addAction:[UIAlertAction actionWithTitle:likeTitle
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *action) {
        if (isLiked) {
            [[XCPlaylistDatabaseManager sharedInstance]
                removeSong:song.songId fromPlaylist:@"favorites"];
        } else {
            [[XCPlaylistDatabaseManager sharedInstance]
                addSong:song toPlaylist:@"favorites"];
        }
    }]];

    __weak typeof(self) weakSelf = self;
    [sheet addAction:[UIAlertAction actionWithTitle:@"加入播放列表…"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *action) {
        [weakSelf showPlaylistPickerForSong:song];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"取消"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];

    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)showPlaylistPickerForSong:(XC_YYSongData *)song {
    NSArray<XC_YYAlbumData *> *playlists =
        [[XCPlaylistDatabaseManager sharedInstance]
            getAllPlaylistsSortedBy:XCPlaylistSortByUpdateTime];

    UIAlertController *picker = [UIAlertController
        alertControllerWithTitle:@"选择播放列表"
                         message:nil
                  preferredStyle:UIAlertControllerStyleActionSheet];

    for (XC_YYAlbumData *playlist in playlists) {
        [picker addAction:[UIAlertAction actionWithTitle:playlist.name
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *action) {
            BOOL added = [[XCPlaylistDatabaseManager sharedInstance]
                          addSong:song toPlaylist:playlist.albumId];
            if (!added) {
                NSLog(@"[Playlist] 歌曲《%@》已在播放列表《%@》中", song.name, playlist.name);
            }
        }]];
    }

    [picker addAction:[UIAlertAction actionWithTitle:@"取消"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    [self presentViewController:picker animated:YES completion:nil];
}
- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
  if (indexPath.row == 0) {
    return 464.47;
  }
  return 60;
}

#pragma mark - UITableViewDelegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  if (indexPath.row == 0) {
    return;
  }
  [tableView deselectRowAtIndexPath:indexPath animated:YES];
  NSLog(@"点击歌曲为%@，id信息为%@",self.model.playerList[indexPath.row - 1].name, self.model.playerList[indexPath.row - 1 ].songId);
  [XCMusicPlayerModel sharedInstance].nowPlayingSong = self.model.playerList[indexPath.row - 1];

  [[XCMusicPlayerModel sharedInstance]playMusicWithId:self.model.playerList[indexPath.row - 1].songId];
  // 传入播放列表
  [XCMusicPlayerModel sharedInstance].playerlist = self.model.playerList;

}

- (void) testCell:(XCAlbumDetailCell*) cell {
  cell.mainImageView.image = [UIImage imageNamed:@"test.jpg"];
  cell.songLabel.text = @"Deadman's Gun";
  cell.authorLabel.text = @"Ashtar Command";
}

#pragma mark - 测试方法
- (void) testView {
  self.mainView.albumImageView.image = [UIImage imageNamed:@"testImage2.jpg"];
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
