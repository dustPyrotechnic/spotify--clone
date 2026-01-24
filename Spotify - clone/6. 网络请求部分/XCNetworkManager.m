//
//  XCNetworkManager.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/11/26.
//

#import "XCNetworkManager.h"

#import "XCAlbumSimpleData.h"
#import "XC-YYAlbumData.h"
#import "XC-YYSongData.h"

#import <AFNetworking/AFNetworking.h>
#import <UICKeyChainStore/UICKeyChainStore.h> // 将token保存在本地里，并加密保存


@implementation XCNetworkManager
static XCNetworkManager *instance = nil;
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

// 简单的测试函数

- (void)getTokenWithCompletion:(void(^)(BOOL success))completion {
    static NSInteger tokenTimes = 0; // 单独记录 token 的重试次数

    NSString *url = @"https://accounts.spotify.com/api/token";

    NSDictionary *params = @{
        @"grant_type": @"client_credentials",
        @"client_id": @"183f5d912f4448519ba2d88416b3ddb1",
        @"client_secret": @"8e3f600ff28940a397b24bcc96faa5ae"
    };

    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];

    [manager POST:url
       parameters:params
          headers:nil
         progress:nil
          success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {

        tokenTimes = 0;
        NSLog(@"拿到新 Token 了: %@", responseObject[@"access_token"]);
        [UICKeyChainStore setString:responseObject[@"access_token"] forKey:@"token" service:@"com.spotify.clone"];

        if (completion) {
            completion(YES);
        }

    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)task.response;
        NSInteger statusCode = httpResponse.statusCode;
        
        NSLog(@"[请求token]失败");
        NSLog(@"状态码: %ld", (long)statusCode);
        NSLog(@"错误信息: %@", error.localizedDescription);
        NSLog(@"错误详情: %@", error.userInfo);

        if (tokenTimes < 3) {
            tokenTimes += 1;
            NSLog(@"正在第 %ld 次重试获取 Token...", (long)tokenTimes);
            // 递归重试
            [self getTokenWithCompletion:completion];
        } else {
            // 彻底失败，通知外界 NO
            NSLog(@"Token 获取彻底失败，已重试 %ld 次", (long)tokenTimes);
            tokenTimes = 0; // 重置计数器
            if (completion) {
                completion(NO);
            }
        }
    }];
}

