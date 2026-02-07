//
//  XCMusicPlayerModel.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/12/1.
//

#import "XCMusicPlayerModel.h"

#import "XCNetworkManager.h"
#import "XCResourceLoaderManager.h"
#import "XCMusicMemoryCache.h"

#import <UICKeyChainStore/UICKeyChainStore.h>
#import <AFNetworking/AFNetworking.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <SDWebImage/SDWebImage.h>
#import <objc/message.h>

@implementation XCMusicPlayerModel
#pragma mark - 单例模式代码
static XCMusicPlayerModel *instance = nil;
// 在 +load 方法中创建单例实例
+ (void)load {
    NSLog(@"[PlayerModel] ✅ 单例初始化");
    instance = [[super allocWithZone:NULL] init];
}
// 饿汉模式的全局访问点
+ (instancetype)sharedInstance {
    return instance;
}
// 重写 allocWithZone: 方法，确保无法通过 alloc 直接创建新实例
+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    // 直接返回已经创建好的单例实例
    return [self sharedInstance];
}
// 重写 copy 和 mutableCopy 方法，防止实例被复制
- (id)copyWithZone:(NSZone *)zone {
    return self;
}
- (id)mutableCopyWithZone:(NSZone *)zone {
    return self;
}
- (instancetype) init {
    NSLog(@"[PlayerModel] 🎵 播放器初始化");
    self = [super init];
    [self signUpAVAudioSession];
    [self setupRemoteCommands];
    return self;
}
- (void)setNowPlayingSong:(XC_YYSongData *)nowPlayingSong {
    NSLog(@"[PlayerModel] 🎵 当前歌曲变更: %@ -> %@", _nowPlayingSong.name ?: @"无", nowPlayingSong.name);
    _nowPlayingSong = nowPlayingSong;
    [self updateLockScreenInfo];
}
#pragma mark - 音乐测试播放部分代码
- (void)testPlaySpotifySong {
    // 1. 使用搜索查询 (Ed Sheeran - Shape of You)
    // 根据网络上的解决方案，使用 search 端点可以获取到 preview_url
    NSString *const searchQuery = @"Never Gonna Give You Up";

    NSString *accessToken = [UICKeyChainStore stringForKey:@"token" service:@"com.spotify.clone"];

    if (!accessToken || accessToken.length == 0) {
        NSLog(@"错误: Keychain 里没找到 Token 或 Token 为空！");
        NSLog(@"提示: 请先确保 getTokenWithCompletion 成功完成");
        return;
    }

    NSLog(@"从 Keychain 读取到 Token，长度: %lu", (unsigned long)accessToken.length);

    // 3. 准备 AFNetworking 请求 - 使用 search 端点替代 tracks 端点
    NSString *urlString = @"https://api.spotify.com/v1/search";
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];

    // 确保响应序列化器支持 JSON
    manager.responseSerializer = [AFJSONResponseSerializer serializer];
    manager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript", @"text/html", nil];

    // 设置 Bearer Token
    NSString *authHeader = [NSString stringWithFormat:@"Bearer %@", accessToken];
    [manager.requestSerializer setValue:authHeader forHTTPHeaderField:@"Authorization"];

    // 设置搜索参数 - 增加 limit 以便找到有 preview_url 的歌曲
    NSDictionary *params = @{
        @"q": searchQuery,
        @"type": @"track",
        @"limit": @20  // 增加到 20，提高找到有 preview_url 的歌曲的概率
    };

    NSLog(@"开始请求 Spotify Search API...");
    NSLog(@"搜索关键词: %@", searchQuery);
    NSLog(@"URL: %@", urlString);

    // 4. 发送 GET 请求
    __weak typeof(self) weakSelf = self; // 防止 Block 循环引用
    [manager GET:urlString
      parameters:params
         headers:nil
        progress:nil
         success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        NSLog(@"Spotify API 请求成功");

        // 解析数据 - search 端点返回的数据结构不同
        if (![responseObject isKindOfClass:[NSDictionary class]]) {
            NSLog(@"响应数据格式错误，不是字典类型");
            return;
        }

        NSDictionary *json = (NSDictionary *)responseObject;
        NSDictionary *tracksDict = json[@"tracks"];

        if (!tracksDict || ![tracksDict isKindOfClass:[NSDictionary class]]) {
            NSLog(@"tracks 数据不存在或格式错误");
            NSLog(@"响应数据: %@", json);
            return;
        }

        NSArray *items = tracksDict[@"items"];

        if (!items || items.count == 0) {
            NSLog(@"搜索未找到任何歌曲");
            NSLog(@"响应数据: %@", json);
            return;
        }

        NSLog(@"找到 %lu 首歌曲", (unsigned long)items.count);

        // 遍历搜索结果，找到第一个有 preview_url 的歌曲
        BOOL foundPlayableTrack = NO;
        for (NSDictionary *trackData in items) {
            NSString *previewUrl = trackData[@"preview_url"];
            NSString *songName = trackData[@"name"] ?: @"未知歌曲";
            NSString *artistName = @"";
            NSArray *artists = trackData[@"artists"];
            if (artists && artists.count > 0) {
                artistName = artists[0][@"name"] ?: @"未知艺术家";
            }

            // 检查是否有预览链接
            if (previewUrl && ![previewUrl isKindOfClass:[NSNull class]] && previewUrl.length > 0) {
                NSLog(@"找到可播放的歌曲: %@ - %@", artistName, songName);
                NSLog(@"Preview URL: %@", previewUrl);

                // 初始化播放器并播放
                NSURL *url = [NSURL URLWithString:previewUrl];
                weakSelf.player = [AVPlayer playerWithURL:url];
                [weakSelf.player play];

                foundPlayableTrack = YES;
                break; // 找到就退出循环
            } else {
                NSLog(@"跳过: %@ - %@ (无 preview_url)", artistName, songName);
            }
        }

        if (!foundPlayableTrack) {
            NSLog(@"搜索到的所有歌曲都没有 preview_url");
            NSLog(@"提示: 这可能是因为版权限制或地区限制，尝试搜索其他歌曲");
        }

    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        // 打印详细错误，方便你看是不是 401 (Token 过期)
        NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
        NSInteger statusCode = response ? response.statusCode : 0;
        NSLog(@"Spotify API 请求失败");
        NSLog(@"状态码: %ld", (long)statusCode);
        NSLog(@"错误描述: %@", error.localizedDescription);
        NSLog(@"错误详情: %@", error.userInfo);

        if (statusCode == 401) {
            NSLog(@"Token 可能已过期或无效，需要重新获取");
        } else if (statusCode == 0) {
            NSLog(@"可能是网络连接问题，请检查网络设置");
        }
    }];
}
// 第二个测试方法
- (void)testPlaySpotifySong2 {
    // 直接使用url播放音频
    // url为https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview122/v4/72/a3/ab/72a3ab79-0066-f773-6618-7a53adc250b3/mzaf_17921540907592750976.plus.aac.p.m4a
    NSURL *url = [NSURL URLWithString:@"https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview122/v4/72/a3/ab/72a3ab79-0066-f773-6618-7a53adc250b3/mzaf_17921540907592750976.plus.aac.p.m4a"];
    self.player = [AVPlayer playerWithURL:url];
    [self.player play];
}

