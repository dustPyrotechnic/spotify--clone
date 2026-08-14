//
//  XCSongCommentList.m
//  Spotify - clone
//
//  Created by Kimi on 2026/03/03.
//

#import "XCSongCommentList.h"

#pragma mark - 高度缓存条目实现

@implementation XCSongCommentCellHeightCache
@end

#pragma mark - XCSongCommentList 实现

@interface XCSongCommentList ()

@property (nonatomic, strong, readwrite) NSArray<XCSongComment *> *hotComments;
@property (nonatomic, strong, readwrite) NSArray<XCSongComment *> *comments;
@property (nonatomic, assign, readwrite) BOOL hasMore;
@property (nonatomic, copy, readwrite, nullable) NSString *cursor;

/// 高度缓存：key = "hot_索引" 或 "normal_索引"
@property (nonatomic, strong) NSMutableDictionary<NSString *, XCSongCommentCellHeightCache *> *heightCache;

@end

@implementation XCSongCommentList

#pragma mark - 常量

/// 内容区域最大宽度（屏幕宽度减去边距）
static const CGFloat kContentMaxWidth = 280.0;
/// 头像区域高度
static const CGFloat kAvatarAreaHeight = 50.0;
/// 昵称区域高度
static const CGFloat kNicknameHeight = 20.0;
/// 底部栏高度（点赞+时间）
static const CGFloat kBottomBarHeight = 30.0;
/// 展开按钮高度
static const CGFloat kExpandButtonHeight = 24.0;
/// 回复引用框高度（如果有）
static const CGFloat kReplyBoxHeight = 50.0;
/// 垂直间距总和
static const CGFloat kTotalVerticalSpacing = 36.0;

#pragma mark - 初始化

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    self = [super init];
    if (self) {
        _heightCache = [NSMutableDictionary dictionary];
        [self parseFromDictionary:dict];
    }
    return self;
}

- (void)parseFromDictionary:(NSDictionary *)dict {
    if (![dict isKindOfClass:[NSDictionary class]]) return;
    
    // 解析热门评论
    NSArray *hotCommentsArray = dict[@"hotComments"];
    if ([hotCommentsArray isKindOfClass:[NSArray class]]) {
        NSMutableArray *tempHot = [NSMutableArray array];
        for (NSDictionary *item in hotCommentsArray) {
            XCSongComment *comment = [[XCSongComment alloc] initWithDictionary:item];
            if (comment) [tempHot addObject:comment];
        }
        self.hotComments = [tempHot copy];
    } else {
        self.hotComments = @[];
    }
    
    // 解析普通评论
    NSArray *commentsArray = dict[@"comments"];
    if ([commentsArray isKindOfClass:[NSArray class]]) {
        NSMutableArray *tempNormal = [NSMutableArray array];
        for (NSDictionary *item in commentsArray) {
            XCSongComment *comment = [[XCSongComment alloc] initWithDictionary:item];
            if (comment) [tempNormal addObject:comment];
        }
        self.comments = [tempNormal copy];
    } else {
        self.comments = @[];
    }
    
    // 是否还有更多
    self.hasMore = [dict[@"more"] boolValue] || [dict[@"hasMore"] boolValue];
    
    // 分页游标：lastComment 是 XCSongComment 对象，取 timestamp * 1000 转毫秒字符串
    XCSongComment *lastComment = [self.comments lastObject];
    if (lastComment && lastComment.timestamp > 0) {
        self.cursor = [NSString stringWithFormat:@"%.0f", lastComment.timestamp * 1000];
    }
    
    // 预计算所有高度
    [self preCalculateAllHeights];
}

#pragma mark - 高度预计算

- (void)preCalculateAllHeights {
    // 计算热门评论高度
    for (NSInteger i = 0; i < self.hotComments.count; i++) {
        XCSongComment *comment = self.hotComments[i];
        [self calculateHeightForComment:comment key:[NSString stringWithFormat:@"hot_%ld", (long)i]];
    }
    
    // 计算普通评论高度
    for (NSInteger i = 0; i < self.comments.count; i++) {
        XCSongComment *comment = self.comments[i];
        [self calculateHeightForComment:comment key:[NSString stringWithFormat:@"normal_%ld", (long)i]];
    }
}

