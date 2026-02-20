//
//  XCPreloadManager.m
//  Spotify - clone
//
//  Phase 7: 预加载管理器实现
//

#import "XCPreloadManager.h"
#import "XCAudioCacheManager.h"
#import "XCNetworkManager.h"
#import "XCAudioCachePathUtils.h"
#import "XCMemoryCacheManager.h"

// 预加载错误域
static NSString * const kXCPreloadErrorDomain = @"com.spotifyclone.preload";

// 预加载错误码
typedef NS_ENUM(NSInteger, XCPreloadErrorCode) {
    XCPreloadErrorCodeCancelled = -1,
    XCPreloadErrorCodeNetworkError = -2,
    XCPreloadErrorCodeInvalidResponse = -3,
    XCPreloadErrorCodeCacheError = -4
};

@interface XCPreloadManager () <NSURLSessionDataDelegate>

/// 任务队列（优先级队列）
@property (nonatomic, strong) NSMutableArray<XCPreloadTask *> *taskQueue;

/// 当前正在执行的任务
@property (nonatomic, strong) NSMutableArray<XCPreloadTask *> *activeTasks;

/// 所有任务的字典（songId -> task）
@property (nonatomic, strong) NSMutableDictionary<NSString *, XCPreloadTask *> *taskDictionary;

/// 队列访问锁
@property (nonatomic, strong) NSLock *queueLock;

/// URLSession
@property (nonatomic, strong) NSURLSession *urlSession;

/// 是否暂停
@property (nonatomic, assign, getter=isPaused) BOOL paused;

/// 当前播放的歌曲ID
@property (nonatomic, copy, nullable) NSString *currentPlayingSongId;

/// 下一首歌曲ID
@property (nonatomic, copy, nullable) NSString *nextPlayingSongId;

@end

@implementation XCPreloadManager

#pragma mark - 单例

+ (instancetype)sharedInstance {
    static XCPreloadManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // 【任务队列初始化】创建优先级队列和活跃任务列表
        _taskQueue = [NSMutableArray array];      // 等待执行的任务队列
        _activeTasks = [NSMutableArray array];    // 正在执行的任务
        _taskDictionary = [NSMutableDictionary dictionary]; // songId -> task 映射
        _queueLock = [[NSLock alloc] init];       // 队列访问锁
        _maxConcurrentTasks = 1;  // 【默认配置】单并发，避免影响当前播放
        _preloadSegmentLimit = 0; // 【默认配置】0 表示不限制分段数
        _paused = NO;
        
        // 【URLSession 配置】独立 session 用于预加载，不影响主播放器
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.timeoutIntervalForRequest = 30.0;
        config.timeoutIntervalForResource = 300.0;
        config.HTTPMaximumConnectionsPerHost = 2;
        _urlSession = [NSURLSession sessionWithConfiguration:config
                                                    delegate:self
                                               delegateQueue:[NSOperationQueue mainQueue]];
    }
    return self;
}

- (void)dealloc {
    [self.urlSession invalidateAndCancel];
}

#pragma mark - 预加载控制

- (void)preloadSong:(NSString *)songId priority:(XCAudioPreloadPriority)priority {
    [self preloadSong:songId priority:priority progressBlock:nil completionBlock:nil];
}