- (void)getDataOfAllAlbums:(NSMutableArray *)array {
    static NSInteger dataTimes = 0;

    NSLog(@"[首页数据] 开始请求数据... (第 %ld 次尝试)", (long)(dataTimes + 1));
    NSString *token = [UICKeyChainStore stringForKey:@"token" service:@"com.spotify.clone"];

    // 如果没有 Token，直接去拿，不要往下走了
    if (!token || token.length == 0) {
        NSLog(@"本地没有 Token，先去申请...");
        [self getTokenWithCompletion:^(BOOL success) {
            if (success) {
                NSLog(@"Token 获取成功，重新请求数据...");
                // 拿到后，递归调用自己，重新开始
                [self getDataOfAllAlbums:array];
            } else {
                NSLog(@"Token 获取失败，无法继续请求数据");
            }
        }];
        return;
    }
    
    NSLog(@"找到本地 Token，长度: %lu", (unsigned long)token.length);

    NSString *baseUrl = @"https://api.spotify.com/v1/browse/new-releases";
    NSString *header = [NSString stringWithFormat:@"Bearer %@", token];

    NSDictionary *params = @{
        @"limit" : @50,
        @"offset" : @0
    };

    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    [manager.requestSerializer setValue:header forHTTPHeaderField:@"Authorization"];

    [manager GET:baseUrl
      parameters:params
         headers:nil
        progress:nil
         success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {

        NSLog(@"[首页数据] 请求成功");
        dataTimes = 0;
        NSDictionary *rootDict = (NSDictionary *)responseObject;
        
        if (!rootDict) {
            NSLog(@"响应数据为空");
            return;
        }
        
        NSDictionary *albumsDict = rootDict[@"albums"];
        if (!albumsDict) {
            NSLog(@"albums 字典为空");
            return;
        }
        
        NSArray *items = albumsDict[@"items"];
        if (!items || items.count == 0) {
            NSLog(@"items 数组为空或长度为0");
            return;
        }
        
        NSLog(@"收到 %lu 个专辑数据", (unsigned long)items.count);
        
        // 关键修复：先清空原有数据，避免因为数组已有5组数据导致循环立即退出
        [array removeAllObjects];
        
        // 逻辑：遍历 items，每 10 个塞进一个小数组，满 5 组停止
        NSMutableArray *currentGroup = nil;

        for (int i = 0; i < items.count; i++) {
            // 1. 每逢 10 的倍数 (0, 10, 20...) 创建新组
            if (i % 10 == 0) {
                if (array.count >= 5) break; // 够 5 组了，不装了
                currentGroup = [[NSMutableArray alloc] init];
                [array addObject:currentGroup];
            }

            // 解析单个 Model
            NSDictionary *albumData = items[i];
            if (!albumData || ![albumData isKindOfClass:[NSDictionary class]]) {
                NSLog(@"第 %d 个专辑数据格式错误，跳过", i);
                continue;
            }
            
            XCAlbumSimpleData *album = [[XCAlbumSimpleData alloc] init];

            // 安全取图片
            NSArray *images = albumData[@"images"];
            if (images && images.count > 0 && [images[0] isKindOfClass:[NSDictionary class]]) {
                album.imageURL = images[0][@"url"];
            }
            album.nameAlbum = albumData[@"name"] ?: @"未知专辑";
            album.idOfAlbum = albumData[@"id"] ?: @"";

            // 3. 加入当前组
            [currentGroup addObject:album];
        }
        
        NSLog(@"数据解析完成，共 %lu 组数据", (unsigned long)array.count);
        for (int i = 0; i < array.count; i++) {
            NSArray *group = array[i];
            NSLog(@"第 %d 组: %lu 个专辑", i, (unsigned long)group.count);
        }

        // 记得在这里刷新 UI，例如：
      dispatch_async(dispatch_get_main_queue(), ^{
//        [self.collectionView reloadData];
        // 发送通知
        [[NSNotificationCenter defaultCenter] postNotificationName:@"HomePageDataLoaded" object:nil];
      });

    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {

        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)task.response;
        NSInteger statusCode = httpResponse.statusCode;

        NSLog(@"[首页数据] 请求失败");
        NSLog(@"状态码: %ld", (long)statusCode);
        NSLog(@"错误信息: %@", error.localizedDescription);
        NSLog(@"错误详情: %@", error.userInfo);
        
        if (statusCode == 401) {
            NSLog(@"Token 过期或无效，正在刷新...");

            // 关键：使用 Block 等待 Token 回来！
            [self getTokenWithCompletion:^(BOOL success) {
                if (success) {
                    NSLog(@"Token 刷新成功，正在重试请求数据...");
                    dataTimes = 0; // 重置重试次数
                    [self getDataOfAllAlbums:array];
                } else {
                    NSLog(@"Token 刷新失败，无法继续");
                }
            }];
            return;
        }

        if (dataTimes < 10) {
            dataTimes += 1;
            NSLog(@"网络波动，1秒后进行第 %ld 次重试...", (long)dataTimes);
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self getDataOfAllAlbums:array];
            });
        } else {
            NSLog(@"彻底失败，已重试 %ld 次，请检查网络", (long)dataTimes);
            dataTimes = 0; // 重置计数器
        }
    }];
}

