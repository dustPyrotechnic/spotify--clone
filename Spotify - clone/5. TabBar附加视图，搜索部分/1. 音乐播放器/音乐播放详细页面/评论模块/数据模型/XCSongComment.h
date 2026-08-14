//
//  XCSongComment.h
//  Spotify - clone
//
//  Created by Kimi on 2026/03/03.
//  单条评论数据模型
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - 长评论常量

/// 长评论判定阈值（字符数）
extern const NSInteger kXCLongCommentThreshold;
/// 折叠状态显示的最大行数
extern const NSInteger kXCMaxCollapsedLines;

#pragma mark - XCSongComment

/// 单条评论数据模型
@interface XCSongComment : NSObject

#pragma mark - 基础信息

/// 评论ID
@property (nonatomic, copy) NSString *commentId;
/// 评论内容
@property (nonatomic, copy) NSString *content;
/// 内容长度（字符数）
@property (nonatomic, assign, readonly) NSInteger contentLength;

#pragma mark - 用户信息

/// 用户ID
@property (nonatomic, copy) NSString *userId;
/// 用户昵称
@property (nonatomic, copy) NSString *nickname;
/// 用户头像URL
@property (nonatomic, copy) NSString *avatarUrl;

#pragma mark - 互动数据

/// 点赞数量
@property (nonatomic, assign) NSInteger likedCount;
/// 是否已点赞
@property (nonatomic, assign) BOOL isLiked;
/// 回复数量（用于显示"查看xx条回复"）
@property (nonatomic, assign) NSInteger replyCount;

#pragma mark - 时间

/// 评论时间戳（毫秒）
@property (nonatomic, assign) NSTimeInterval timestamp;

#pragma mark - 回复关系

/// 被回复的评论（一层嵌套）
@property (nonatomic, strong, nullable) XCSongComment *replyToComment;
/// 父评论ID（楼层评论用）
@property (nonatomic, copy, nullable) NSString *parentCommentId;

#pragma mark - 长评论专用

/// 是否为长评论（>120字）
@property (nonatomic, assign, readonly) BOOL isLongComment;
/// 是否已展开（UI状态，默认NO）
@property (nonatomic, assign) BOOL isExpanded;

#pragma mark - 初始化

/// 使用字典初始化（YYModel风格）
- (instancetype)initWithDictionary:(NSDictionary *)dict;

@end

NS_ASSUME_NONNULL_END