- (void)preloadSong:(NSString *)songId
           priority:(XCAudioPreloadPriority)priority
      progressBlock:(XCPreloadProgressBlock)progressBlock
    completionBlock:(XCPreloadCompletionBlock)completionBlock {
    // 【参数校验】songId 无效记录错误并返回
    if (!songId || songId.length == 0) {
        NSLog(@"[PreloadManager] 错误: songId 为空");
        return;
    }
    
    // 【线程安全】加锁保护队列操作
    [self.queueLock lock];
    
    // 【重复检查】检查是否已有该任务在队列或执行中
    XCPreloadTask *existingTask = self.taskDictionary[songId];
    if (existingTask) {
        // 【优先级提升】新优先级更高时更新并重新排序
        if (priority > existingTask.priority) {
            existingTask.priority = priority;
            [self sortTaskQueue];
            NSLog(@"[PreloadManager] 更新 %@ 优先级为 %ld", songId, (long)priority);
        }
        // 【回调更新】合并新的回调块
        if (progressBlock) {
            existingTask.progressBlock = progressBlock;
        }
        if (completionBlock) {
            existingTask.completionBlock = completionBlock;
        }
        [self.queueLock unlock];
        return;
    }
    
    // 【缓存检查】如已有 L3 完整缓存，直接回调成功并跳过
    XCAudioCacheManager *cacheManager = [XCAudioCacheManager sharedInstance];
    if ([cacheManager hasCompleteCacheForSongId:songId]) {
        NSLog(@"[PreloadManager] %@ 已有 L3 完整缓存，跳过预加载", songId);
        [self.queueLock unlock];
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(songId, YES, nil);
            });
        }
        return;
    }
    
    // 【创建任务】新建预加载任务并设置回调
    XCPreloadTask *task = [[XCPreloadTask alloc] initWithSongId:songId priority:priority];
    task.progressBlock = progressBlock;
    task.completionBlock = completionBlock;
    
    // 【加入队列】添加到队列和字典以便快速查找
    [self.taskQueue addObject:task];
    self.taskDictionary[songId] = task;
    
    // 【优先级排序】确保高优先级任务在前
    [self sortTaskQueue];
    
    NSLog(@"[PreloadManager] 添加预加载任务: %@, 优先级: %ld, 队列长度: %lu",
          songId, (long)priority, (unsigned long)self.taskQueue.count);
    
    [self.queueLock unlock];
    
    // 【启动检查】尝试启动下一个可执行任务
    [self processNextTask];
}

- (void)cancelPreloadForSongId:(NSString *)songId {
    if (!songId) return;
    
    [self.queueLock lock];
    
    XCPreloadTask *task = self.taskDictionary[songId];
    if (!task) {
        [self.queueLock unlock];
        return;
    }
    
    task.cancelled = YES;
    
    // 如果在队列中等待，直接移除
    if (!task.isExecuting) {
        [self.taskQueue removeObject:task];
        [self.taskDictionary removeObjectForKey:songId];
        NSLog(@"[PreloadManager] 取消等待中的任务: %@", songId);
    } else {
        // 如果正在执行，取消数据任务
        NSLog(@"[PreloadManager] 取消正在执行的任务: %@", songId);
        [task.dataTask cancel];
        [self.activeTasks removeObject:task];
        task.executing = NO;
        [self.taskDictionary removeObjectForKey:songId];
    }
    
    [self.queueLock unlock];
    
    // 触发完成回调（使用后台线程避免死锁）
    if (task.completionBlock) {
        NSError *error = [NSError errorWithDomain:kXCPreloadErrorDomain
                                             code:XCPreloadErrorCodeCancelled
                                         userInfo:@{NSLocalizedDescriptionKey: @"预加载已取消"}];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            task.completionBlock(songId, NO, error);
        });
    }
    
    // 继续处理下一个任务
    [self processNextTask];
}

- (void)cancelAllPreloads {
    [self.queueLock lock];
    
    NSLog(@"[PreloadManager] 取消所有预加载任务");
    
    // 取消所有正在执行的任务
    for (XCPreloadTask *task in self.activeTasks) {
        [task.dataTask cancel];
        task.cancelled = YES;
        task.executing = NO;
        
        if (task.completionBlock) {
            NSError *error = [NSError errorWithDomain:kXCPreloadErrorDomain
                                                 code:XCPreloadErrorCodeCancelled
                                             userInfo:@{NSLocalizedDescriptionKey: @"预加载已取消"}];
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                task.completionBlock(task.songId, NO, error);
            });
        }
    }
    [self.activeTasks removeAllObjects];
    
    // 清空等待队列
    [self.taskQueue removeAllObjects];
    [self.taskDictionary removeAllObjects];
    
    [self.queueLock unlock];
}

