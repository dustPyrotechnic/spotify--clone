//
//  XCCacheIndexManager.h
//  Spotify - clone
//
//  L3 层缓存索引管理器
//  功能：管理 Library/Caches/MusicCache/index.plist 的读写
//  用途：记录已完整缓存的歌曲元数据，支持 LRU 清理
//

#import <Foundation/Foundation.h>
@class XCAudioSongCacheInfo;

@interface XCCacheIndexManager : NSObject

/// 获取单例实例
+ (instancetype)sharedInstance;

/// 添加歌曲缓存记录
/// @discussion 当歌曲确认完整并从 L2 移动到 L3 后调用
- (void)addSongCacheInfo:(XCAudioSongCacheInfo *)info;

/// 查询歌曲缓存信息
/// @param songId 歌曲标识
/// @return XCAudioSongCacheInfo 或 nil（未缓存）
- (XCAudioSongCacheInfo *)getSongCacheInfo:(NSString *)songId;

/// 移除歌曲缓存记录
/// @discussion 删除 L3 缓存文件时同步调用
- (void)removeSongCacheInfo:(NSString *)songId;

/// 更新歌曲最后播放时间
/// @discussion 每次从 L3 播放时调用，用于 LRU 排序
- (void)updatePlayTimeForSongId:(NSString *)songId;

/// 获取当前缓存总大小
- (NSInteger)totalCacheSize;

/// 获取缓存歌曲数量
- (NSInteger)cachedSongCount;

/// 执行 LRU 清理，删除最久未播放的歌曲直到总大小小于 targetSize
/// @param targetSize 目标缓存大小（字节）
/// @return 实际删除的歌曲数量
- (NSInteger)cleanCacheToSize:(NSInteger)targetSize;

/// 删除所有缓存记录和文件
- (void)clearAllCache;

@end
