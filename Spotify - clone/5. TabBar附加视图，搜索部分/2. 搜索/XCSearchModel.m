//
//  XCSearchModel.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/12/5.
//

#import "XCSearchModel.h"
#import "XCNetworkManager.h"

@implementation XCSearchModel

#pragma mark - Search Methods

- (void)searchSongsWithQuery:(NSString *)query
                      offset:(NSInteger)offset
                       limit:(NSInteger)limit
                  completion:(void (^)(NSArray *results, NSError *error))completion {
    // TODO: 实现歌曲搜索 API 调用
    // 可以使用网易云或 Spotify 搜索 API
    if (completion) {
        completion(@[], nil);
    }
}

- (void)searchAlbumsWithQuery:(NSString *)query
                       offset:(NSInteger)offset
                        limit:(NSInteger)limit
                   completion:(void (^)(NSArray *results, NSError *error))completion {
    // TODO: 实现专辑搜索 API 调用
    if (completion) {
        completion(@[], nil);
    }
}

- (void)searchArtistsWithQuery:(NSString *)query
                        offset:(NSInteger)offset
                         limit:(NSInteger)limit
                    completion:(void (^)(NSArray *results, NSError *error))completion {
    // TODO: 实现艺人搜索 API 调用
    if (completion) {
        completion(@[], nil);
    }
}

@end
