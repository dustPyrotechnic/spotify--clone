//
//  XCMusicMemoryCache.h
//  Spotify - clone
//
//  内存缓存管理器 - 基于 NSCache 实现音频数据的内存缓存
//  使用 LRU 算法自动管理缓存，支持临时文件写入供 AVPlayer 播放
//

#import <Foundation/Foundation.h>

@class XC_YYSongData;

NS_ASSUME_NONNULL_BEGIN

@interface XCMusicMemoryCache : NSObject

+ (instancetype)sharedInstance;

#pragma mark - 查询
/// 基于 NSCache 的 key-value 查询，判断歌曲是否已缓存
- (BOOL)isCached:(NSString *)songId;
/// 从 NSCache 中获取缓存的音频数据
- (nullable NSData *)dataForSongId:(NSString *)songId;

#pragma mark - 写入
/// 将音频数据写入 NSCache，使用数据大小作为 cost 参与 LRU 淘汰计算
- (void)cacheData:(NSData *)data forSongId:(NSString *)songId;
/// 使用 NSURLSession 在后台并发队列下载歌曲并缓存
- (void)downloadAndCache:(XC_YYSongData *)song;

#pragma mark - 当前播放管理
/// 设置当前播放歌曲，通过重新 setObject 刷新其在 NSCache 中的优先级防止被清理
- (void)setCurrentPlayingSong:(NSString *)songId;
/// 将内存缓存数据写入临时文件，返回 file:// URL 供 AVPlayer 播放
- (nullable NSURL *)localURLForSongId:(NSString *)songId;

#pragma mark - 清理
/// 从 NSCache 和临时目录移除指定歌曲缓存
- (void)removeCache:(NSString *)songId;
/// 清空 NSCache 所有对象和临时目录所有文件
- (void)clearAllCache;

#pragma mark - 统计
/// 获取当前缓存占用内存大小（未实现）
- (NSUInteger)currentCacheSize;
/// 获取缓存歌曲数量（未实现）
- (NSUInteger)cachedSongCount;

@end

NS_ASSUME_NONNULL_END
