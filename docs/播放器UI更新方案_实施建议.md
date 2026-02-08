# 播放器 UI 更新方案 - 实施建议文档

> 创建日期: 2026-02-07  
> 目标: 实现播放歌曲时，播放器界面（图片、歌曲信息、按钮状态）的实时同步更新

---

## 推荐方案概述

采用 **NSNotificationCenter 通知机制** 实现 Model 层与 UI 层的解耦通信。

### 为什么选择这个方案？

| 评估维度 | NSNotificationCenter | KVO | Delegate | Combine/Rx |
|---------|---------------------|-----|----------|------------|
| 与单例模式适配 | ⭐⭐⭐ 完美适配 | ⭐⭐ 需额外处理 | ⭐ 增加耦合 | ⭐⭐ 需桥接 |
| 一对多广播 | ⭐⭐⭐ 原生支持 | ⭐⭐ 需额外封装 | ⭐ 手动管理 | ⭐⭐⭐ 支持 |
| OC 兼容性 | ⭐⭐⭐ 原生支持 | ⭐⭐⭐ 原生支持 | ⭐⭐⭐ 原生支持 | ⭐ 需 Swift |
| 实现复杂度 | ⭐ 简单 | ⭐⭐ 中等 | ⭐⭐ 中等 | ⭐⭐⭐ 复杂 |
| 风险等级 | 🟢 低 | 🟡 中（野指针） | 🟢 低 | 🟡 中（新依赖） |

**结论**: NSNotificationCenter 最适合当前项目架构（MVVM + 单例模式）。

---

## 数据流向（修改后）

```
用户点击歌曲
    ↓
XCALbumDetailViewController
    ↓
[XCMusicPlayerModel sharedInstance]
    ↓
nowPlayingSong = song (setter 被调用)
    ↓
┌─────────────────────────────────────┐
│  1. 更新锁屏信息 (updateLockScreenInfo)│
│  2. 发送通知 (postNotificationName:)  │  ← 新增
└─────────────────────────────────────┘
    ↓
    ├───────────────┬───────────────┐
    ↓               ↓               ↓
NSNotificationCenter   NSNotificationCenter   NSNotificationCenter
    ↓                   ↓                     ↓
XCMusicPlayerViewController  XCMusicPlayerAccessoryView  (其他需要更新的UI)
    ↓                         ↓
 更新UI                     更新UI
(歌曲名、图片、按钮)          (底部播放条)
```

---

## 修改清单

### 第一步：定义通知常量（XCMusicPlayerModel.h）

在头文件中定义通知名称常量，便于统一管理：

```objc
// 当前播放歌曲变更通知
extern NSString * const XCMusicPlayerNowPlayingSongDidChangeNotification;
// 播放状态变更通知
extern NSString * const XCMusicPlayerPlaybackStateDidChangeNotification;
```

### 第二步：Model 层发送通知（XCMusicPlayerModel.m）

#### 2.1 在 `setNowPlayingSong:` 中发送歌曲变更通知

```objc
- (void)setNowPlayingSong:(XC_YYSongData *)nowPlayingSong {
    NSLog(@"[PlayerModel] 当前歌曲变更: %@ -> %@", _nowPlayingSong.name ?: @"无", nowPlayingSong.name);
    _nowPlayingSong = nowPlayingSong;
    [self updateLockScreenInfo];
    
    // 新增：发送歌曲变更通知
    [[NSNotificationCenter defaultCenter] postNotificationName:XCMusicPlayerNowPlayingSongDidChangeNotification
                                                        object:self
                                                      userInfo:@{@"song": nowPlayingSong ?: [NSNull null]}];
}
```

#### 2.2 在播放控制方法中发送状态变更通知

```objc
- (void)pauseMusic {
    NSLog(@"[PlayerModel] 暂停播放");
    [self.player pause];
    
    // 新增：发送播放状态变更通知
    [[NSNotificationCenter defaultCenter] postNotificationName:XCMusicPlayerPlaybackStateDidChangeNotification
                                                        object:self
                                                      userInfo:@{@"isPlaying": @NO}];
}

- (void)playMusic {
    NSLog(@"[PlayerModel] 继续播放");
    [self.player play];
    
    // 新增：发送播放状态变更通知
    [[NSNotificationCenter defaultCenter] postNotificationName:XCMusicPlayerPlaybackStateDidChangeNotification
                                                        object:self
                                                      userInfo:@{@"isPlaying": @YES}];
}
```

### 第三步：UI 组件添加配置方法

#### 3.1 XCMusicPlayerView 添加 `configureWithSong:`

