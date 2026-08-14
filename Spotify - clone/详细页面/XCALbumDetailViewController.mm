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

  // 监听 URL 获取失败通知，弹框告知用户
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(handleURLFetchFailed:)
                                               name:XCMusicPlayerURLFetchFailedNotification
                                             object:nil];
}


#pragma mark - UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return self.model.playerList.count + 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

  if (indexPath.row == 0) {
    XCAlbumHeadCell* cell = [tableView dequeueReusableCellWithIdentifier:@"XCAlbumHeadCell"];
    
    // 封面始终使用第一首歌的封面
    NSString *coverUrl = nil;
    if (self.model.playerList.count > 0) {
        coverUrl = self.model.playerList.firstObject.mainIma;
    }
    
    // 重置封面状态：先清除旧图片，避免复用时显示旧封面
    [cell.albumImageView sd_cancelCurrentImageLoad];
    cell.albumImageView.image = nil;
    cell.albumImageView.backgroundColor = [UIColor systemGray5Color];
    
    if (coverUrl && coverUrl.length > 0) {
        NSURL* url = [NSURL URLWithString:coverUrl];
        SDWebImageOptions options = SDWebImageRetryFailed | 
                                    SDWebImageLowPriority | 
                                    SDWebImageAvoidDecodeImage |
                                    SDWebImageScaleDownLargeImages;
        
        // 创建图片压缩 Transformer，压缩到 400x400 像素
        id<SDImageTransformer> transformer = [SDImageResizingTransformer transformerWithSize:CGSizeMake(400, 400) 
                                                                                   scaleMode:SDImageScaleModeAspectFill];
        SDWebImageContext *context = @{SDWebImageContextImageTransformer: transformer};
        
        [cell.albumImageView sd_setImageWithURL:url
                              placeholderImage:nil
                                       options:options
                                       context:context
                                      progress:nil
                                     completed:^(UIImage * _Nullable image, NSError * _Nullable error, SDImageCacheType cacheType, NSURL * _Nullable imageURL) {
          // 回调中无需额外处理，SDWebImage 已设置图片
        }];
    }
    
    cell.titleLabel.text = self.model.playerlistName;
    // 更新歌曲数量显示
    cell.refreshDateLabel.text = [NSString stringWithFormat:@"%lu 首歌曲", (unsigned long)self.model.playerList.count];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    __weak typeof(self) weakSelf = self;

    // 播放按钮：顺序播放，从第一首开始
    cell.onPlayButtonTapped = ^{
        if (!weakSelf.model.playerList.count) return;
        XCMusicPlayerModel *m = [XCMusicPlayerModel sharedInstance];
        m.playerlist = weakSelf.model.playerList;
        m.playMode = XCPlayModeSequential;
        XC_YYSongData *first = weakSelf.model.playerList.firstObject;
        m.nowPlayingSong = first;
        [m playMusicWithId:first.songId];
    };

    // 随机播放按钮：开启随机模式，从随机一首开始
    cell.onShuffleButtonTapped = ^{
        if (!weakSelf.model.playerList.count) return;
        XCMusicPlayerModel *m = [XCMusicPlayerModel sharedInstance];
        m.playerlist = weakSelf.model.playerList;
        m.playMode = XCPlayModeShuffle;
        NSUInteger randomIdx = arc4random_uniform((uint32_t)weakSelf.model.playerList.count);
        XC_YYSongData *randomSong = weakSelf.model.playerList[randomIdx];
        m.nowPlayingSong = randomSong;
        [m playMusicWithId:randomSong.songId];
    };

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
  __weak typeof(cell) weakCell = cell;
  SDWebImageOptions options = SDWebImageRetryFailed | 
                              SDWebImageLowPriority | 
                              SDWebImageAvoidDecodeImage |
                              SDWebImageScaleDownLargeImages;
  
  // 创建图片压缩 Transformer，压缩到 150x150 像素
  id<SDImageTransformer> transformer = [SDImageResizingTransformer transformerWithSize:CGSizeMake(150, 150) 
                                                                             scaleMode:SDImageScaleModeAspectFill];
  SDWebImageContext *context = @{SDWebImageContextImageTransformer: transformer};
  
  [cell.mainImageView sd_setImageWithURL:url
                        placeholderImage:nil
                                 options:options
                                 context:context
                                progress:nil
                               completed:^(UIImage * _Nullable image, NSError * _Nullable error, SDImageCacheType cacheType, NSURL * _Nullable imageURL) {
    if (image && weakCell) {
      weakCell.mainImageView.image = image;
    }
  }];
  cell.songId = song.songId;
  cell.songLabel.text = song.name;
  cell.authorLabel.text = song.artist;
  cell.durationLabel.text = song.durationText;

  cell.menuButton.menu = [self menuForSong:song];
  cell.menuButton.showsMenuAsPrimaryAction = YES;
}

