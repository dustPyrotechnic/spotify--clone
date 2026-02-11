//
//  XCNetworkManager.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/11/26.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface XCNetworkManager : NSObject
+ (instancetype)sharedInstance;
- (void)getTokenWithCompletion:(void(^)(BOOL success))completion;
- (void) getDataOfAllAlbums:(NSMutableArray*) array ;
- (void)getDataOfPlaylistsFromWY:(NSMutableArray *)array offset:(NSInteger)offset limit:(NSInteger)limit withCompletion:(void(^)(BOOL success))completion;
- (void)getAlbumsFromWY:(NSMutableArray *)array offset:(NSInteger)offset limit:(NSInteger)limit withCompletion:(void(^)(BOOL success))completion;
- (void)getDetailOfAlbumFromWY:(NSMutableArray *)array ofAlbumId:(NSString*) albumId withCompletion:(void(^)(BOOL success))completion;
- (void)findUrlOfSongWithId:(NSString *)songId completion:(void(^)(NSURL * _Nullable songUrl))completion;
@end

NS_ASSUME_NONNULL_END