#pragma mark - 这里是使用到的网络请求
// 直接获取专辑封面和名字，使用api
// https://1390963969-2g6ivueiij.ap-guangzhou.tencentscf.com
// 妈生网易云，真他妈难用
// 4个参数，可以自定义偏移量和请求数据多少
#pragma mark - 播放列表和专辑部分内容
- (void)getDataOfPlaylistsFromWY:(NSMutableArray *)array offset:(NSInteger)offset limit:(NSInteger)limit withCompletion:(void(^)(BOOL success))completion {
    NSString *baseUrl = @"https://1390963969-2g6ivueiij.ap-guangzhou.tencentscf.com";
    NSString *requestUrl = [NSString stringWithFormat:@"%@/top/playlist", baseUrl];

    NSDictionary *params = @{
        @"limit" : @(limit),
        @"offset" : @(offset)
    };
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];

    manager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript", @"text/html", @"text/plain", nil];

    [manager GET:requestUrl
      parameters:params
         headers:nil
        progress:nil
         success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        if (![responseObject isKindOfClass:[NSDictionary class]]) {
            if (completion) completion(NO);
            return;
        }
        NSArray *playlistsJSON = responseObject[@"playlists"];

        if (playlistsJSON) {
            NSArray<XC_YYAlbumData *> *newAlbums = [NSArray yy_modelArrayWithClass:[XC_YYAlbumData class] json:playlistsJSON];
          [array removeAllObjects];
          [array addObjectsFromArray:newAlbums];

            if (completion) completion(YES);
        } else {
            if (completion) completion(NO);
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSLog(@"请求失败: %@", error);
        if (completion) completion(NO);
    }];
}
- (void)getAlbumsFromWY:(NSMutableArray *)array offset:(NSInteger)offset limit:(NSInteger)limit withCompletion:(void(^)(BOOL success))completion {
    NSString *baseUrl = @"https://1390963969-2g6ivueiij.ap-guangzhou.tencentscf.com";
    NSString *requestUrl = [NSString stringWithFormat:@"%@/album/list", baseUrl];

    NSDictionary *params = @{
        @"limit" : @(limit),
        @"offset" : @(offset)
    };
  AFHTTPSessionManager* manager = [AFHTTPSessionManager manager];
  manager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript", @"text/html", @"text/plain", nil];
  [manager GET:requestUrl
    parameters:params
       headers:nil
      progress:nil
       success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
    if (![responseObject isKindOfClass:[NSDictionary class]]) {
      completion(NO);
      return;
    }
    NSArray* playlistsJSON = responseObject[@"products"];
    if (playlistsJSON) {
      NSArray<XC_YYAlbumData *> *newAlbums = [NSArray yy_modelArrayWithClass:[XC_YYAlbumData class] json:playlistsJSON];
      [array removeAllObjects];
      [array addObjectsFromArray:newAlbums];
      if (completion) completion(YES);
    } else {
        if (completion) completion(NO);
    }
  } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
    NSLog(@"请求失败： %@", error);
    if (completion) completion(NO);
  }];
}
- (void)getDetailOfAlbumFromWY:(NSMutableArray *)array ofAlbumId:(NSString*) albumId withCompletion:(void(^)(BOOL success))completion  {
    // 示例：https://1390963969-2g6ivueiij.ap-guangzhou.tencentscf.com/album?id=190605791
  NSString *baseUrl = @"https://1390963969-2g6ivueiij.ap-guangzhou.tencentscf.com";
  NSString *requestUrl = [NSString stringWithFormat:@"%@/album", baseUrl];
  NSDictionary *params = @{@"id" : albumId};
  AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
  manager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript", @"text/html", @"text/plain", nil];
    [manager GET:requestUrl parameters:params headers:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        if (![responseObject isKindOfClass:[NSDictionary class]]) {
            if (completion) completion(NO);
            return;
        }
        NSArray *songsJSON = responseObject[@"songs"];
        if (songsJSON) {
            NSArray<XC_YYSongData *> *newSongs = [NSArray yy_modelArrayWithClass:[XC_YYSongData class] json:songsJSON];
            [array removeAllObjects];
            [array addObjectsFromArray:newSongs];
            if (completion) completion(YES);
        } else {
            if (completion) completion(NO);
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
      NSLog(@"请求失败： %@", error);
      NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
      NSLog(@"状态码: %ld", (long)response.statusCode);
      NSLog(@"错误描述: %@", error.localizedDescription);
      if (completion) completion(NO);
    }];
}
#pragma mark - 单个歌曲的相关操作
- (void)findUrlOfSongWithId:(NSString *)songId completion:(void(^)(NSURL * _Nullable songUrl))completion {
  NSString *baseUrl = @"https://1390963969-2g6ivueiij.ap-guangzhou.tencentscf.com";
  NSString *requestUrl = [NSString stringWithFormat:@"%@/song/url/v1", baseUrl];
  NSDictionary *params = @{
     @"id" : songId,
     @"level": @"standard"
  };

  AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
  manager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript", @"text/html", @"text/plain", nil];

  [manager GET:requestUrl parameters:params headers:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id _Nullable responseObject) {
     NSArray *data = responseObject[@"data"];

     if (data && data.count > 0) {
         NSDictionary *songInfo = data.firstObject;
         NSString *urlString = songInfo[@"url"];

         if (urlString && ![urlString isKindOfClass:[NSNull class]]) {
             NSURL *finalUrl = [NSURL URLWithString:urlString];
             if (completion) completion(finalUrl);
         } else {
             NSLog(@"警告：歌曲 ID %@ 的 URL 为空（可能需付费或无版权）", songId);
             if (completion) completion(nil);
         }
     } else {
         if (completion) completion(nil);
     }

  } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
     NSLog(@"请求失败： %@", error);
     NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
     NSLog(@"状态码: %ld", (long)response.statusCode);

     if (completion) completion(nil);
  }];
}

@end
