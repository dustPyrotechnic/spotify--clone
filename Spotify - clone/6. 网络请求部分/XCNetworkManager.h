//
//  XCNetworkManager.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/11/26.
//
/*
 这是网络请求单例
 我们会在网络请求单例中做到几个功能
 1. Post请求token，并存储在UICKeyChainStore这个第三方库里进行保存
 2. 根据token来进行请求数据，如果遇到token失效，将任务加入队列
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface XCNetworkManager : NSObject
// 暴露方法
+ (instancetype)sharedInstance;
- (void)getTokenWithCompletion:(void(^)(BOOL success))completion;
- (void) getDataOfAllAlbums:(NSMutableArray*) array ;
@end

NS_ASSUME_NONNULL_END
