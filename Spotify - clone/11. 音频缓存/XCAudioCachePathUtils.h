//
//  XCAudioCachePathUtils.h
//  Spotify - clone
//

#import <Foundation/Foundation.h>

/// 音频缓存系统路径管理工具
/// @discussion 提供 L2(Tmp) 和 L3(Cache) 层的路径管理服务
/// @note 单例模式，应用启动时自动创建所需目录
@interface XCAudioCachePathUtils : NSObject

/// 获取单例实例
+ (instancetype)sharedInstance;

/// L2 层临时目录路径
/// @note 对应：tmp/MusicTemp/
@property (nonatomic, copy, readonly) NSString *tempDirectory;

/// L3 层缓存目录路径
/// @note 对应：Library/Caches/MusicCache/
@property (nonatomic, copy, readonly) NSString *cacheDirectory;

/// 缓存索引文件路径
/// @note 对应：Library/Caches/MusicCache/index.plist
@property (nonatomic, copy, readonly) NSString *manifestPath;

/// 获取 L2 层临时文件完整路径
/// - Parameter songId: 歌曲标识
/// - Returns: tmp/MusicTemp/{songId}.mp3.tmp
- (NSString *)tempFilePathForSongId:(NSString *)songId;

/// 获取 L3 层缓存文件完整路径
/// - Parameter songId: 歌曲标识
/// - Returns: Library/Caches/MusicCache/{songId}.mp3
- (NSString *)cacheFilePathForSongId:(NSString *)songId;

/// 创建缓存目录（自动调用）
/// @discussion 初始化时自动执行，无需手动调用
- (void)createDirectories;

@end
