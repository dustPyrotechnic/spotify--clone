//
//  XCMusicMemoryCache.h
//  Spotify - clone
//
//  内存缓存管理器 - 只缓存当前和即将播放的歌曲
//

#import <Foundation/Foundation.h>

@class XC_YYSongData;

NS_ASSUME_NONNULL_BEGIN

@interface XCMusicMemoryCache : NSObject

+ (instancetype)sharedInstance;

#pragma mark - 查询
/// 歌曲是否在内存缓存中
- (BOOL)isCached:(NSString *)songId;

/// 获取缓存的音频数据
- (nullable NSData *)dataForSongId:(NSString *)songId;

#pragma mark - 写入
/// 缓存歌曲数据
- (void)cacheData:(NSData *)data forSongId:(NSString *)songId;

/// 从 URL 下载并缓存（后台异步）
- (void)downloadAndCache:(XC_YYSongData *)song;

#pragma mark - 当前播放管理
/// 设置当前播放歌曲（防被清理）
- (void)setCurrentPlayingSong:(NSString *)songId;

/// 获取当前播放歌曲的本地临时文件 URL（用于 AVPlayer）
- (nullable NSURL *)localURLForSongId:(NSString *)songId;

#pragma mark - 清理
/// 移除指定歌曲缓存
- (void)removeCache:(NSString *)songId;

/// 清空所有缓存
- (void)clearAllCache;

#pragma mark - 统计
/// 当前缓存占用内存大小（字节）
- (NSUInteger)currentCacheSize;

/// 缓存歌曲数量
- (NSUInteger)cachedSongCount;

@end

NS_ASSUME_NONNULL_END
