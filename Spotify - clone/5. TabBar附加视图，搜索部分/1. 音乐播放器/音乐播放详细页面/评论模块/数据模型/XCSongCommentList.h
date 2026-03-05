//
//  XCSongCommentList.h
//  Spotify - clone
//
//  Created by Kimi on 2026/03/03.
//  主评论列表管理 - 包含高度缓存
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "XCSongComment.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark - 高度缓存条目

/// Cell 高度缓存条目
@interface XCSongCommentCellHeightCache : NSObject

@property (nonatomic, assign) CGFloat height;           ///< 总高度
@property (nonatomic, assign) CGFloat contentHeight;    ///< 内容区域高度
@property (nonatomic, assign) BOOL needsExpandButton;   ///< 是否需要展开按钮

@end

#pragma mark - XCSongCommentList

/// 主评论列表管理器
/// 负责数据解析、高度预计算和缓存
@interface XCSongCommentList : NSObject

#pragma mark - 数据属性

/// 热门评论数组
@property (nonatomic, strong, readonly) NSArray<XCSongComment *> *hotComments;
/// 普通评论数组
@property (nonatomic, strong, readonly) NSArray<XCSongComment *> *comments;
/// 是否还有更多数据
@property (nonatomic, assign, readonly) BOOL hasMore;
/// 分页游标（超过5000条时使用）
@property (nonatomic, copy, readonly, nullable) NSString *cursor;

#pragma mark - 初始化

/// 使用API返回的字典初始化
- (instancetype)initWithDictionary:(NSDictionary *)dict;

#pragma mark - 高度管理

/// 获取指定索引评论的Cell高度
/// @param index 索引
/// @param isHot 是否是热门评论
- (CGFloat)heightForCommentAtIndex:(NSInteger)index isHot:(BOOL)isHot;

/// 更新指定评论的展开状态并重新计算高度
/// @param isExpanded 是否展开
/// @param index 索引
/// @param isHot 是否是热门评论
- (void)updateExpandState:(BOOL)isExpanded forCommentAtIndex:(NSInteger)index isHot:(BOOL)isHot;

/// 获取评论对象
/// @param index 索引
/// @param isHot 是否是热门评论
- (XCSongComment *)commentAtIndex:(NSInteger)index isHot:(BOOL)isHot;

/// 总评论数（热门+普通）
- (NSInteger)totalCount;

@end

NS_ASSUME_NONNULL_END