#pragma mark - 状态查询

- (BOOL)isPreloadingSong:(NSString *)songId {
    if (!songId) return NO;
    
    [self.queueLock lock];
    XCPreloadTask *task = self.taskDictionary[songId];
    BOOL isPreloading = (task != nil && !task.isCancelled);
    [self.queueLock unlock];
    
    return isPreloading;
}

- (CGFloat)preloadProgressForSong:(NSString *)songId {
    if (!songId) return 0.0;
    
    [self.queueLock lock];
    XCPreloadTask *task = self.taskDictionary[songId];
    CGFloat progress = task ? task.progress : 0.0;
    [self.queueLock unlock];
    
    return progress;
}

- (NSString *)currentPreloadingSongId {
    [self.queueLock lock];
    NSString *songId = nil;
    for (XCPreloadTask *task in self.activeTasks) {
        if (task.isExecuting) {
            songId = task.songId;
            break;
        }
    }
    [self.queueLock unlock];
    return songId;
}

- (NSInteger)totalPreloadTaskCount {
    [self.queueLock lock];
    NSInteger count = self.taskQueue.count + self.activeTasks.count;
    [self.queueLock unlock];
    return count;
}

- (NSInteger)pendingTaskCount {
    [self.queueLock lock];
    NSInteger count = self.taskQueue.count;
    [self.queueLock unlock];
    return count;
}

#pragma mark - 任务处理

/// 处理下一个任务
- (void)processNextTask {
    [self.queueLock lock];
    
    // 【状态检查】暂停状态下不启动新任务
    if (self.isPaused) {
        [self.queueLock unlock];
        return;
    }
    
    // 【并发控制】达到最大并发数时等待
    if (self.activeTasks.count >= (NSUInteger)self.maxConcurrentTasks) {
        [self.queueLock unlock];
        return;
    }
    
    // 【任务选取】从队列中选取优先级最高的可执行任务
    XCPreloadTask *nextTask = nil;
    for (XCPreloadTask *task in self.taskQueue) {
        if (!task.isExecuting && !task.isCancelled && !task.isCompleted) {
            nextTask = task;
            break;
        }
    }
    
    if (!nextTask) {
        [self.queueLock unlock];
        return;
    }
    
    // 【状态变更】标记为执行中并移动到活跃列表
    nextTask.executing = YES;
    [self.taskQueue removeObject:nextTask];
    [self.activeTasks addObject:nextTask];
    
    [self.queueLock unlock];
    
    // 【启动预加载】开始执行下载任务
    [self startPreloadTask:nextTask];
}

/// 开始预加载任务
- (void)startPreloadTask:(XCPreloadTask *)task {
    NSLog(@"[PreloadManager] 开始预加载: %@, 优先级: %ld", task.songId, (long)task.priority);
    
    // 获取歌曲 URL
    XCNetworkManager *networkManager = [XCNetworkManager sharedInstance];
    [networkManager findUrlOfSongWithId:task.songId completion:^(NSURL * _Nullable songUrl) {
        if (!songUrl) {
            NSLog(@"[PreloadManager] 获取歌曲 URL 失败: %@", task.songId);
            [self handleTaskCompletion:task success:NO error:nil];
            return;
        }
        
        // 检查是否需要 Range 请求（分段加载）
        [self preloadSongWithURL:songUrl task:task];
    }];
}

/// 预加载歌曲（分段方式）
- (void)preloadSongWithURL:(NSURL *)url task:(XCPreloadTask *)task {
    // 【加载策略】先加载前 3 个分段（约 1.5MB），确保可立即播放
    // 高优先级任务可继续加载更多分段
    
    NSInteger initialSegments = 3;  // 【预加载策略】优先加载前 3 段
    if (self.preloadSegmentLimit > 0 && self.preloadSegmentLimit < initialSegments) {
        initialSegments = self.preloadSegmentLimit;
    }
    
    // 【开始加载】从第一段开始顺序加载
    [self loadSegmentForTask:task
                         url:url
               segmentIndex:0
                   priority:task.priority
               totalSegments:initialSegments];
}