- (UIMenu *)menuForSong:(XC_YYSongData *)song {
    BOOL isLiked = [[XCPlaylistDatabaseManager sharedInstance]
                    isSong:song.songId inPlaylist:@"favorites"];
    NSString *likeTitle = isLiked ? @"从喜爱的歌曲移除" : @"加入喜爱的歌曲";
    NSString *likeImageName = isLiked ? @"heart.slash" : @"heart";

    UIAction *likeAction = [UIAction actionWithTitle:likeTitle
                                              image:[UIImage systemImageNamed:likeImageName]
                                         identifier:nil
                                            handler:^(__kindof UIAction *_) {
        if (isLiked) {
            [[XCPlaylistDatabaseManager sharedInstance] removeSong:song.songId fromPlaylist:@"favorites"];
        } else {
            [[XCPlaylistDatabaseManager sharedInstance] addSong:song toPlaylist:@"favorites"];
        }
    }];

    UIMenu *playlistMenu = [self playlistSubmenuForSong:song];
    return [UIMenu menuWithTitle:song.name image:nil identifier:nil
                         options:0 children:@[likeAction, playlistMenu]];
}

- (UIMenu *)playlistSubmenuForSong:(XC_YYSongData *)song {
    NSArray<XC_YYAlbumData *> *playlists =
        [[XCPlaylistDatabaseManager sharedInstance] getAllPlaylistsSortedBy:XCPlaylistSortByUpdateTime];
    NSMutableArray *actions = [NSMutableArray array];
    for (XC_YYAlbumData *playlist in playlists) {
        UIAction *action = [UIAction actionWithTitle:playlist.name image:nil identifier:nil
                                            handler:^(__kindof UIAction *_) {
            BOOL added = [[XCPlaylistDatabaseManager sharedInstance] addSong:song toPlaylist:playlist.albumId];
            if (!added) {
                NSLog(@"[Playlist] 歌曲《%@》已在播放列表《%@》中", song.name, playlist.name);
            }
        }];
        [actions addObject:action];
    }
    return [UIMenu menuWithTitle:@"加入播放列表…"
                           image:[UIImage systemImageNamed:@"plus"]
                      identifier:nil options:0 children:actions];
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
  XC_YYSongData *song = self.model.playerList[indexPath.row - 1];
  NSLog(@"点击歌曲为%@，id信息为%@", song.name, song.songId);

  // 先设置播放列表，再设置当前歌曲，最后触发播放
  // 确保 playMusicWithId 内部调用 playNextSong 时能取到正确的列表
  [XCMusicPlayerModel sharedInstance].playerlist = self.model.playerList;
  [XCMusicPlayerModel sharedInstance].nowPlayingSong = song;
  [[XCMusicPlayerModel sharedInstance] playMusicWithId:song.songId];

}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView 
trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    // 第 0 行是表头，不支持侧滑删除
    if (indexPath.row == 0) {
        return nil;
    }
    
    // 如果没有 playlistId（例如在线歌单），不支持删除
    if (self.model.playlistId.length == 0) {
        return nil;
    }
    
    XC_YYSongData *song = self.model.playerList[indexPath.row - 1];
    
    UIContextualAction *deleteAction = [UIContextualAction 
        contextualActionWithStyle:UIContextualActionStyleDestructive 
        title:@"删除" 
        handler:^(UIContextualAction *action, UIView *sourceView, 
                 void (^completionHandler)(BOOL)) {
            
            // 从数据库删除歌曲与播放列表的关联
            BOOL success = [[XCPlaylistDatabaseManager sharedInstance] 
                           removeSong:song.songId fromPlaylist:self.model.playlistId];
            
            if (success) {
                // 从数组中移除
                [self.model.playerList removeObjectAtIndex:indexPath.row - 1];
                // 使用 batchUpdates 同时处理删除和表头刷新
                [tableView performBatchUpdates:^{
                    // 删除歌曲行
                    [tableView deleteRowsAtIndexPaths:@[indexPath] 
                                     withRowAnimation:UITableViewRowAnimationAutomatic];
                    // 刷新表头（更新封面和歌曲数量）
                    NSIndexPath *headerIndexPath = [NSIndexPath indexPathForRow:0 inSection:0];
                    [tableView reloadRowsAtIndexPaths:@[headerIndexPath] 
                                     withRowAnimation:UITableViewRowAnimationNone];
                } completion:nil];
            }
            
            completionHandler(success);
        }];
    
    return [UISwipeActionsConfiguration configurationWithActions:@[deleteAction]];
}

- (void) testCell:(XCAlbumDetailCell*) cell {
  cell.mainImageView.image = [UIImage imageNamed:@"test.jpg"];
  cell.songLabel.text = @"Deadman's Gun";
  cell.authorLabel.text = @"Ashtar Command";
}

#pragma mark - URL 获取失败处理

- (void)handleURLFetchFailed:(NSNotification *)notification {
  NSString *songName = notification.userInfo[@"songName"] ?: @"该歌曲";
  NSString *msg = [NSString stringWithFormat:@"《%@》暂时无法播放，已自动跳至下一首", songName];
  dispatch_async(dispatch_get_main_queue(), ^{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"无法播放"
                                                                   message:msg
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
  });
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
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