```objc
// XCMusicPlayerView.h
- (void)configureWithSong:(XC_YYSongData *)song;

// XCMusicPlayerView.m
- (void)configureWithSong:(XC_YYSongData *)song {
    if (!song) return;
    
    // 更新歌曲名
    self.songNameLabel.text = song.name ?: @"未知歌曲";
    
    // 更新艺术家名称（song.artist 已存在）
    self.artistLabel.text = song.artist ?: @"未知艺术家";
    
    // 使用 SDWebImage 加载专辑封面
    if (song.mainIma) {
        [self.albumImageView sd_setImageWithURL:[NSURL URLWithString:song.mainIma]
                               placeholderImage:[UIImage imageNamed:@"placeholder_cover"]];
    }
    
    // 更新背景渐变色（可选）
    [self updateBackgroundGradient];
}
```

#### 3.2 XCMusicPlayerAccessoryView 添加更新方法

```objc
// XCMusicPlayerAccessoryView.h
- (void)updateWithSong:(XC_YYSongData *)song;
- (void)updatePlayState:(BOOL)isPlaying;

// XCMusicPlayerAccessoryView.m
- (void)updateWithSong:(XC_YYSongData *)song {
    if (!song) return;
    
    self.songNameLabel.text = song.name ?: @"未知歌曲";
    self.artistLabel.text = song.artist ?: @"未知艺术家";
    
    if (song.mainIma) {
        [self.albumImageView sd_setImageWithURL:[NSURL URLWithString:song.mainIma]
                               placeholderImage:[UIImage imageNamed:@"placeholder_cover"]];
    }
}

- (void)updatePlayState:(BOOL)isPlaying {
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithFont:[UIFont boldSystemFontOfSize:20]];
    UIImage *image = isPlaying 
        ? [UIImage systemImageNamed:@"pause.fill" withConfiguration:config]
        : [UIImage systemImageNamed:@"play.fill" withConfiguration:config];
    [self.playButton setImage:image forState:UIControlStateNormal];
}
```

### 第四步：详细播放页面监听通知（XCMusicPlayerViewController）

```objc
// XCMusicPlayerViewController.m

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.musicPlayerModel = [XCMusicPlayerModel sharedInstance];
    
    // 初始化主视图
    self.mainView = [[XCMusicPlayerView alloc] init];
    [self.view addSubview:self.mainView];
    
    // 使用 Masonry 设置约束
    [self.mainView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    
    // 新增：注册通知监听
    [self registerNotifications];
    
    // 新增：如果已有正在播放的歌曲，立即显示
    if (self.musicPlayerModel.nowPlayingSong) {
        [self.mainView configureWithSong:self.musicPlayerModel.nowPlayingSong];
        // 同步播放按钮状态
        BOOL isPlaying = (self.musicPlayerModel.player.timeControlStatus == AVPlayerTimeControlStatusPlaying);
        [self updatePlayButtonState:isPlaying];
    }
}

- (void)dealloc {
    // 新增：移除通知监听（防止内存泄漏）
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - 通知注册

- (void)registerNotifications {
    // 监听歌曲变更
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleNowPlayingSongDidChange:)
                                                 name:XCMusicPlayerNowPlayingSongDidChangeNotification
                                               object:nil];
    
    // 监听播放状态变更
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handlePlaybackStateDidChange:)
                                                 name:XCMusicPlayerPlaybackStateDidChangeNotification
                                               object:nil];
}

#pragma mark - 通知处理

- (void)handleNowPlayingSongDidChange:(NSNotification *)notification {
    XC_YYSongData *song = notification.userInfo[@"song"];
    if ([song isKindOfClass:[NSNull class]]) song = nil;
    
    // 主线程更新 UI
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.mainView configureWithSong:song];
    });
}

- (void)handlePlaybackStateDidChange:(NSNotification *)notification {
    BOOL isPlaying = [notification.userInfo[@"isPlaying"] boolValue];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updatePlayButtonState:isPlaying];
    });
}

- (void)updatePlayButtonState:(BOOL)isPlaying {
    self.isPlaying = isPlaying;
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithFont:[UIFont boldSystemFontOfSize:40]];
    UIImage *image = isPlaying
        ? [UIImage systemImageNamed:@"pause.fill" withConfiguration:config]
        : [UIImage systemImageNamed:@"play.fill" withConfiguration:config];
    [self.mainView.playOrStopButton setImage:image forState:UIControlStateNormal];
    
    // 更新专辑图片动画
    if (isPlaying) {
        [self.mainView letAlbumImageBig];
    } else {
        [self.mainView letAlbumImageSmall];
    }
}

#pragma mark - 按钮响应方法

- (void)pressPlayOrStopButton {
    // 修改：直接调用 Model 的方法，由 Model 发送通知更新 UI
    if (self.musicPlayerModel.player.timeControlStatus == AVPlayerTimeControlStatusPlaying) {
        [self.musicPlayerModel pauseMusic];
    } else {
        [self.musicPlayerModel playMusic];
    }
}
```