/// 加载单个分段
- (void)loadSegmentForTask:(XCPreloadTask *)task
                       url:(NSURL *)url
             segmentIndex:(NSInteger)segmentIndex
                 priority:(XCAudioPreloadPriority)priority
             totalSegments:(NSInteger)totalSegments {
    
    // 【取消检查】任务被取消时立即结束
    if (task.isCancelled) {
        [self handleTaskCompletion:task success:NO error:nil];
        return;
    }
    
    // 【限制检查】达到分段限制时标记完成
    if (self.preloadSegmentLimit > 0 && segmentIndex >= self.preloadSegmentLimit) {
        NSLog(@"[PreloadManager] %@ 已达到分段限制 %ld", task.songId, (long)self.preloadSegmentLimit);
        [self handleTaskCompletion:task success:YES error:nil];
        return;
    }
    
    // 【缓存检查】如该分段已存在则跳过并继续下一段
    XCAudioCacheManager *cacheManager = [XCAudioCacheManager sharedInstance];
    if ([cacheManager hasSegmentForSongId:task.songId segmentIndex:segmentIndex]) {
        NSLog(@"[PreloadManager] %@ 分段 %ld 已存在，跳过", task.songId, (long)segmentIndex);
        task.loadedSegments++;
        task.progress = (CGFloat)task.loadedSegments / (CGFloat)totalSegments;
        
        if (task.progressBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                task.progressBlock(task.songId, task.progress, task.loadedSegments, totalSegments);
            });
        }
        
        // 【递归加载】继续加载下一段
        [self loadSegmentForTask:task
                             url:url
                   segmentIndex:segmentIndex + 1
                       priority:priority
                   totalSegments:totalSegments];
        return;
    }
    
    // 【Range 请求】创建分段下载请求，每段 512KB
    NSInteger offset = segmentIndex * kAudioSegmentSize;
    NSString *rangeHeader = [NSString stringWithFormat:@"bytes=%ld-%ld",
                            (long)offset, (long)(offset + kAudioSegmentSize - 1)];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setValue:rangeHeader forHTTPHeaderField:@"Range"];
    
    NSLog(@"[PreloadManager] %@ 请求分段 %ld, Range: %@", task.songId, (long)segmentIndex, rangeHeader);
    
    // 创建数据任务
    task.dataTask = [self.urlSession dataTaskWithRequest:request
                                       completionHandler:^(NSData * _Nullable data,
                                                          NSURLResponse * _Nullable response,
                                                          NSError * _Nullable error) {
        if (task.isCancelled) {
            return;
        }
        
        if (error) {
            NSLog(@"[PreloadManager] %@ 分段 %ld 下载失败: %@", task.songId, (long)segmentIndex, error.localizedDescription);
            [self handleTaskCompletion:task success:NO error:error];
            return;
        }
        
        if (!data || data.length == 0) {
            // 可能是文件结束或空数据
            NSLog(@"[PreloadManager] %@ 分段 %ld 无数据，可能已加载完毕", task.songId, (long)segmentIndex);
            [self handleTaskCompletion:task success:YES error:nil];
            return;
        }
        
        // 存储到 L1 缓存
        [cacheManager storeSegment:data
                         forSongId:task.songId
                      segmentIndex:segmentIndex];
        
        NSLog(@"[PreloadManager] %@ 分段 %ld 加载完成 (%ld bytes)",
              task.songId, (long)segmentIndex, (long)data.length);
        
        task.loadedSegments++;
        task.progress = (CGFloat)task.loadedSegments / (CGFloat)totalSegments;
        
        // 进度回调
        if (task.progressBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                task.progressBlock(task.songId, task.progress, task.loadedSegments, totalSegments);
            });
        }
        
        // 检查是否完成或继续下一段
        BOOL isLastSegment = (data.length < kAudioSegmentSize);
        if (isLastSegment || segmentIndex >= totalSegments - 1) {
            // 完成
            [self handleTaskCompletion:task success:YES error:nil];
        } else {
            // 继续下一段
            [self loadSegmentForTask:task
                                 url:url
                       segmentIndex:segmentIndex + 1
                           priority:priority
                       totalSegments:totalSegments];
        }
    }];
    
    [task.dataTask resume];
}

