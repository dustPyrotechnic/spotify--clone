//
//  XCSearchModel.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/12/5.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface XCSearchModel : NSObject

/// 搜索歌曲
- (void)searchSongsWithQuery:(NSString *)query
                      offset:(NSInteger)offset
                       limit:(NSInteger)limit
                  completion:(void (^)(NSArray *results, NSError *error))completion;

/// 搜索专辑
- (void)searchAlbumsWithQuery:(NSString *)query
                       offset:(NSInteger)offset
                        limit:(NSInteger)limit
                   completion:(void (^)(NSArray *results, NSError *error))completion;

/// 搜索艺人
- (void)searchArtistsWithQuery:(NSString *)query
                        offset:(NSInteger)offset
                         limit:(NSInteger)limit
                    completion:(void (^)(NSArray *results, NSError *error))completion;

@end

NS_ASSUME_NONNULL_END
