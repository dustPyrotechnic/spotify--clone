//
//  XCPreloadManager.h
//  Spotify - clone
//
//  Phase 7: 预加载管理器
//  功能：管理音频资源的预加载，支持优先级队列和进度回调
//

#import <Foundation/Foundation.h>
#import "XCAudioCacheConst.h"

@class XCPreloadTask;

/// 预加载进度回调块
/// @param songId 歌曲ID
/// @param progress 预加载进度 0.0 - 1.0
/// @param loadedSegments 已加载分段数
/// @param totalSegments 总分段数
typedef void(^XCPreloadProgressBlock)(NSString *songId, CGFloat progress, NSInteger loadedSegments, NSInteger totalSegments);

/// 预加载完成回调块
/// @param songId 歌曲ID
/// @param success 是否成功完成
/// @param error 错误信息（失败时有效）
typedef void(^XCPreloadCompletionBlock)(NSString *songId, BOOL success, NSError * _Nullable error);

/// 预加载管理器
/// @discussion 管理音频资源的预加载，支持优先级队列、并发控制和进度回调
/// @note 与 XCAudioCacheManager 集成，预加载的分段存储在 L1 层
@interface XCPreloadManager : NSObject

/// 获取单例实例
+ (instancetype)sharedInstance;

#pragma mark - 预加载控制

/// 开始预加载歌曲
/// @param songId 歌曲唯一标识
/// @param priority 预加载优先级
/// @discussion 如果该歌曲已在预加载队列中，会更新其优先级
- (void)preloadSong:(NSString *)songId
           priority:(XCAudioPreloadPriority)priority;

/// 开始预加载歌曲（带回调）
/// @param songId 歌曲唯一标识
/// @param priority 预加载优先级
/// @param progressBlock 进度回调（可选）
/// @param completionBlock 完成回调（可选）
- (void)preloadSong:(NSString *)songId
           priority:(XCAudioPreloadPriority)priority
      progressBlock:(nullable XCPreloadProgressBlock)progressBlock
    completionBlock:(nullable XCPreloadCompletionBlock)completionBlock;

/// 取消指定歌曲的预加载
/// @param songId 歌曲唯一标识
/// @discussion 如果该歌曲正在预加载，会立即停止
- (void)cancelPreloadForSongId:(NSString *)songId;

/// 取消所有预加载任务
- (void)cancelAllPreloads;

#pragma mark - 状态查询

/// 检查指定歌曲是否正在预加载
/// @param songId 歌曲唯一标识
/// @return YES 表示正在预加载
- (BOOL)isPreloadingSong:(NSString *)songId;

/// 获取指定歌曲的预加载进度
/// @param songId 歌曲唯一标识
/// @return 预加载进度 0.0 - 1.0，未在预加载返回 0
- (CGFloat)preloadProgressForSong:(NSString *)songId;

/// 获取当前正在预加载的歌曲ID
@property (nonatomic, copy, readonly, nullable) NSString *currentPreloadingSongId;

/// 获取当前预加载任务总数（包括队列中等待的）
@property (nonatomic, assign, readonly) NSInteger totalPreloadTaskCount;

/// 获取等待队列中的任务数
@property (nonatomic, assign, readonly) NSInteger pendingTaskCount;

#pragma mark - 配置

/// 最大并发预加载任务数，默认 1
@property (nonatomic, assign) NSInteger maxConcurrentTasks;

/// 预加载分段数量限制（0 表示不限制）
/// @discussion 设置为 3 表示只预加载前 3 个分段（约 1.5MB），确保立即播放
@property (nonatomic, assign) NSInteger preloadSegmentLimit;

#pragma mark - 批量操作

/// 预加载多首歌曲
/// @param songIds 歌曲ID数组
/// @param priority 预加载优先级
/// @discussion 按数组顺序依次加入队列
- (void)preloadSongs:(NSArray<NSString *> *)songIds
            priority:(XCAudioPreloadPriority)priority;

/// 设置当前播放歌曲，自动调整预加载优先级
/// @param songId 当前播放的歌曲ID
/// @discussion 会自动将下一首设为高优先级，清理已播放歌曲的预加载
- (void)setCurrentPlayingSong:(NSString *)songId;

/// 设置即将播放的下一首歌曲（用于高优先级预加载）
/// @param songId 下一首歌曲ID
/// @discussion 等价于 preloadSong:priority:XCAudioPreloadPriorityHigh
- (void)setNextPlayingSong:(NSString *)songId;

#pragma mark - 工具方法

/// 获取预加载统计信息
/// @return 包含统计信息的字典
- (NSDictionary *)preloadStatistics;

/// 暂停所有预加载（保留队列）
- (void)pauseAllPreloads;

/// 恢复预加载
- (void)resumePreloads;

@end

#pragma mark - XCPreloadTask

/// 预加载任务模型
/// @discussion 内部使用，描述一个预加载任务
@interface XCPreloadTask : NSObject

/// 歌曲ID
@property (nonatomic, copy, readonly) NSString *songId;

/// 预加载优先级
@property (nonatomic, assign) XCAudioPreloadPriority priority;

/// 任务创建时间
@property (nonatomic, assign, readonly) NSTimeInterval createTime;

/// 当前进度 0.0 - 1.0
@property (nonatomic, assign) CGFloat progress;

/// 已加载分段数
@property (nonatomic, assign) NSInteger loadedSegments;

/// 总分段数（预估，可能为 0 表示未知）
@property (nonatomic, assign) NSInteger totalSegments;

/// 进度回调
@property (nonatomic, copy, nullable) XCPreloadProgressBlock progressBlock;

/// 完成回调
@property (nonatomic, copy, nullable) XCPreloadCompletionBlock completionBlock;

/// 当前的数据任务
@property (nonatomic, strong, nullable) NSURLSessionDataTask *dataTask;

/// 是否正在执行
@property (nonatomic, assign, getter=isExecuting) BOOL executing;

/// 是否已完成
@property (nonatomic, assign, getter=isCompleted) BOOL completed;

/// 是否已取消
@property (nonatomic, assign, getter=isCancelled) BOOL cancelled;

/// 初始化方法
- (instancetype)initWithSongId:(NSString *)songId
                      priority:(XCAudioPreloadPriority)priority;

/// 比较优先级（用于排序）
/// @param otherTask 另一个任务
/// @return NSOrderedAscending 表示 self 优先级更高
- (NSComparisonResult)comparePriority:(XCPreloadTask *)otherTask;

@end