- (void)calculateHeightForComment:(XCSongComment *)comment key:(NSString *)key {
    XCSongCommentCellHeightCache *cache = [[XCSongCommentCellHeightCache alloc] init];
    cache.needsExpandButton = comment.isLongComment;
    
    // 计算内容高度
    CGFloat contentHeight = 0;
    
    if (comment.isLongComment && !comment.isExpanded) {
        // 折叠状态：计算3行高度 + 展开按钮
        contentHeight = [self heightForText:comment.content maxLines:kXCMaxCollapsedLines];
        contentHeight += kExpandButtonHeight;
    } else {
        // 展开状态或短评论：计算完整高度
        contentHeight = [self heightForText:comment.content maxLines:0];
    }
    
    cache.contentHeight = contentHeight;
    
    // 计算总高度
    CGFloat totalHeight = kAvatarAreaHeight + kNicknameHeight + contentHeight + kBottomBarHeight + kTotalVerticalSpacing;
    
    // 有回复引用时增加高度
    if (comment.replyToComment || comment.replyCount > 0) {
        totalHeight += kReplyBoxHeight;
    }
    
    cache.height = totalHeight;
    self.heightCache[key] = cache;
}

- (CGFloat)heightForText:(NSString *)text maxLines:(NSInteger)maxLines {
    if (!text || text.length == 0) return 0;
    
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
    
    NSDictionary *attributes = @{
        NSFontAttributeName: [UIFont systemFontOfSize:14],
        NSParagraphStyleAttributeName: paragraphStyle
    };
    
    if (maxLines > 0) {
        // 计算指定行数的高度
        NSString *oneLine = @"中";
        CGFloat oneLineHeight = [oneLine boundingRectWithSize:CGSizeMake(kContentMaxWidth, CGFLOAT_MAX)
                                                      options:NSStringDrawingUsesLineFragmentOrigin
                                                   attributes:attributes
                                                      context:nil].size.height;
        return oneLineHeight * maxLines + 4; // 4pt 行间距
    } else {
        // 计算完整高度
        CGSize size = [text boundingRectWithSize:CGSizeMake(kContentMaxWidth, CGFLOAT_MAX)
                                         options:NSStringDrawingUsesLineFragmentOrigin
                                      attributes:attributes
                                         context:nil].size;
        return ceil(size.height);
    }
}

#pragma mark - 公共方法

- (CGFloat)heightForCommentAtIndex:(NSInteger)index isHot:(BOOL)isHot {
    NSString *key = isHot ? [NSString stringWithFormat:@"hot_%ld", (long)index] 
                          : [NSString stringWithFormat:@"normal_%ld", (long)index];
    XCSongCommentCellHeightCache *cache = self.heightCache[key];
    return cache ? cache.height : 100.0; // 默认高度
}

- (void)updateExpandState:(BOOL)isExpanded forCommentAtIndex:(NSInteger)index isHot:(BOOL)isHot {
    XCSongComment *comment = [self commentAtIndex:index isHot:isHot];
    if (!comment) return;
    
    comment.isExpanded = isExpanded;
    
    // 重新计算高度
    NSString *key = isHot ? [NSString stringWithFormat:@"hot_%ld", (long)index] 
                          : [NSString stringWithFormat:@"normal_%ld", (long)index];
    [self calculateHeightForComment:comment key:key];
}

- (XCSongComment *)commentAtIndex:(NSInteger)index isHot:(BOOL)isHot {
    if (isHot) {
        if (index >= 0 && index < self.hotComments.count) {
            return self.hotComments[index];
        }
    } else {
        if (index >= 0 && index < self.comments.count) {
            return self.comments[index];
        }
    }
    return nil;
}

- (NSInteger)totalCount {
    return self.hotComments.count + self.comments.count;
}

@end