/// 处理任务完成
- (void)handleTaskCompletion:(XCPreloadTask *)task success:(BOOL)success error:(NSError *)error {
    [self.queueLock lock];
    
    task.executing = NO;
    task.completed = success;
    [self.activeTasks removeObject:task];
    [self.taskDictionary removeObjectForKey:task.songId];
    
    [self.queueLock unlock];
    
    NSLog(@"[PreloadManager] %@ 预加载完成, 成功: %d, 已加载分段: %ld",
          task.songId, success, (long)task.loadedSegments);
    
    // 完成回调（使用后台线程避免死锁）
    if (task.completionBlock) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            task.completionBlock(task.songId, success, error);
        });
    }
    
    // 继续处理下一个任务
    [self processNextTask];
}

/// 对任务队列进行排序
- (void)sortTaskQueue {
    [self.taskQueue sortUsingSelector:@selector(comparePriority:)];
}

#pragma mark - 批量操作

- (void)preloadSongs:(NSArray<NSString *> *)songIds priority:(XCAudioPreloadPriority)priority {
    for (NSString *songId in songIds) {
        [self preloadSong:songId priority:priority];
    }
}

- (void)setCurrentPlayingSong:(NSString *)songId {
    self.currentPlayingSongId = songId;
    
    // 清理已播放歌曲的预加载缓存（可选）
    // 这里可以选择清理 L1 中之前歌曲的分段
}

- (void)setNextPlayingSong:(NSString *)songId {
    self.nextPlayingSongId = songId;
    [self preloadSong:songId priority:XCAudioPreloadPriorityHigh];
}

#pragma mark - 工具方法

- (NSDictionary *)preloadStatistics {
    [self.queueLock lock];
    
    NSDictionary *stats = @{
        @"totalTasks": @(self.taskQueue.count + self.activeTasks.count),
        @"pendingTasks": @(self.taskQueue.count),
        @"activeTasks": @(self.activeTasks.count),
        @"maxConcurrentTasks": @(self.maxConcurrentTasks),
        @"isPaused": @(self.isPaused)
    };
    
    [self.queueLock unlock];
    
    return stats;
}

- (void)pauseAllPreloads {
    self.paused = YES;
    NSLog(@"[PreloadManager] 预加载已暂停");
}

- (void)resumePreloads {
    self.paused = NO;
    NSLog(@"[PreloadManager] 预加载已恢复");
    [self processNextTask];
}

@end

#pragma mark - XCPreloadTask 实现

@implementation XCPreloadTask

- (instancetype)initWithSongId:(NSString *)songId priority:(XCAudioPreloadPriority)priority {
    self = [super init];
    if (self) {
        _songId = [songId copy];
        _priority = priority;
        _createTime = [[NSDate date] timeIntervalSince1970];
        _progress = 0.0;
        _loadedSegments = 0;
        _totalSegments = 0;
        _executing = NO;
        _completed = NO;
        _cancelled = NO;
    }
    return self;
}

- (NSComparisonResult)comparePriority:(XCPreloadTask *)otherTask {
    // 优先级高的排在前面
    if (self.priority > otherTask.priority) {
        return NSOrderedAscending;
    } else if (self.priority < otherTask.priority) {
        return NSOrderedDescending;
    } else {
        // 相同优先级，创建时间早的排在前面（FIFO）
        if (self.createTime < otherTask.createTime) {
            return NSOrderedAscending;
        } else if (self.createTime > otherTask.createTime) {
            return NSOrderedDescending;
        } else {
            return NSOrderedSame;
        }
    }
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<XCPreloadTask: %@, priority=%ld, progress=%.2f, executing=%d>",
            self.songId, (long)self.priority, self.progress, self.isExecuting];
}

@end