### 第五步：底部播放条监听通知（MainTabBarController）

```objc
// MainTabBarController.m

@interface MainTabBarController ()
@property (nonatomic, strong) XCMusicPlayerAccessoryView *accessoryView;
@end

@implementation MainTabBarController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // ... 其他初始化代码 ...
    
    // 初始化底部播放条
    self.accessoryView = [[XCMusicPlayerAccessoryView alloc] init];
    // ... 添加约束 ...
    
    // 新增：注册通知监听
    [self registerNotifications];
    
    // 新增：同步当前播放状态
    XCMusicPlayerModel *model = [XCMusicPlayerModel sharedInstance];
    if (model.nowPlayingSong) {
        [self.accessoryView updateWithSong:model.nowPlayingSong];
        BOOL isPlaying = (model.player.timeControlStatus == AVPlayerTimeControlStatusPlaying);
        [self.accessoryView updatePlayState:isPlaying];
    }
}

- (void)dealloc {
    // 新增：移除通知监听
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)registerNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleNowPlayingSongDidChange:)
                                                 name:XCMusicPlayerNowPlayingSongDidChangeNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handlePlaybackStateDidChange:)
                                                 name:XCMusicPlayerPlaybackStateDidChangeNotification
                                               object:nil];
}

- (void)handleNowPlayingSongDidChange:(NSNotification *)notification {
    XC_YYSongData *song = notification.userInfo[@"song"];
    if ([song isKindOfClass:[NSNull class]]) song = nil;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.accessoryView updateWithSong:song];
    });
}

- (void)handlePlaybackStateDidChange:(NSNotification *)notification {
    BOOL isPlaying = [notification.userInfo[@"isPlaying"] boolValue];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.accessoryView updatePlayState:isPlaying];
    });
}

@end
```

### 第六步：更新锁屏信息（XCMusicPlayerModel.m）

数据结构已包含 `artist` 和 `albumName`，更新锁屏信息代码：

```objc
// XCMusicPlayerModel.m 中的 updateLockScreenInfo 方法
- (void)updateLockScreenInfo {
    NSLog(@"[PlayerModel] 更新锁屏信息...");
    MPNowPlayingInfoCenter *infoCenter = [MPNowPlayingInfoCenter defaultCenter];
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];

    // 使用真实的歌曲数据
    [dict setObject:(self.nowPlayingSong.name ?: @"未知标题") forKey:MPMediaItemPropertyTitle];
    [dict setObject:(self.nowPlayingSong.artist ?: @"未知艺术家") forKey:MPMediaItemPropertyArtist];
    [dict setObject:(self.nowPlayingSong.albumName ?: @"未知专辑") forKey:MPMediaItemPropertyAlbumTitle];

    NSURL *url = [NSURL URLWithString:self.nowPlayingSong.mainIma];

    // 尝试先找占位图
    UIImage *artworkImage = [UIImage imageNamed:@"placeholder_cover"];

    if (url) {
        NSString *key = [[SDWebImageManager sharedManager] cacheKeyForURL:url];
        // 同时查找内存和磁盘 (Disk)
        UIImage *cachedImage = [[SDImageCache sharedImageCache] imageFromDiskCacheForKey:key];

        if (cachedImage) {
            artworkImage = cachedImage;
            NSLog(@"[PlayerModel] 使用缓存的专辑封面");
        } else {
            NSLog(@"[PlayerModel] 未找到专辑封面缓存");
        }
    }

    if (artworkImage) {
        MPMediaItemArtwork *artwork = [[MPMediaItemArtwork alloc] initWithBoundsSize:artworkImage.size requestHandler:^UIImage * _Nonnull(CGSize size) {
            return artworkImage;
        }];
        [dict setObject:artwork forKey:MPMediaItemPropertyArtwork];
    }
    
    // 使用真实时长
    NSTimeInterval duration = self.nowPlayingSong.duration / 1000.0; // 毫秒转秒
    NSTimeInterval currentTime = CMTimeGetSeconds(self.player.currentTime);
    
    [dict setObject:@(duration) forKey:MPMediaItemPropertyPlaybackDuration];
    [dict setObject:@(currentTime) forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];
    
    // 根据播放状态设置 rate
    BOOL isPlaying = (self.player.timeControlStatus == AVPlayerTimeControlStatusPlaying);
    [dict setObject:@(isPlaying ? 1.0 : 0.0) forKey:MPNowPlayingInfoPropertyPlaybackRate];

    [infoCenter setNowPlayingInfo:dict];
    NSLog(@"[PlayerModel] 锁屏信息更新完成: %@ - %@", self.nowPlayingSong.name, self.nowPlayingSong.artist);
}
```

