//
//  XCAudioSongCacheInfo.h
//  Spotify - clone
//

#import <Foundation/Foundation.h>

/// L3 层缓存索引模型：已完整缓存的歌曲元数据
/// @discussion 仅当歌曲确认完整并移动到 L3 后，才会在 index.plist 中创建此记录
/// @note 此模型只存在于 L3 层，不记录 L1/L2 的临时状态
@interface XCAudioSongCacheInfo : NSObject

/// 歌曲唯一标识
@property (nonatomic, copy) NSString *songId;

/// 音频文件总大小(字节)
@property (nonatomic, assign) NSInteger totalSize;

/// 缓存到 L3 的时间戳
@property (nonatomic, assign) NSTimeInterval cacheTime;

/// 最后播放时间戳
/// @note LRU 清理依据，每次播放时更新
@property (nonatomic, assign) NSTimeInterval lastPlayTime;

/// 播放次数统计
@property (nonatomic, assign) NSInteger playCount;

/// 文件 MD5 校验值（可选）
@property (nonatomic, copy, nullable) NSString *md5Hash;

/// 初始化方法
/// - Parameters:
///   - songId: 歌曲标识
///   - totalSize: 音频文件总大小
- (instancetype)initWithSongId:(NSString *)songId totalSize:(NSInteger)totalSize;

/// 更新播放时间
/// @discussion 每次从 L3 播放时调用，用于 LRU 排序
- (void)updatePlayTime;

@end
