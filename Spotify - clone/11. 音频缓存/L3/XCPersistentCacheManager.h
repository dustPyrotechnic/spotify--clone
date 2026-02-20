//
//  XCPersistentCacheManager.h
//  Spotify - clone
//
//  L3 层缓存管理器：永久完整歌曲缓存
//  功能：管理 Library/Caches/MusicCache/ 下的完整音频文件
//

#import <Foundation/Foundation.h>

/// L3 层缓存管理器（磁盘永久缓存）
/// @discussion 只存储完整的歌曲文件，文件格式为 {songId}.mp3
/// @note 与 XCCacheIndexManager 配合使用，索引记录元数据，本管理器管理实际文件
@interface XCPersistentCacheManager : NSObject

/// 获取单例实例
+ (instancetype)sharedInstance;

#pragma mark - 写入操作

/// 将完整歌曲数据写入 L3 缓存
/// @param data 完整的歌曲二进制数据
/// @param songId 歌曲唯一标识
/// @return YES 表示写入成功
/// @discussion 写入后会自动更新 XCCacheIndexManager 中的索引
- (BOOL)writeCompleteSongData:(NSData *)data forSongId:(NSString *)songId;

/// 将临时文件移动到 L3 缓存（L2→L3 流转）
/// @param tempFilePath 临时文件路径（L2 层）
/// @param songId 歌曲唯一标识
/// @return YES 表示移动成功
/// @discussion 用于歌曲下载完整后，从临时位置移动到永久缓存
- (BOOL)moveTempFileToCache:(NSString *)tempFilePath forSongId:(NSString *)songId;

/// 将临时文件移动到缓存目录（指定目标路径）
/// - Parameters:
///   - tempFilePath: 临时文件路径
///   - cachePath: 目标缓存文件路径
///   - songId: 歌曲标识
/// - Returns: 是否移动成功
- (BOOL)moveTempFileToCache:(NSString *)tempFilePath 
                  cachePath:(NSString *)cachePath 
                  forSongId:(NSString *)songId;

#pragma mark - 读取操作

/// 获取缓存文件的 URL
/// @param songId 歌曲唯一标识
/// @return 文件 URL，如果不存在返回 nil
- (NSURL *)cachedURLForSongId:(NSString *)songId;

/// 获取缓存文件的本地路径
/// @param songId 歌曲唯一标识
/// @return 文件路径，如果不存在返回 nil
- (NSString *)cachedFilePathForSongId:(NSString *)songId;

#pragma mark - 查询操作

/// 检查是否有完整缓存
/// @param songId 歌曲唯一标识
/// @return YES 表示 L3 存在该歌曲的完整缓存
- (BOOL)hasCompleteCacheForSongId:(NSString *)songId;

/// 获取缓存文件大小
/// @param songId 歌曲唯一标识
/// @return 文件大小（字节），如果不存在返回 0
- (NSInteger)fileSizeForSongId:(NSString *)songId;

#pragma mark - 删除操作

/// 删除指定歌曲的缓存
/// @param songId 歌曲唯一标识
/// @discussion 删除文件并同步更新 XCCacheIndexManager 索引
- (void)deleteCacheForSongId:(NSString *)songId;

/// 清空所有 L3 缓存
/// @discussion 删除所有文件并清空索引
- (void)clearAllCache;

#pragma mark - 统计与清理

/// 获取当前缓存总大小
/// @return 所有缓存文件的总大小（字节）
- (NSInteger)totalCacheSize;

/// 获取缓存歌曲数量
/// @return 缓存的文件数量
- (NSInteger)cachedSongCount;

/// 执行 LRU 清理，删除最久未播放的歌曲
/// @param targetSize 目标缓存大小（字节）
/// @return 实际删除的歌曲数量
/// @discussion 根据 XCCacheIndexManager 中的 lastPlayTime 排序删除
- (NSInteger)cleanCacheToSize:(NSInteger)targetSize;

/// 执行 LRU 清理，保留指定大小的最新缓存
/// @param sizeToPreserve 要保留的大小（字节）
/// @return 实际删除的歌曲数量
- (NSInteger)cleanOldestCache:(NSInteger)sizeToPreserve;

@end