- (void)testPlayAppleMusicSong {
    NSString *const searchTerm = @"长城";
    NSString *urlString = @"https://itunes.apple.com/search";

    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.responseSerializer = [AFJSONResponseSerializer serializer];
    manager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript", @"text/html", nil];

    NSDictionary *params = @{
        @"term": searchTerm,
        @"media": @"music",
        @"limit": @25,
        @"country": @"US"
    };

    NSLog(@"开始请求 Apple Music (iTunes Search) API...");
    NSLog(@"搜索关键词: %@", searchTerm);

    __weak typeof(self) weakSelf = self;
    [manager GET:urlString
      parameters:params
         headers:nil
        progress:nil
         success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        NSLog(@"Apple Music API 请求成功");

        if (![responseObject isKindOfClass:[NSDictionary class]]) {
            NSLog(@"响应数据格式错误");
            return;
        }

        NSArray *results = responseObject[@"results"];
        if (!results || results.count == 0) {
            NSLog(@"没有在 Apple Music 中找到匹配歌曲");
            return;
        }

        BOOL foundPlayableTrack = NO;
        for (NSDictionary *track in results) {
            NSString *previewUrl = track[@"previewUrl"];
            NSString *songName = track[@"trackName"] ?: @"未知歌曲";
            NSString *artistName = track[@"artistName"] ?: @"未知艺术家";

            if (previewUrl && previewUrl.length > 0) {
                NSLog(@"找到 Apple Music 可播放歌曲: %@ - %@", artistName, songName);
                NSLog(@"Preview URL: %@", previewUrl);

                NSURL *url = [NSURL URLWithString:previewUrl];
                weakSelf.player = [AVPlayer playerWithURL:url];
                [weakSelf.player play];

                foundPlayableTrack = YES;
                break;
            } else {
                NSLog(@"跳过 Apple Music 歌曲 (无 previewUrl): %@ - %@", artistName, songName);
            }
        }

        if (!foundPlayableTrack) {
            NSLog(@"Apple Music 返回的结果都没有 previewUrl");
        }

    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
        NSInteger statusCode = response ? response.statusCode : 0;
        NSLog(@"Apple Music API 请求失败");
        NSLog(@"状态码: %ld", (long)statusCode);
        NSLog(@"错误描述: %@", error.localizedDescription);
        NSLog(@"错误详情: %@", error.userInfo);
    }];
}

