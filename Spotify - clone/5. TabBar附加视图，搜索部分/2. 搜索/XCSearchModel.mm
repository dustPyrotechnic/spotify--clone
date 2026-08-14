//
//  XCSearchModel.m
//  Spotify - clone
//

#import "XCSearchModel.h"
#import "XCNetworkManager.h"
#import <YYModel/YYModel.h>

@implementation XCSearchModel

#pragma mark - 搜索歌曲

- (void)searchSongsWithQuery:(NSString *)query
                      offset:(NSInteger)offset
                       limit:(NSInteger)limit
                  completion:(void (^)(NSArray<XC_YYSongData *> *results, NSError *error))completion {
    [[XCNetworkManager sharedInstance] searchFromWY:query type:1 offset:offset limit:limit
                                     withCompletion:^(BOOL success, id result) {
        if (!success || !result) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(@[], nil);
            });
            return;
        }
        NSArray *songsJSON = ((NSDictionary *)result)[@"songs"];
        if (!songsJSON || songsJSON.count == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(@[], nil);
            });
            return;
        }
        // YYModel 自动映射：id→songId, al.picUrl→mainIma, al.name→albumName,
        // al.id→albumId, dt→duration, mv→mvId, no→trackNumber, pop→popularity,
        // alia→alias; ar 数组由 modelCustomTransformFromDictionary: 处理
        NSArray<XC_YYSongData *> *songs = [NSArray yy_modelArrayWithClass:[XC_YYSongData class] json:songsJSON];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(songs ?: @[], nil);
        });
    }];
}

#pragma mark - 搜索专辑

- (void)searchAlbumsWithQuery:(NSString *)query
                       offset:(NSInteger)offset
                        limit:(NSInteger)limit
                   completion:(void (^)(NSArray<XC_YYAlbumData *> *results, NSError *error))completion {
    [[XCNetworkManager sharedInstance] searchFromWY:query type:10 offset:offset limit:limit
                                     withCompletion:^(BOOL success, id result) {
        if (!success || !result) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(@[], nil);
            });
            return;
        }
        NSArray *albumsJSON = ((NSDictionary *)result)[@"albums"];
        if (!albumsJSON || albumsJSON.count == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(@[], nil);
            });
            return;
        }
        // cloudsearch 专辑字段：id, name, picUrl, artist{id,name}
        // 与 XC_YYAlbumData 的 YYModel mapper 不匹配，手动映射
        NSMutableArray<XC_YYAlbumData *> *albums = [NSMutableArray array];
        for (NSDictionary *dict in albumsJSON) {
            if (![dict isKindOfClass:[NSDictionary class]]) continue;
            XC_YYAlbumData *album = [[XC_YYAlbumData alloc] init];
            id idVal = dict[@"id"];
            album.albumId = idVal ? [NSString stringWithFormat:@"%@", idVal] : @"";
            album.name = dict[@"name"] ?: @"";
            NSString *picUrl = dict[@"picUrl"];
            if ([picUrl isKindOfClass:[NSString class]]) {
                if ([picUrl hasPrefix:@"http://"]) {
                    picUrl = [picUrl stringByReplacingOccurrencesOfString:@"http://" withString:@"https://"];
                }
                album.coverImgUrl = picUrl;
            }
            NSDictionary *artistDict = dict[@"artist"];
            if ([artistDict isKindOfClass:[NSDictionary class]]) {
                album.artistName = artistDict[@"name"] ?: @"";
                id artistId = artistDict[@"id"];
                album.authorId = artistId ? [NSString stringWithFormat:@"%@", artistId] : @"";
            }
            [albums addObject:album];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion([albums copy], nil);
        });
    }];
}

#pragma mark - 搜索艺人

- (void)searchArtistsWithQuery:(NSString *)query
                        offset:(NSInteger)offset
                         limit:(NSInteger)limit
                    completion:(void (^)(NSArray *results, NSError *error))completion {
    [[XCNetworkManager sharedInstance] searchFromWY:query type:100 offset:offset limit:limit
                                     withCompletion:^(BOOL success, id result) {
        NSArray *artists = success ? ((NSDictionary *)result)[@"artists"] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(artists ?: @[], nil);
        });
    }];
}

#pragma mark - 搜索建议

- (void)fetchSuggestionsWithQuery:(NSString *)query
                       completion:(void (^)(NSArray<NSString *> *suggestions, NSError *error))completion {
    [[XCNetworkManager sharedInstance] searchSuggestFromWY:query
                                            withCompletion:^(BOOL success, NSArray<NSString *> *suggestions) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(suggestions ?: @[], nil);
        });
    }];
}

#pragma mark - 热搜榜

- (void)fetchHotSearchesWithCompletion:(void (^)(NSArray<NSString *> *hotWords, NSError *error))completion {
    [[XCNetworkManager sharedInstance] searchHotDetailFromWYWithCompletion:^(BOOL success, NSArray<NSString *> *hotWords) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(hotWords ?: @[], nil);
        });
    }];
}

@end
