//
//  XCSongCommentFloorList.h
//  Spotify - clone
//
//  Created by Kimi on 2026/03/03.
//  楼层评论列表管理
//

#import <Foundation/Foundation.h>
#import "XCSongComment.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark - 楼层评论项

/// 楼层评论项（带层级信息）
@interface XCSongCommentFloorItem : NSObject

/// 评论数据
@property (nonatomic, strong) XCSongComment *comment;
/// 楼层层级（0=楼主，1=一级回复，2=二级回复...）
@property (nonatomic, assign) NSInteger floorLevel;
/// 是否显示左侧回复线
@property (nonatomic, assign) BOOL showReplyLine;

@end

#pragma mark - XCSongCommentFloorList

/// 楼层评论列表管理器
@interface XCSongCommentFloorList : NSObject

/// 楼主原评论
@property (nonatomic, strong, nullable) XCSongComment *ownerComment;
/// 楼层评论项数组（已按层级排序）
@property (nonatomic, strong, readonly) NSArray<XCSongCommentFloorItem *> *floorItems;
/// 是否还有更多
@property (nonatomic, assign, readonly) BOOL hasMore;
/// 下一页时间戳
@property (nonatomic, copy, readonly, nullable) NSString *nextTime;

/// 使用API返回的字典初始化
- (instancetype)initWithDictionary:(NSDictionary *)dict;

/// 获取指定索引的楼层项
- (XCSongCommentFloorItem *)itemAtIndex:(NSInteger)index;

/// 总楼层数
- (NSInteger)totalCount;

/// 追加下一页数据（分页加载更多时调用）
/// @param nextPage 下一页返回的 XCSongCommentFloorList
- (void)appendItemsFromFloorList:(XCSongCommentFloorList *)nextPage;

@end

NS_ASSUME_NONNULL_END
