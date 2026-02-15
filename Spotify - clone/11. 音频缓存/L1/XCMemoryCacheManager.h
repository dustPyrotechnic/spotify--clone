//
//  XCMemoryCacheManager.h
//  Spotify - clone
//
//  L1 层缓存管理器：NSCache 分段缓存
//  功能：管理内存中的音频分段缓存，提供高速访问
//

#import <Foundation/Foundation.h>

@class XCAudioSegmentInfo;

/// L1 层缓存管理器（NSCache）
/// @discussion 使用 NSCache 存储音频分段数据，支持内存警告自动清理
/// @note Key 格式: "{songId}_{segmentIndex}" (例如: "123456_0")
@interface XCMemoryCacheManager : NSObject

/// 获取单例实例
+ (instancetype)sharedInstance;

#pragma mark - 分段存储与读取

/// 存储分段数据到 L1 缓存
/// @param data 分段二进制数据
/// @param songId 歌曲唯一标识
/// @param segmentIndex 分段索引，从 0 开始
/// @discussion 如果该分段已存在，会覆盖旧数据
- (void)storeSegmentData:(NSData *)data
              forSongId:(NSString *)songId
           segmentIndex:(NSInteger)segmentIndex;

/// 从 L1 缓存读取分段数据
/// @param songId 歌曲唯一标识
/// @param segmentIndex 分段索引
/// @return 分段数据，如果不存在返回 nil
- (NSData *)segmentDataForSongId:(NSString *)songId
                    segmentIndex:(NSInteger)segmentIndex;

/// 检查指定分段是否存在于 L1 缓存
/// @param songId 歌曲唯一标识
/// @param segmentIndex 分段索引
/// @return YES 表示存在，NO 表示不存在
- (BOOL)hasSegmentForSongId:(NSString *)songId
               segmentIndex:(NSInteger)segmentIndex;

/// 获取指定歌曲的所有分段（按索引排序）
/// @param songId 歌曲唯一标识
/// @return XCAudioSegmentInfo 数组，按 index 升序排列
/// @discussion 用于切歌时将 L1 分段合并到 L2
- (NSArray<XCAudioSegmentInfo *> *)getAllSegmentsForSongId:(NSString *)songId;

/// 清空指定歌曲的所有分段
/// @param songId 歌曲唯一标识
/// @discussion 切歌完成或歌曲已完整缓存到 L3 后调用
- (void)clearSegmentsForSongId:(NSString *)songId;

#pragma mark - 优先级管理

/// 设置当前播放歌曲，提升其分段优先级
/// @param songId 当前播放的歌曲 ID
/// @discussion 当前歌曲的分段在内存紧张时最后被清理
- (void)setCurrentSongPriority:(NSString *)songId;

/// 获取当前优先歌曲 ID
@property (nonatomic, copy, readonly) NSString *currentPrioritySongId;

#pragma mark - 缓存统计

/// 获取缓存总成本（近似内存占用，字节）
/// @discussion NSCache 的 totalCostLimit 统计
@property (nonatomic, assign, readonly) NSInteger totalCost;

/// 获取缓存中歌曲数量（唯一 songId 数量）
- (NSInteger)cachedSongCount;

/// 获取指定歌曲的分段数量
/// @param songId 歌曲唯一标识
- (NSInteger)segmentCountForSongId:(NSString *)songId;

#pragma mark - 内存管理

/// 手动清理所有缓存（非当前优先歌曲）
/// @discussion 接收到内存警告时自动调用，也可手动触发
- (void)trimCache;

/// 清空所有缓存（包括当前优先歌曲）
- (void)clearAllCache;

@end
