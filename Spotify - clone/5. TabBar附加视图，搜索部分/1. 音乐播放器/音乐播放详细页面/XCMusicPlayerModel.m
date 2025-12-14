//
//  XCMusicPlayerModel.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/12/1.
//

#import "XCMusicPlayerModel.h"

#import <UICKeyChainStore/UICKeyChainStore.h>
#import <AFNetworking/AFNetworking.h>
#import <AVFoundation/AVFoundation.h>

@implementation XCMusicPlayerModel
#pragma mark - 单例模式代码
static XCMusicPlayerModel *instance = nil;
// 在 +load 方法中创建单例实例
+ (void)load {
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
#pragma mark - 音乐播放部分代码
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
    NSString *const searchTerm = @"大国民";
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



@end
