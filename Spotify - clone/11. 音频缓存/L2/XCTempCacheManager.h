//
//  XCTempCacheManager.h
//  Spotify - clone
//
//  L2 层缓存管理器：临时完整歌曲缓存
//  功能：管理 tmp/MusicTemp/ 下的临时音频文件（可能不完整）
//

#import <Foundation/Foundation.h>

/// L2 层缓存管理器（临时文件缓存）
/// @discussion 存储正在下载或未完成验证的歌曲文件，文件格式为 {songId}.mp3.tmp
/// @note 临时文件可能不完整，需要通过 isTempFileComplete:expectedSize: 验证完整性后才能移动到 L3
@interface XCTempCacheManager : NSObject

/// 获取单例实例
+ (instancetype)sharedInstance;

#pragma mark - 写入操作

/// 追加写入临时文件
/// @param data 要写入的数据块
/// @param songId 歌曲唯一标识
/// @return YES 表示写入成功
/// @discussion 如果临时文件不存在会自动创建，存在则追加到文件末尾
- (BOOL)writeTempSongData:(NSData *)data forSongId:(NSString *)songId;

/// 追加写入临时文件（带正确的扩展名）
/// @param data 要写入的数据块
/// @param songId 歌曲唯一标识
/// @param originalURL 原始音频 URL，用于确定正确的文件扩展名
/// @return YES 表示写入成功
- (BOOL)writeTempSongData:(NSData *)data forSongId:(NSString *)songId originalURL:(NSURL *)originalURL;

/// 创建或打开临时文件的写入句柄
/// @param songId 歌曲唯一标识
/// @return NSFileHandle 实例，失败返回 nil
/// @discussion 用于需要多次追加写入的场景，使用完后需要调用 closeFile
- (NSFileHandle *)fileHandleForWritingTempFile:(NSString *)songId;

#pragma mark - 读取操作

/// 获取临时文件的 URL
/// @param songId 歌曲唯一标识
/// @return 文件 URL，如果不存在返回 nil
- (NSURL *)tempFileURLForSongId:(NSString *)songId;

/// 获取临时文件的 URL（带正确的扩展名）
/// - Parameters:
///   - songId: 歌曲唯一标识
///   - originalURL: 原始音频 URL，用于确定正确的文件扩展名
/// - Returns: 文件 URL，如果不存在返回 nil
- (NSURL *)tempFileURLForSongId:(NSString *)songId originalURL:(NSURL *)originalURL;

/// 获取临时文件的本地路径
/// @param songId 歌曲唯一标识
/// @return 文件路径，如果不存在返回 nil
- (NSString *)tempFilePathForSongId:(NSString *)songId;

/// 获取临时文件的本地路径（带正确的扩展名）
/// - Parameters:
///   - songId: 歌曲唯一标识
///   - originalURL: 原始音频 URL，用于确定正确的文件扩展名
/// - Returns: 文件路径，如果不存在返回 nil
- (NSString *)tempFilePathForSongId:(NSString *)songId originalURL:(NSURL *)originalURL;

#pragma mark - 查询操作

/// 检查临时文件是否存在
/// @param songId 歌曲唯一标识
/// @return YES 表示 L2 存在该歌曲的临时文件
- (BOOL)hasTempFileForSongId:(NSString *)songId;

/// 检查临时文件是否存在（带正确的扩展名）
/// - Parameters:
///   - songId: 歌曲唯一标识
///   - originalURL: 原始音频 URL，用于确定正确的文件扩展名
/// - Returns: YES 表示 L2 存在该歌曲的临时文件
- (BOOL)hasTempFileForSongId:(NSString *)songId originalURL:(NSURL *)originalURL;

/// 获取临时文件大小
/// @param songId 歌曲唯一标识
/// @return 文件大小（字节），如果不存在返回 0
- (NSInteger)tempFileSizeForSongId:(NSString *)songId;

/// 验证临时文件是否完整
/// @param songId 歌曲唯一标识
/// @param expectedSize 期望的文件大小（通常来自 HTTP Content-Length）
/// @return YES 表示文件大小与期望值匹配
/// @discussion 用于判断歌曲是否下载完整，可以移动到 L3
- (BOOL)isTempFileComplete:(NSString *)songId expectedSize:(NSInteger)expectedSize;

#pragma mark - 删除操作

/// 删除指定歌曲的临时文件
/// @param songId 歌曲唯一标识
/// @discussion 删除 L2 临时文件，不影响 L1/L3
- (void)deleteTempFileForSongId:(NSString *)songId;

/// 清空所有 L2 临时缓存
/// @discussion 删除 tmp/MusicTemp/ 目录下所有 .mp3.tmp 文件
- (void)clearAllTempCache;

#pragma mark - L2 → L3 流转

/// 将临时文件移动到 L3 永久缓存
/// @param songId 歌曲唯一标识
/// @return YES 表示移动成功
/// @discussion 内部会验证文件存在性，移动到 L3 后会自动删除 L2 临时文件并更新索引
- (BOOL)moveToPersistentCache:(NSString *)songId;

/// 验证完整性并移动到 L3
/// @param songId 歌曲唯一标识
/// @param expectedSize 期望的文件大小
/// @return YES 表示验证通过且移动成功
/// @discussion 先验证文件完整性，完整则移动到 L3，不完整返回 NO
- (BOOL)confirmCompleteAndMoveToCache:(NSString *)songId expectedSize:(NSInteger)expectedSize;

#pragma mark - 过期清理

/// 清理过期的临时文件（默认7天）
/// @return 清理的文件数量
/// @discussion 删除创建时间超过 kAudioTempFileExpireTime 的文件
- (NSInteger)cleanExpiredTempFiles;

/// 清理指定天数前的临时文件
/// @param days 天数阈值
/// @return 清理的文件数量
- (NSInteger)cleanTempFilesOlderThanDays:(NSInteger)days;

#pragma mark - 统计信息

/// 获取临时缓存总大小
/// @return 所有临时文件的总大小（字节）
- (NSInteger)totalTempCacheSize;

/// 获取临时文件数量
/// @return 临时文件数量
- (NSInteger)tempFileCount;

@end
