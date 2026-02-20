//
//  XCResourceLoaderManager.h
//  Spotify - clone
//
//  资源加载拦截器 - 基于 AVAssetResourceLoaderDelegate 实现音频资源请求的拦截
//  用于拦截 AVPlayer 的资源加载请求，实现自定义缓存策略
//  Phase B: 实现边下边播，支持 L1 分段缓存
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 资源加载管理器 - 实现分段播放/边下边播
@interface XCResourceLoaderManager : NSObject <AVAssetResourceLoaderDelegate>
+ (instancetype)sharedInstance;

/// 将原始 URL 转换为自定义 scheme URL（用于触发 resourceLoader）
/// @param originalURL 原始音频 URL
/// @param songId 歌曲 ID
/// @return 自定义 scheme URL (如: streaming://songId?url=originalURL)
- (NSURL *)streamingURLFromOriginalURL:(NSURL *)originalURL songId:(NSString *)songId;

/// 从自定义 scheme URL 解析原始 URL
- (NSURL *)originalURLFromStreamingURL:(NSURL *)streamingURL;

/// 从自定义 scheme URL 解析 songId
- (NSString *)songIdFromStreamingURL:(NSURL *)streamingURL;

@end

NS_ASSUME_NONNULL_END