// 监听回调
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"status"]) {
        if (self.player.currentItem.status == AVPlayerItemStatusFailed) {
          // 这行日志能告诉你底层到底是由于权限、网络还是解码失败
          NSLog(@"[Player] 播放失败详细原因: %@", self.player.currentItem.error.localizedDescription);
          NSLog(@"[Player] 错误代码: %ld", (long)self.player.currentItem.error.code);
        } else {
          NSLog(@"[Player] 播放成功");
        }
    }
}

#pragma mark - 音乐播放代码
- (void)pauseMusic {
    NSLog(@"[PlayerModel] ⏸️ 暂停播放");
    [self.player pause];
}

- (void)playMusic {
    NSLog(@"[PlayerModel] ▶️ 继续播放");
    [self.player play];
}

// 根据指定id，播放音乐
- (void)playMusicWithId:(NSString *)songId {
    if (!songId.length) {
        NSLog(@"[PlayerModel] ⚠️ playMusicWithId: songId 为空");
        return;
    }
    
    NSLog(@"[PlayerModel] 🎵 请求播放歌曲: %@", songId);
    
    // 1. 先检查内存缓存
    NSURL *localURL = [[XCMusicMemoryCache sharedInstance] localURLForSongId:songId];
    if (localURL) {
        NSLog(@"[PlayerModel] ✅ 命中内存缓存，使用本地播放");
        [self playWithURL:localURL songId:songId];
        [[XCMusicMemoryCache sharedInstance] setCurrentPlayingSong:songId];
        return;
    }
    
    NSLog(@"[PlayerModel] 🔍 未命中缓存，准备从网络获取 URL...");
    
    // 2. 无缓存，从网络获取
    XCNetworkManager *networkManager = [XCNetworkManager sharedInstance];
    [networkManager findUrlOfSongWithId:songId completion:^(NSURL * _Nullable songUrl) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (songUrl) {
                NSLog(@"[PlayerModel] 🌐 获取到歌曲 URL: %@", songUrl);
                [self playWithURL:songUrl songId:songId];
                
                // 3. 后台下载到内存缓存（只缓存当前播放的）
                XC_YYSongData *song = [self findSongInPlaylistById:songId];
                if (song) {
                    // 关键：将获取到的 URL 赋值给 song 对象
                    song.songUrl = songUrl.absoluteString;
                    NSLog(@"[PlayerModel] ⬇️ 触发后台缓存下载, URL: %@", song.songUrl);
                    [[XCMusicMemoryCache sharedInstance] downloadAndCache:song];
                } else {
                    NSLog(@"[PlayerModel] ⚠️ 播放列表中未找到该歌曲，无法缓存: %@", songId);
                }
            } else {
                NSLog(@"[PlayerModel] ❌ 错误: 无法获取歌曲 URL: %@", songId);
            }
        });
    }];
}

