//
//  XCNetworkManager.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/11/26.
//
/*
 这是网络请求单例
Post请求token，并存储在UICKeyChainStore这个第三方库里进行保存
根据token来进行请求数据，如果遇到token失效，将任务加入队列
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface XCNetworkManager : NSObject
// 暴露方法
+ (instancetype)sharedInstance;
- (void)getTokenWithCompletion:(void(^)(BOOL success))completion;
- (void) getDataOfAllAlbums:(NSMutableArray*) array ;
/// 使用网易云的API来请求数据（支持分页）
- (void)getDataOfPlaylistsFromWY:(NSMutableArray *)array offset:(NSInteger)offset limit:(NSInteger)limit withCompletion:(void(^)(BOOL success))completion;
- (void)getAlbumsFromWY:(NSMutableArray *)array offset:(NSInteger)offset limit:(NSInteger)limit withCompletion:(void(^)(BOOL success))completion;

- (void)getDetailOfAlbumFromWY:(NSMutableArray *)array ofAlbumId:(NSString*) albumId withCompletion:(void(^)(BOOL success))completion;

- (void)findUrlOfSongWithId:(NSString *)songId completion:(void(^)(NSURL * _Nullable songUrl))completion;
@end

NS_ASSUME_NONNULL_END
