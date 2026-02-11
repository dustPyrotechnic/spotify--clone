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
#import <UICKeyChainStore/UICKeyChainStore.h>

@implementation XCNetworkManager
static XCNetworkManager *instance = nil;

+ (void)load {
  instance = [[super allocWithZone:NULL] init];
}

+ (instancetype)sharedInstance {
  return instance;
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone {
  return [self sharedInstance];
}

- (id)copyWithZone:(NSZone *)zone {
  return self;
}

- (id)mutableCopyWithZone:(NSZone *)zone {
  return self;
}

- (void)getTokenWithCompletion:(void(^)(BOOL success))completion {
    static NSInteger tokenTimes = 0;
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
        [UICKeyChainStore setString:responseObject[@"access_token"] forKey:@"token" service:@"com.spotify.clone"];
        if (completion) completion(YES);
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)task.response;
        NSInteger statusCode = httpResponse.statusCode;
        if (tokenTimes < 3) {
            tokenTimes += 1;
            [self getTokenWithCompletion:completion];
        } else {
            tokenTimes = 0;
            if (completion) completion(NO);
        }
    }];
}

- (void)getDataOfAllAlbums:(NSMutableArray *)array {
    static NSInteger dataTimes = 0;
    NSString *token = [UICKeyChainStore stringForKey:@"token" service:@"com.spotify.clone"];
    if (!token || token.length == 0) {
        [self getTokenWithCompletion:^(BOOL success) {
            if (success) {
                [self getDataOfAllAlbums:array];
            }
        }];
        return;
    }
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
        dataTimes = 0;
        NSDictionary *rootDict = (NSDictionary *)responseObject;
        if (!rootDict) return;
        NSDictionary *albumsDict = rootDict[@"albums"];
        if (!albumsDict) return;
        NSArray *items = albumsDict[@"items"];
        if (!items || items.count == 0) return;
        [array removeAllObjects];
        NSMutableArray *currentGroup = nil;
        for (int i = 0; i < items.count; i++) {
            if (i % 10 == 0) {
                if (array.count >= 5) break;
                currentGroup = [[NSMutableArray alloc] init];
                [array addObject:currentGroup];
            }
            NSDictionary *albumData = items[i];
            if (!albumData || ![albumData isKindOfClass:[NSDictionary class]]) continue;
            XCAlbumSimpleData *album = [[XCAlbumSimpleData alloc] init];
            NSArray *images = albumData[@"images"];
            if (images && images.count > 0 && [images[0] isKindOfClass:[NSDictionary class]]) {
                album.imageURL = images[0][@"url"];
            }
            album.nameAlbum = albumData[@"name"] ?: @"未知专辑";
            album.idOfAlbum = albumData[@"id"] ?: @"";
            [currentGroup addObject:album];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"HomePageDataLoaded" object:nil];
        });
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)task.response;
        NSInteger statusCode = httpResponse.statusCode;
        if (statusCode == 401) {
            [self getTokenWithCompletion:^(BOOL success) {
                if (success) {
                    dataTimes = 0;
                    [self getDataOfAllAlbums:array];
                }
            }];
            return;
        }
        if (dataTimes < 10) {
            dataTimes += 1;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self getDataOfAllAlbums:array];
            });
        } else {
            dataTimes = 0;
        }
    }];
}

#pragma mark - 网易云API
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
        if (completion) completion(NO);
    }];
}

- (void)getDetailOfAlbumFromWY:(NSMutableArray *)array ofAlbumId:(NSString*) albumId withCompletion:(void(^)(BOOL success))completion {
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
        if (completion) completion(NO);
    }];
}

#pragma mark - 歌曲操作
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
                if (completion) completion(nil);
            }
        } else {
            if (completion) completion(nil);
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        if (completion) completion(nil);
    }];
}

@end
