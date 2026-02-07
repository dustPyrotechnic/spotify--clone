# XC-YYSongData 关联代码修改清单

> 说明：修改 XC-YYSongData 数据结构后，以下文件需要做相应更改

---

## 一、必须修改（硬编码替换）

### 1. XCALbumDetailViewController.m

**位置**：`giveData:ToCell:` 方法（约第 106 行）

**当前代码**：
```objc
cell.authorLabel.text = @"赵本山";  // ← 硬编码
```

**改为**：
```objc
cell.authorLabel.text = song.artist;
```

**位置**：`testCell:` 方法（约第 132-133 行）

**当前代码**：
```objc
cell.songLabel.text = @"Deadman's Gun";      // 测试数据
cell.authorLabel.text = @"Ashtar Command";   // 测试数据
```

**建议**：保持测试方法不变，或也使用 song 参数

---

### 2. XCMusicPlayerView.m

**位置**：`init` 方法（约第 45 行和第 55 行）

**当前代码**：
```objc
self.songNameLabel.text = @"歌曲名称";    // ← 硬编码
self.authorNameLabel.text = @"艺术家";    // ← 硬编码
```

**说明**：这两处是初始化时的默认值。需要添加一个配置方法来更新这些值。

**建议**：添加 `configureWithSong:` 方法（参考之前的文档）

---

### 3. XCMusicPlayerAccessoryView.m

**位置**：`initWithFrame:withImage:andTitle:withSonger:withCondition:` 方法（约第 35 行）

**当前代码**：
```objc
_authorLabel.text = songer;  // 从参数传入，但调用时传的是硬编码
```

**调用位置**：MainTabBarController.m 第 91 行

**当前代码**：
```objc
XCMusicPlayerAccessoryView *musicPayerAccessoryView = [[XCMusicPlayerAccessoryView alloc] 
    initWithFrame:... 
        withImage:[UIImage imageNamed:@"1.jpeg"] 
         andTitle:@"测试歌曲"      // ← 硬编码
       withSonger:@"测试歌手"      // ← 硬编码
    withCondition:NO];
```

**需要**：添加 `updateWithSong:` 方法来更新已创建的视图

---

### 4. XCMusicPlayerModel.m

**位置**：`updateLockScreenInfo` 方法（约第 485-486 行）

**当前代码**：
```objc
[dict setObject:@"测试歌手 - Ed Sheeran" forKey:MPMediaItemPropertyArtist]; // ← 硬编码
[dict setObject:@"测试专辑 - Divide" forKey:MPMediaItemPropertyAlbumTitle]; // ← 硬编码
```

**改为**：
```objc
[dict setObject:(self.nowPlayingSong.artist ?: @"未知艺术家") forKey:MPMediaItemPropertyArtist];
[dict setObject:(self.nowPlayingSong.albumName ?: @"未知专辑") forKey:MPMediaItemPropertyAlbumTitle];
```

---

## 二、需要添加的方法

### 1. XCMusicPlayerView.h / .m

**添加配置方法**：
```objc
/// 使用歌曲数据配置视图
- (void)configureWithSong:(XC_YYSongData *)song;
```

**实现**：
```objc
- (void)configureWithSong:(XC_YYSongData *)song {
    self.songNameLabel.text = song.name ?: @"未知歌曲";
    self.authorNameLabel.text = song.artist ?: @"未知艺术家";
    
    // 加载图片
    NSURL *imageURL = [NSURL URLWithString:song.mainIma];
    [self.albumImage sd_setImageWithURL:imageURL placeholderImage:[UIImage imageNamed:@"testImage.jpg"]];
    
    // 更新背景
    __weak typeof(self) weakSelf = self;
    [self.albumImage sd_setImageWithURL:imageURL 
                       placeholderImage:[UIImage imageNamed:@"testImage.jpg"]
                              completed:^(UIImage * _Nullable image, NSError * _Nullable error, SDImageCacheType cacheType, NSURL * _Nullable imageURL) {
        if (image) {
            weakSelf.image = image;
            [weakSelf setNeedsLayout]; // 更新背景渐变色
        }
    }];
}
```

---

### 2. XCMusicPlayerAccessoryView.h / .m

**添加更新方法**：
```objc
/// 更新视图显示
- (void)updateWithSong:(XC_YYSongData *)song;

/// 更新播放状态
- (void)updatePlayState:(BOOL)isPlaying;
```

**实现**：
```objc
- (void)updateWithSong:(XC_YYSongData *)song {
    self.titleLabel.text = song.name ?: @"未知歌曲";
    self.authorLabel.text = song.artist ?: @"未知艺术家";
    
    NSURL *imageURL = [NSURL URLWithString:song.mainIma];
    [self.imageView sd_setImageWithURL:imageURL placeholderImage:[UIImage imageNamed:@"testImage.jpg"]];
}

- (void)updatePlayState:(BOOL)isPlaying {
    self.isPlaying = isPlaying;
    NSString *imageName = isPlaying ? @"pause.fill" : @"play.fill";
    [self.stopOrContinueButton setImage:[UIImage systemImageNamed:imageName] forState:UIControlStateNormal];
}
```