// 播放指定 URL
- (void)playWithURL:(NSURL *)url songId:(NSString *)songId {
    NSLog(@"[PlayerModel] 🎧 创建播放器: %@", songId);
    NSLog(@"[PlayerModel]    URL: %@", url);
    
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithURL:url];
    if (!self.player) {
        self.player = [AVPlayer playerWithPlayerItem:playerItem];
        NSLog(@"[PlayerModel]    创建新的 AVPlayer");
    } else {
        [self.player replaceCurrentItemWithPlayerItem:playerItem];
        NSLog(@"[PlayerModel]    替换当前播放项");
    }
    
    [self.player play];
    NSLog(@"[PlayerModel] ▶️ 开始播放: %@", songId);
    [self updateLockScreenInfo];
}

// 在播放列表中查找歌曲
- (XC_YYSongData *)findSongInPlaylistById:(NSString *)songId {
    if (!self.playerlist || self.playerlist.count == 0) {
        NSLog(@"[PlayerModel] ⚠️ 播放列表为空");
        return nil;
    }
    
    for (XC_YYSongData *song in self.playerlist) {
        if ([song.songId isEqualToString:songId]) {
            NSLog(@"[PlayerModel] 🔍 在播放列表中找到歌曲: %@ (索引: %lu)", 
                  song.name, (unsigned long)[self.playerlist indexOfObject:song]);
            return song;
        }
    }
    
    NSLog(@"[PlayerModel] ⚠️ 播放列表中未找到歌曲: %@", songId);
    return nil;
}

// 根据当前播放歌曲，自动切换到下一首歌（顺序播放）
- (void)playNextSong {
    NSLog(@"[PlayerModel] ⏭️ 切换到下一首");
    
    if (self.playerlist.count == 0) {
        NSLog(@"[PlayerModel] ⚠️ 播放列表为空，无法切换");
        return;
    }
    
    // 找到当前播放索引
    NSInteger currentIndex = [self.playerlist indexOfObject:self.nowPlayingSong];
    if (currentIndex == NSNotFound) {
        NSLog(@"[PlayerModel] ⚠️ 当前歌曲不在播放列表中，从第一首开始");
        currentIndex = -1;
    } else {
        NSLog(@"[PlayerModel]    当前索引: %lu/%lu", 
              (unsigned long)currentIndex, (unsigned long)self.playerlist.count);
    }
    
    // 计算下一首
    NSInteger nextIndex = (currentIndex + 1) % self.playerlist.count;
    XC_YYSongData *nextSong = self.playerlist[nextIndex];
    self.nowPlayingSong = nextSong;
    
    NSLog(@"[PlayerModel]    下一首索引: %lu, 歌曲: %@", 
          (unsigned long)nextIndex, nextSong.name);
    
    // 预加载下下首到内存
    NSInteger preloadIndex = (nextIndex + 1) % self.playerlist.count;
    if (preloadIndex != nextIndex) {  // 避免只有一首歌时重复加载
        XC_YYSongData *preloadSong = self.playerlist[preloadIndex];
        NSLog(@"[PlayerModel] 🔮 预加载歌曲: %@ (索引: %lu)", 
              preloadSong.name, (unsigned long)preloadIndex);
        [[XCMusicMemoryCache sharedInstance] downloadAndCache:preloadSong];
    }
    
    [self playMusicWithId:nextSong.songId];
}