---

## 修改文件清单

| 序号 | 文件路径 | 修改类型 | 修改内容 |
|-----|---------|---------|---------|
| 1 | `XCMusicPlayerModel.h` | 新增 | 通知常量定义 |
| 2 | `XCMusicPlayerModel.m` | 修改 | 在 setter 和播放控制方法中发送通知；更新锁屏信息使用真实数据 |
| 3 | `XCMusicPlayerView.h/m` | 新增 | `configureWithSong:` 方法（使用 song.artist） |
| 4 | `XCMusicPlayerViewController.m` | 修改 | 注册通知监听、实现处理方法、修改按钮响应 |
| 5 | `MainTabBarController.m` | 修改 | 持有 accessoryView 引用、注册通知监听 |
| 6 | `XCMusicPlayerAccessoryView.h/m` | 新增 | `updateWithSong:` 和 `updatePlayState:` 方法（使用 song.artist） |

---

## 关键注意事项

### ⚠️ 内存管理

**必须**在 `dealloc` 中移除通知监听，否则会造成内存泄漏：

```objc
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
```

### ⚠️ 线程安全

UI 更新必须确保在主线程执行：

```objc
dispatch_async(dispatch_get_main_queue(), ^{
    // UI 更新代码
});
```

### ⚠️ 初始状态

`XCMusicPlayerViewController` 打开时，如果已有正在播放的歌曲，应立即显示：

```objc
if (self.musicPlayerModel.nowPlayingSong) {
    [self.mainView configureWithSong:self.musicPlayerModel.nowPlayingSong];
}
```

### ⚠️ SDWebImage 导入

使用 SDWebImage 加载图片需要导入头文件：

```objc
#import <SDWebImage/SDWebImage.h>
```

---

## 验证清单

修改完成后，请验证以下功能：

- [ ] 点击歌曲后，详细播放器页面显示正确的歌曲名和艺术家
- [ ] 点击歌曲后，详细播放器页面加载并显示专辑图片
- [ ] 点击歌曲后，底部播放条同步更新歌曲信息（含艺术家）
- [ ] 播放/暂停按钮状态与实际播放状态一致
- [ ] 在详细页面切换播放状态，底部播放条按钮同步更新
- [ ] 在底部播放条切换播放状态，详细页面按钮同步更新
- [ ] 连续播放多首歌曲，UI 都能正确更新
- [ ] 锁屏界面显示正确的歌曲名、艺术家、专辑名
- [ ] 无内存泄漏（使用 Instruments 检查）

---

## 数据结构说明

当前 `XC-YYSongData` 已包含以下可直接使用的字段：

| 字段名 | 类型 | 说明 |
|-------|------|------|
| `name` | NSString | 歌曲名称 |
| `artist` | NSString | 主艺术家名称（已处理，无值时为"未知艺术家"） |
| `artists` | NSArray | 所有艺术家数组 |
| `albumName` | NSString | 专辑名称（已处理，无值时为"未知专辑"） |
| `mainIma` | NSString | 专辑封面 URL |
| `duration` | NSInteger | 歌曲时长（毫秒） |
| `durationText` | NSString | 格式化时长（只读，如 "03:46"） |
| `songId` | NSString | 歌曲 ID |

---

## 备选方案（可选进阶）

如果未来需要更复杂的响应式需求，可以考虑：

### 方案 B: KVO 模式

```objc
// Model 层
@property (nonatomic, strong, readonly) XC_YYSongData *nowPlayingSong;

// UI 层注册 KVO
[self.musicPlayerModel addObserver:self 
                        forKeyPath:@"nowPlayingSong" 
                           options:NSKeyValueObservingOptionNew 
                           context:nil];
```

**适用场景**: 需要精确监听某个属性变化的时机。

### 方案 C: Delegate 模式

```objc
@protocol XCMusicPlayerModelDelegate <NSObject>
- (void)musicPlayerModel:(XCMusicPlayerModel *)model didChangeNowPlayingSong:(XC_YYSongData *)song;
- (void)musicPlayerModel:(XCMusicPlayerModel *)model didChangePlaybackState:(BOOL)isPlaying;
@end
```

**适用场景**: 只有单个 UI 需要响应，或需要更严格的类型检查。

---

## 参考资源

- [NSNotificationCenter - Apple Developer](https://developer.apple.com/documentation/foundation/nsnotificationcenter)
- [SDWebImage GitHub](https://github.com/SDWebImage/SDWebImage)
- 项目 AGENTS.md 中关于 MVVM 架构和单例模式的说明
- `XC-YYSongData.h/mm` 数据结构定义
