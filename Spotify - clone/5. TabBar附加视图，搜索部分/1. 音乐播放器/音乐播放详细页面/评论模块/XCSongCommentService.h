//
//  XCSongCommentService.h
//  Spotify - clone
//
//  Created by Kimi on 2026/03/03.
//  评论网络服务层 - 封装网易云评论API
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - 评论排序类型

typedef NS_ENUM(NSInteger, XCCommentSortType) {
    XCCommentSortTypeHot    = 0,  ///< 热门评论
    XCCommentSortTypeLatest = 1,  ///< 最新评论
};

#pragma mark - Forward Declaration

@class XCSongComment;
@class XCSongCommentList;
@class XCSongCommentFloorList;

#pragma mark - XCSongCommentService

/// 评论网络服务单例
/// 封装网易云音乐评论API，支持请求取消
@interface XCSongCommentService : NSObject

+ (instancetype)sharedInstance;

#pragma mark - 主评论列表

/// 获取歌曲评论列表
/// @param songId 歌曲ID
/// @param sortType 排序类型（热门/最新）
/// @param limit 每页数量（默认20）
/// @param beforeCursor 分页游标（超过5000条时使用上一页最后一条的time）
/// @param completion 回调：评论列表对象或错误
- (NSURLSessionDataTask *)fetchCommentsForSongId:(NSString *)songId
                                          sortType:(XCCommentSortType)sortType
                                             limit:(NSInteger)limit
                                            before:(nullable NSString *)beforeCursor
                                        completion:(void (^)(XCSongCommentList *_Nullable commentList, NSError *_Nullable error))completion;

#pragma mark - 楼层评论

/// 获取楼层评论（回复链）
/// @param parentCommentId 父评论ID（楼层ID）
/// @param songId 歌曲ID
/// @param limit 每页数量（默认20）
/// @param time 分页时间戳（取上一页最后一项的time）
/// @param completion 回调：楼层评论列表对象或错误
- (NSURLSessionDataTask *)fetchFloorComments:(NSString *)parentCommentId
                                        songId:(NSString *)songId
                                         limit:(NSInteger)limit
                                          time:(nullable NSString *)time
                                    completion:(void (^)(XCSongCommentFloorList *_Nullable floorList, NSError *_Nullable error))completion;

#pragma mark - 请求管理

/// 取消指定歌曲的评论请求
/// @param songId 歌曲ID
- (void)cancelRequestForSongId:(NSString *)songId;

/// 取消所有评论请求
- (void)cancelAllRequests;

@end

NS_ASSUME_NONNULL_END