// 播放上一首
- (void)playPreviousSong {
    NSLog(@"[PlayerModel] ⏮️ 切换到上一首");
    
    if (self.playerlist.count == 0) {
        NSLog(@"[PlayerModel] ⚠️ 播放列表为空，无法切换");
        return;
    }
    
    NSInteger currentIndex = [self.playerlist indexOfObject:self.nowPlayingSong];
    if (currentIndex == NSNotFound) {
        NSLog(@"[PlayerModel] ⚠️ 当前歌曲不在播放列表中");
        currentIndex = 0;
    } else {
        NSLog(@"[PlayerModel]    当前索引: %lu/%lu", 
              (unsigned long)currentIndex, (unsigned long)self.playerlist.count);
    }
    
    // 计算上一首
    NSInteger prevIndex = (currentIndex - 1 + self.playerlist.count) % self.playerlist.count;
    XC_YYSongData *prevSong = self.playerlist[prevIndex];
    self.nowPlayingSong = prevSong;
    
    NSLog(@"[PlayerModel]    上一首索引: %lu, 歌曲: %@", 
          (unsigned long)prevIndex, prevSong.name);
    
    [self playMusicWithId:prevSong.songId];
}
#pragma mark - 对接远程控制器
- (void)signUpAVAudioSession {
    NSLog(@"[PlayerModel] 🔊 配置音频会话...");
    NSError *error = nil;
    AVAudioSession *session = [AVAudioSession sharedInstance];

    [session setCategory:AVAudioSessionCategoryPlayback error:&error];
    if (error) {
        NSLog(@"[PlayerModel] ⚠️ Category 设置失败: %@", error.localizedDescription);
    } else {
        NSLog(@"[PlayerModel] ✅ Category 设置成功");
    }

    [session setActive:YES error:&error];
    if (error) {
        NSLog(@"[PlayerModel] ⚠️ Session 激活失败: %@", error.localizedDescription);
    } else {
        NSLog(@"[PlayerModel] ✅ Session 激活成功");
    }
}
// 与系统控制器绑定操作
- (void)setupRemoteCommands {
    NSLog(@"[PlayerModel] 🎛️ 设置远程控制命令...");
    // 获取全局的远程命令中心
    MPRemoteCommandCenter *commandCenter = [MPRemoteCommandCenter sharedCommandCenter];
    [commandCenter.playCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
        NSLog(@"[PlayerModel] 🎛️ 远程命令: 播放");
        [self playMusic];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    [commandCenter.pauseCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
        NSLog(@"[PlayerModel] 🎛️ 远程命令: 暂停");
        [self pauseMusic];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    [commandCenter.changePlaybackPositionCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
        MPChangePlaybackPositionCommandEvent *positionEvent = (MPChangePlaybackPositionCommandEvent *)event;
        NSLog(@"[PlayerModel] 🎛️ 远程命令: 进度调整 -> %.1fs", positionEvent.positionTime);
        // TODO: 自己的调整播放时间的操作
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    NSLog(@"[PlayerModel] ✅ 远程控制命令设置完成");
}

// 每次切换的时候更新信息
- (void)updateLockScreenInfo {
    NSLog(@"[PlayerModel] 🔒 更新锁屏信息...");
    MPNowPlayingInfoCenter *infoCenter = [MPNowPlayingInfoCenter defaultCenter];
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];

    [dict setObject:(self.nowPlayingSong.name ?: @"未知标题") forKey:MPMediaItemPropertyTitle];
    [dict setObject:(self.nowPlayingSong.artist ?: @"未知艺术家") forKey:MPMediaItemPropertyArtist];
    [dict setObject:(self.nowPlayingSong.albumName ?: @"未知专辑") forKey:MPMediaItemPropertyAlbumTitle];

    NSURL *url = [NSURL URLWithString:self.nowPlayingSong.mainIma];

    // 尝试先找占位图
    UIImage *artworkImage = [UIImage imageNamed:@"placeholder_cover"];

    if (url) {
        NSString *key = [[SDWebImageManager sharedManager] cacheKeyForURL:url];
        // 【关键修改】同时查找内存和磁盘 (Disk)
        UIImage *cachedImage = [[SDImageCache sharedImageCache] imageFromDiskCacheForKey:key];

        if (cachedImage) {
            artworkImage = cachedImage;
            NSLog(@"[PlayerModel]    使用缓存的专辑封面");
        } else {
            NSLog(@"[PlayerModel]    未找到专辑封面缓存");
        }
    }

    if (artworkImage) {
        MPMediaItemArtwork *artwork = [[MPMediaItemArtwork alloc] initWithBoundsSize:artworkImage.size requestHandler:^UIImage * _Nonnull(CGSize size) {
            return artworkImage;
        }];
        [dict setObject:artwork forKey:MPMediaItemPropertyArtwork];
    }
    // 示例：假设 self.player 是 AVPlayer
    // CMTime duration = self.player.currentItem.duration;
    // float totalSeconds = CMTimeGetSeconds(duration);
    // float currentSeconds = CMTimeGetSeconds(self.player.currentTime);

    // 使用歌曲实际时长（转换为秒）
    NSInteger durationSeconds = self.nowPlayingSong.duration / 1000;
    if (durationSeconds > 0) {
        [dict setObject:@(durationSeconds) forKey:MPMediaItemPropertyPlaybackDuration];
    } else {
        [dict setObject:@(200.0) forKey:MPMediaItemPropertyPlaybackDuration];
    }
    [dict setObject:@(50.0) forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];

    // 如果暂停了，Rate 必须设为 0.0，否则锁屏进度条会一直走
    // [dict setObject:@(self.player.rate) forKey:MPNowPlayingInfoPropertyPlaybackRate];
    [dict setObject:@(1.0) forKey:MPNowPlayingInfoPropertyPlaybackRate];

    [infoCenter setNowPlayingInfo:dict];
    NSLog(@"[PlayerModel] ✅ 锁屏信息更新完成: %@", self.nowPlayingSong.name);
}
#pragma mark - 缓存相关内容
- (NSURL *)customURLFromOriginalURL:(NSURL *)originalURL {
    NSURLComponents *components = [NSURLComponents componentsWithURL:originalURL resolvingAgainstBaseURL:NO];
    components.scheme = @"pyrotechnic";
    return components.URL;
}
// TODO: 完成从沙盒里取数据和放数据和查数据

#pragma mark - 缓存测试方法

/// 测试内存缓存功能（可在 viewDidLoad 中调用）
- (void)testMemoryCache {
    NSLog(@"=================================================================");
    NSLog(@"[PlayerModel] 🧪 开始内存缓存测试");
    NSLog(@"=================================================================");
    
    XCMusicMemoryCache *cache = [XCMusicMemoryCache sharedInstance];
    
    // 测试 1: 空缓存查询
    NSLog(@"[PlayerModel] 🧪 测试1: 查询未缓存的歌曲...");
    BOOL isCached = [cache isCached:@"test_song_123"];
    NSLog(@"[PlayerModel]    结果: %@", isCached ? @"已缓存❌" : @"未缓存✅");
    
    // 测试 2: 写入缓存
    NSLog(@"[PlayerModel] 🧪 测试2: 写入测试数据...");
    NSString *testString = @"This is test audio data for caching";
    NSData *testData = [testString dataUsingEncoding:NSUTF8StringEncoding];
    [cache cacheData:testData forSongId:@"test_song_123"];
    
    // 测试 3: 再次查询
    NSLog(@"[PlayerModel] 🧪 测试3: 再次查询...");
    isCached = [cache isCached:@"test_song_123"];
    NSLog(@"[PlayerModel]    结果: %@", isCached ? @"已缓存✅" : @"未缓存❌");
    
    // 测试 4: 读取数据
    NSLog(@"[PlayerModel] 🧪 测试4: 读取缓存数据...");
    NSData *readData = [cache dataForSongId:@"test_song_123"];
    NSString *readString = [[NSString alloc] initWithData:readData encoding:NSUTF8StringEncoding];
    NSLog(@"[PlayerModel]    读取内容: %@", readString);
    BOOL dataCorrect = [readString isEqualToString:testString];
    NSLog(@"[PlayerModel]    数据一致性: %@", dataCorrect ? @"✅" : @"❌");
    
    // 测试 5: 本地 URL
    NSLog(@"[PlayerModel] 🧪 测试5: 获取本地文件 URL...");
    NSURL *localURL = [cache localURLForSongId:@"test_song_123"];
    NSLog(@"[PlayerModel]    本地 URL: %@", localURL);
    NSLog(@"[PlayerModel]    文件是否存在: %@", localURL ? @"✅" : @"❌");
    
    // 测试 6: 清理
    NSLog(@"[PlayerModel] 🧪 测试6: 清理缓存...");
    [cache removeCache:@"test_song_123"];
    isCached = [cache isCached:@"test_song_123"];
    NSLog(@"[PlayerModel]    结果: %@", isCached ? @"已缓存❌" : @"未缓存✅");
    
    NSLog(@"=================================================================");
    NSLog(@"[PlayerModel] 🧪 内存缓存测试结束");
    NSLog(@"=================================================================");
}

@end
