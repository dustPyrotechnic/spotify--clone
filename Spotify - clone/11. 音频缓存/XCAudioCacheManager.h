//
//  XCAudioCacheManager.h
//  Spotify - clone
//
//  Phase 6: 音频缓存主管理器
//  功能：整合 L1/L2/L3 三层缓存，提供统一接口
//

#import <Foundation/Foundation.h>
#import "XCAudioCacheConst.h"

@class XCAudioSongCacheInfo;

/// 音频缓存主管理器
/// @discussion 整合 L1(NSCache分段)/L2(临时文件)/L3(完整缓存)三层架构
/// @note 作为播放器与缓存系统的唯一接口，处理数据流转和查询
@interface XCAudioCacheManager : NSObject

/// 获取单例实例
+ (instancetype)sharedInstance;

#pragma mark - URL 记录

/// 记录 songId 对应的原始 URL，用于确定正确的文件扩展名
/// @param url 原始音频 URL
/// @param songId 歌曲唯一标识
/// @discussion 在播放网络音频时调用，确保缓存文件使用正确的扩展名
- (void)recordOriginalURL:(NSURL *)url forSongId:(NSString *)songId;

#pragma mark - 三级查询（L3 → L2 → nil）

/// 查询歌曲缓存状态
/// @param songId 歌曲唯一标识
/// @return 当前缓存状态（None/InMemory/TempFile/Complete）
- (XCAudioFileCacheState)cacheStateForSongId:(NSString *)songId;

/// 获取可用于播放的本地文件 URL
/// @param songId 歌曲唯一标识
/// @return 文件 URL，无缓存时返回 nil
/// @discussion 查询顺序：L3(完整缓存) → L2(临时文件) → nil
- (NSURL *)cachedURLForSongId:(NSString *)songId;

/// 获取可用于播放的本地文件路径
/// @param songId 歌曲唯一标识
/// @return 文件路径，无缓存时返回 nil
- (NSString *)cachedFilePathForSongId:(NSString *)songId;




/// 检查是否有 L3 完整缓存
/// @param songId 歌曲唯一标识
- (BOOL)hasCompleteCacheForSongId:(NSString *)songId;

/// 检查是否有 L2 临时缓存
/// @param songId 歌曲唯一标识
- (BOOL)hasTempCacheForSongId:(NSString *)songId;

/// 检查是否有 L1 内存分段缓存
/// @param songId 歌曲唯一标识
- (BOOL)hasMemoryCacheForSongId:(NSString *)songId;

#pragma mark - L1层操作（内存分段）

/// 存储分段数据到 L1
/// @param data 分段二进制数据
/// @param songId 歌曲唯一标识
/// @param segmentIndex 分段索引
- (void)storeSegment:(NSData *)data
           forSongId:(NSString *)songId
        segmentIndex:(NSInteger)segmentIndex;

/// 从 L1 读取分段数据
/// @param songId 歌曲唯一标识
/// @param segmentIndex 分段索引
/// @return 分段数据，不存在返回 nil
- (NSData *)getSegmentForSongId:(NSString *)songId
                   segmentIndex:(NSInteger)segmentIndex;

/// 检查 L1 中是否存在指定分段
/// @param songId 歌曲唯一标识
/// @param segmentIndex 分段索引
- (BOOL)hasSegmentForSongId:(NSString *)songId
               segmentIndex:(NSInteger)segmentIndex;

/// 获取指定歌曲的所有分段
/// @param songId 歌曲唯一标识
/// @return XCAudioSegmentInfo 数组，按索引排序
- (NSArray *)getAllSegmentsForSongId:(NSString *)songId;

/// 获取指定歌曲的分段数量
/// @param songId 歌曲唯一标识
- (NSInteger)segmentCountForSongId:(NSString *)songId;

/// 清空指定歌曲的 L1 分段缓存
/// @param songId 歌曲唯一标识
- (void)clearMemoryCacheForSongId:(NSString *)songId;

#pragma mark - 数据流转（切歌时调用）

