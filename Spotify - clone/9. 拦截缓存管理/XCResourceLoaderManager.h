//
//  XCResourceLoaderManager.h
//  Spotify - clone
//
//  资源加载拦截器 - 基于 AVAssetResourceLoaderDelegate 实现音频资源请求的拦截
//  用于拦截 AVPlayer 的资源加载请求，实现自定义缓存策略
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface XCResourceLoaderManager : NSObject <AVAssetResourceLoaderDelegate>
+ (instancetype)sharedInstance;
@end

NS_ASSUME_NONNULL_END
