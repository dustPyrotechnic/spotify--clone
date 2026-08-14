//
//  XCSongCommentService.m
//  Spotify - clone
//
//  Created by Kimi on 2026/03/03.
//

#import "XCSongCommentService.h"
#import "XCSongCommentList.h"
#import "XCSongCommentFloorList.h"
#import <AFNetworking/AFNetworking.h>

// 网易云 API 基础 URL（使用项目现有的）
static NSString * const kWYBaseURL = @"https://1390963969-2g6ivueiij.ap-guangzhou.tencentscf.com";

// 请求超时时间
static const NSTimeInterval kCommentRequestTimeout = 15.0;

@interface XCSongCommentService ()

@property (nonatomic, strong) AFHTTPSessionManager *sessionManager;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSURLSessionDataTask *> *activeTasks;
/// 串行队列保护 activeTasks 的并发读写
@property (nonatomic, strong) dispatch_queue_t tasksQueue;

@end

@implementation XCSongCommentService

#pragma mark - Singleton

+ (instancetype)sharedInstance {
    static XCSongCommentService *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _activeTasks = [NSMutableDictionary dictionary];
        _tasksQueue = dispatch_queue_create("com.xcmusicplayer.commentservice.tasks", DISPATCH_QUEUE_SERIAL);
        [self setupSessionManager];
    }
    return self;
}

- (void)setupSessionManager {
    NSURL *baseURL = [NSURL URLWithString:kWYBaseURL];
    self.sessionManager = [[AFHTTPSessionManager alloc] initWithBaseURL:baseURL];
    
    // 配置请求序列化器
    self.sessionManager.requestSerializer = [AFHTTPRequestSerializer serializer];
    self.sessionManager.requestSerializer.timeoutInterval = kCommentRequestTimeout;
    
    // 配置响应序列化器
    self.sessionManager.responseSerializer = [AFJSONResponseSerializer serializer];
    self.sessionManager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript", @"text/html", @"text/plain", nil];
}

#pragma mark - 主评论列表

- (NSURLSessionDataTask *)fetchCommentsForSongId:(NSString *)songId
                                          sortType:(XCCommentSortType)sortType
                                             limit:(NSInteger)limit
                                            before:(nullable NSString *)beforeCursor
                                        completion:(void (^)(XCSongCommentList *_Nullable, NSError *_Nullable))completion {
    
    if (!songId || songId.length == 0) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:@"XCSongCommentService" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"歌曲ID不能为空"}];
            completion(nil, error);
        }
        return nil;
    }
    
    // 构建参数
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[@"id"] = songId;
    params[@"limit"] = @(limit > 0 ? limit : 20);
    // sortType: 2 = 热度排序，3 = 时间排序（最新）
    params[@"sortType"] = sortType == XCCommentSortTypeLatest ? @3 : @2;

    // 超过5000条时使用 before 分页
    if (beforeCursor && beforeCursor.length > 0) {
        params[@"before"] = beforeCursor;
    }
    
    NSString *taskKey = [NSString stringWithFormat:@"comments_%@", songId];

    // 取消已有的同歌曲请求
    [self cancelRequestForSongId:songId];

    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [self.sessionManager GET:@"/comment/music"
                                               parameters:params
                                                  headers:nil
                                                 progress:nil
                                                  success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        dispatch_async(weakSelf.tasksQueue, ^{
            [weakSelf.activeTasks removeObjectForKey:taskKey];
        });

        if (![responseObject isKindOfClass:[NSDictionary class]]) {
            if (completion) {
                NSError *error = [NSError errorWithDomain:@"XCSongCommentService" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"返回数据格式错误"}];
                completion(nil, error);
            }
            return;
        }

        XCSongCommentList *commentList = [[XCSongCommentList alloc] initWithDictionary:responseObject];
        if (completion) {
            completion(commentList, nil);
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        dispatch_async(weakSelf.tasksQueue, ^{
            [weakSelf.activeTasks removeObjectForKey:taskKey];
        });

        NSLog(@"[CommentService] 获取评论失败: %@", error.localizedDescription);
        if (completion) {
            completion(nil, error);
        }
    }];

    if (task) {
        dispatch_async(self.tasksQueue, ^{
            self.activeTasks[taskKey] = task;
        });
    }

    return task;
}

#pragma mark - 楼层评论

- (NSURLSessionDataTask *)fetchFloorComments:(NSString *)parentCommentId
                                        songId:(NSString *)songId
                                         limit:(NSInteger)limit
                                          time:(nullable NSString *)time
                                    completion:(void (^)(XCSongCommentFloorList *_Nullable, NSError *_Nullable))completion {
    
    if (!parentCommentId || parentCommentId.length == 0 || !songId || songId.length == 0) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:@"XCSongCommentService" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"参数不能为空"}];
            completion(nil, error);
        }
        return nil;
    }
    
    // 构建参数
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[@"parentCommentId"] = parentCommentId;
    params[@"id"] = songId;
    params[@"type"] = @0;  // 0: 歌曲
    params[@"limit"] = @(limit > 0 ? limit : 20);
    
    if (time && time.length > 0) {
        params[@"time"] = time;
    }
    
    NSString *taskKey = [NSString stringWithFormat:@"floor_%@_%@", songId, parentCommentId];

    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [self.sessionManager GET:@"/comment/floor"
                                               parameters:params
                                                  headers:nil
                                                 progress:nil
                                                  success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        dispatch_async(weakSelf.tasksQueue, ^{
            [weakSelf.activeTasks removeObjectForKey:taskKey];
        });

        if (![responseObject isKindOfClass:[NSDictionary class]]) {
            if (completion) {
                NSError *error = [NSError errorWithDomain:@"XCSongCommentService" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"返回数据格式错误"}];
                completion(nil, error);
            }
            return;
        }

        XCSongCommentFloorList *floorList = [[XCSongCommentFloorList alloc] initWithDictionary:responseObject];
        if (completion) {
            completion(floorList, nil);
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        dispatch_async(weakSelf.tasksQueue, ^{
            [weakSelf.activeTasks removeObjectForKey:taskKey];
        });

        NSLog(@"[CommentService] 获取楼层评论失败: %@", error.localizedDescription);
        if (completion) {
            completion(nil, error);
        }
    }];

    if (task) {
        dispatch_async(self.tasksQueue, ^{
            self.activeTasks[taskKey] = task;
        });
    }

    return task;
}

#pragma mark - 请求管理

- (void)cancelRequestForSongId:(NSString *)songId {
    NSString *taskKey = [NSString stringWithFormat:@"comments_%@", songId];
    dispatch_sync(self.tasksQueue, ^{
        NSURLSessionDataTask *task = self.activeTasks[taskKey];
        if (task) {
            [task cancel];
            [self.activeTasks removeObjectForKey:taskKey];
            NSLog(@"[CommentService] 取消歌曲 %@ 的评论请求", songId);
        }
    });
}

- (void)cancelAllRequests {
    dispatch_sync(self.tasksQueue, ^{
        for (NSURLSessionDataTask *task in self.activeTasks.allValues) {
            [task cancel];
        }
        [self.activeTasks removeAllObjects];
    });
    NSLog(@"[CommentService] 取消所有评论请求");
}

@end