**修改按钮点击方法**：
```objc
- (void)pressStopOrContinueButton:(UIButton*)sender {
    XCMusicPlayerModel *model = [XCMusicPlayerModel sharedInstance];
    
    if (model.player.timeControlStatus == AVPlayerTimeControlStatusPlaying) {
        [model pauseMusic];
    } else {
        [model playMusic];
    }
}
```

---

### 3. XCMusicPlayerViewController.m

**在 `viewDidLoad` 中添加**：
```objc
// 如果已有正在播放的歌曲，立即更新UI
if (self.musicPlayerModel.nowPlayingSong) {
    [self.mainView configureWithSong:self.musicPlayerModel.nowPlayingSong];
    [self updatePlayButtonState:self.musicPlayerModel.isPlaying];
}
```

**添加通知监听**（如果之前没加）：
```objc
[[NSNotificationCenter defaultCenter] addObserver:self 
                                         selector:@selector(handleNowPlayingSongDidChange:) 
                                             name:XCMusicPlayerNowPlayingSongDidChangeNotification 
                                           object:nil];
```

**添加处理方法**：
```objc
- (void)handleNowPlayingSongDidChange:(NSNotification *)notification {
    XC_YYSongData *song = notification.userInfo[@"song"];
    if (song && ![song isKindOfClass:[NSNull class]]) {
        [self.mainView configureWithSong:song];
    }
}
```

---

### 4. MainTabBarController.m

**修改底部播放条创建代码**（约第 91 行）：

保留原创建代码，但添加对通知的监听：

```objc
// 创建底部播放条（保持不变）
XCMusicPlayerAccessoryView *musicPlayerAccessoryView = [[XCMusicPlayerAccessoryView alloc] 
    initWithFrame:CGRectMake(20, 20, self.view.bounds.size.width - 40, 40) 
        withImage:[UIImage imageNamed:@"1.jpeg"] 
         andTitle:@"未在播放"           // 改为默认提示
       withSonger:@"点击歌曲开始播放"    // 改为默认提示
    withCondition:NO];

// 保存引用（需要添加属性）
self.musicPlayerAccessoryView = musicPlayerAccessoryView;

// 注册通知监听
[[NSNotificationCenter defaultCenter] addObserver:self 
                                         selector:@selector(handleNowPlayingSongDidChange:) 
                                             name:XCMusicPlayerNowPlayingSongDidChangeNotification 
                                           object:nil];
```

**添加属性**（在 @interface 中）：
```objc
@property (nonatomic, strong) XCMusicPlayerAccessoryView *musicPlayerAccessoryView;
```

**添加处理方法**：
```objc
- (void)handleNowPlayingSongDidChange:(NSNotification *)notification {
    XC_YYSongData *song = notification.userInfo[@"song"];
    if (song && ![song isKindOfClass:[NSNull class]]) {
        [self.musicPlayerAccessoryView updateWithSong:song];
    }
}
```

**添加 dealloc**：
```objc
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
```

---

## 三、可选修改

### XCAlbumDetailCell.m

**添加时长显示**（如果 cell 有时长标签）：
```objc
// 在 giveData:ToCell: 中添加
cell.durationLabel.text = song.durationText;
```

---

## 四、文件修改汇总

| 文件 | 修改类型 | 优先级 |
|------|----------|--------|
| XCALbumDetailViewController.m | 替换硬编码 | P0 |
| XCMusicPlayerView.m | 添加配置方法 | P0 |
| XCMusicPlayerView.h | 添加方法声明 | P0 |
| XCMusicPlayerViewController.m | 添加通知监听 | P0 |
| XCMusicPlayerAccessoryView.m | 添加更新方法 + 修改按钮响应 | P0 |
| XCMusicPlayerAccessoryView.h | 添加方法声明 | P0 |
| MainTabBarController.m | 添加通知监听 + 保存引用 | P0 |
| MainTabBarController.h | 添加属性声明 | P0 |
| XCMusicPlayerModel.m | 替换锁屏信息硬编码 | P1 |
| XCMusicPlayerModel.h | 添加通知常量（如未添加） | P0 |

---

## 五、依赖检查

确保以下导入正确：

1. **使用 SDWebImage 的地方**需要导入：
   ```objc
   #import <SDWebImage/SDWebImage.h>
   ```
   
   涉及文件：
   - XCMusicPlayerView.m
   - XCMusicPlayerAccessoryView.m

2. **使用 XC_YYSongData 的地方**需要导入：
   ```objc
   #import "XC-YYSongData.h"
   ```

---

## 六、测试验证

修改完成后，验证以下功能：

- [ ] 进入专辑详情页，歌曲列表显示正确的歌手名（不是"赵本山"）
- [ ] 点击歌曲播放，底部播放条显示正确的歌名和歌手
- [ ] 打开详细播放器页面，显示正确的歌名、歌手、封面
- [ ] 锁屏时显示正确的歌手名和专辑名（不是"测试歌手 - Ed Sheeran"）
- [ ] 播放器进度条显示正确的总时长（格式 "03:46"）