/// 将当前歌曲的 L1 分段合并写入 L2（切歌时调用）
/// @param songId 歌曲唯一标识
/// @return YES 表示写入成功
/// @discussion 切歌时调用，将内存中的分段合并为临时文件
- (BOOL)finalizeCurrentSong:(NSString *)songId;

/// 验证 L2 临时文件并移动到 L3（歌曲完整下载后调用）
/// @param songId 歌曲唯一标识
/// @param expectedSize 期望的文件大小（来自 HTTP Content-Length）
/// @return YES 表示验证通过且移动成功
/// @discussion 歌曲下载完成后调用，确认完整后移入永久缓存
- (BOOL)confirmCompleteSong:(NSString *)songId
               expectedSize:(NSInteger)expectedSize;

/// 完整的切歌流程：L1 → L2 → L3（如果需要）
/// @param songId 要保存的歌曲 ID
/// @param expectedSize 期望的文件大小（可选，0 表示不验证）
/// @return 最终缓存状态
/// @discussion 封装完整的切歌保存流程，包括合并、验证、移动
- (XCAudioFileCacheState)saveAndFinalizeSong:(NSString *)songId
                                expectedSize:(NSInteger)expectedSize;

#pragma mark - 预加载支持

/// 设置当前优先歌曲（正在播放的歌曲）
/// @param songId 歌曲唯一标识
/// @discussion 提升该歌曲分段的优先级，内存紧张时优先保留
- (void)setCurrentPrioritySong:(NSString *)songId;

/// 获取当前优先歌曲 ID
@property (nonatomic, copy, readonly) NSString *currentPrioritySongId;

#pragma mark - 删除操作

/// 删除指定歌曲的所有层级缓存
/// @param songId 歌曲唯一标识
/// @discussion 删除 L1/L2/L3 中该歌曲的所有缓存
- (void)deleteAllCacheForSongId:(NSString *)songId;

/// 删除指定歌曲的 L3 完整缓存
/// @param songId 歌曲唯一标识
- (void)deleteCompleteCacheForSongId:(NSString *)songId;

/// 删除指定歌曲的 L2 临时缓存
/// @param songId 歌曲唯一标识
- (void)deleteTempCacheForSongId:(NSString *)songId;

/// 清空所有缓存（L1 + L2 + L3）
- (void)clearAllCache;

/// 清空 L1 内存缓存
- (void)clearMemoryCache;

/// 清空 L2 临时缓存
- (void)clearTempCache;

/// 清空 L3 完整缓存
- (void)clearCompleteCache;

#pragma mark - 统计信息

/// 获取 L1 内存缓存大小（近似值）
- (NSInteger)memoryCacheSize;

/// 获取 L2 临时缓存总大小
- (NSInteger)tempCacheSize;

/// 获取 L3 完整缓存总大小
- (NSInteger)completeCacheSize;

/// 获取所有层级缓存总大小
- (NSInteger)totalCacheSize;

/// 获取 L3 缓存歌曲数量
- (NSInteger)completeCacheSongCount;

/// 获取 L2 临时文件数量
- (NSInteger)tempCacheFileCount;

/// 获取缓存统计信息（调试用）
/// @return 包含各层统计的字典
- (NSDictionary *)cacheStatistics;

#pragma mark - 容量管理

/// 检查 L3 缓存是否超过限制
/// @return YES 表示超过 kAudioCacheDiskLimit
- (BOOL)isCompleteCacheOverLimit;

/// 执行 L3 LRU 清理
/// @param targetSize 目标大小（字节）
/// @return 删除的歌曲数量
- (NSInteger)cleanCompleteCacheToSize:(NSInteger)targetSize;

/// 清理过期的 L2 临时文件
/// @return 删除的文件数量
- (NSInteger)cleanExpiredTempFiles;

#pragma mark - 缓存索引查询

/// 获取缓存索引中的歌曲信息
/// @param songId 歌曲唯一标识
/// @return XCAudioSongCacheInfo 或 nil
- (XCAudioSongCacheInfo *)cacheInfoForSongId:(NSString *)songId;

/// 更新歌曲播放时间（用于 LRU）
/// @param songId 歌曲唯一标识
- (void)updatePlayTimeForSongId:(NSString *)songId;

@end
