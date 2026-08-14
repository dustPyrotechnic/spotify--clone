//
//  XCSearchModel.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/12/5.
//

#import <Foundation/Foundation.h>
#import "XC-YYSongData.h"
#import "XC-YYAlbumData.h"

NS_ASSUME_NONNULL_BEGIN

@interface XCSearchModel : NSObject

/// 搜索歌曲（返回 XC_YYSongData 数组）
- (void)searchSongsWithQuery:(NSString *)query
                      offset:(NSInteger)offset
                       limit:(NSInteger)limit
                  completion:(void (^)(NSArray<XC_YYSongData *> *results, NSError *error))completion;

/// 搜索专辑（返回 XC_YYAlbumData 数组）
- (void)searchAlbumsWithQuery:(NSString *)query
                       offset:(NSInteger)offset
                        limit:(NSInteger)limit
                   completion:(void (^)(NSArray<XC_YYAlbumData *> *results, NSError *error))completion;

/// 搜索艺人（返回原始 NSDictionary 数组）
- (void)searchArtistsWithQuery:(NSString *)query
                        offset:(NSInteger)offset
                         limit:(NSInteger)limit
                    completion:(void (^)(NSArray *results, NSError *error))completion;

/// 实时搜索建议
- (void)fetchSuggestionsWithQuery:(NSString *)query
                       completion:(void (^)(NSArray<NSString *> *suggestions, NSError *error))completion;

/// 获取热搜榜词条
- (void)fetchHotSearchesWithCompletion:(void (^)(NSArray<NSString *> *hotWords, NSError *error))completion;

@end

NS_ASSUME_NONNULL_END
