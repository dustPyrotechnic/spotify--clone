//
//  XCSongCommentFloorList.m
//  Spotify - clone
//
//  Created by Kimi on 2026/03/03.
//

#import "XCSongCommentFloorList.h"

#pragma mark - 楼层评论项实现

@implementation XCSongCommentFloorItem

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p> level=%ld, user=%@",
            NSStringFromClass([self class]),
            self,
            (long)self.floorLevel,
            self.comment.nickname];
}

@end

#pragma mark - XCSongCommentFloorList 实现

@interface XCSongCommentFloorList ()

@property (nonatomic, strong, readwrite) NSArray<XCSongCommentFloorItem *> *floorItems;
@property (nonatomic, assign, readwrite) BOOL hasMore;
@property (nonatomic, copy, readwrite, nullable) NSString *nextTime;

@end

@implementation XCSongCommentFloorList

#pragma mark - 初始化

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    self = [super init];
    if (self) {
        [self parseFromDictionary:dict];
    }
    return self;
}

- (void)parseFromDictionary:(NSDictionary *)dict {
    if (![dict isKindOfClass:[NSDictionary class]]) return;

    // 解析楼主评论
    NSDictionary *ownerDict = dict[@"ownerComment"];
    if ([ownerDict isKindOfClass:[NSDictionary class]]) {
        self.ownerComment = [[XCSongComment alloc] initWithDictionary:ownerDict];
    }

    // 解析楼层评论数组
    NSArray *commentsArray = dict[@"comments"];
    NSMutableArray *tempItems = [NSMutableArray array];

    if ([commentsArray isKindOfClass:[NSArray class]]) {
        // 第一遍：解析所有评论，同时构建 commentId → XCSongComment 索引（O(n)）
        NSMutableDictionary<NSString *, XCSongComment *> *idIndex = [NSMutableDictionary dictionaryWithCapacity:commentsArray.count];
        NSMutableArray<XCSongComment *> *allComments = [NSMutableArray arrayWithCapacity:commentsArray.count];

        for (NSDictionary *itemDict in commentsArray) {
            if (![itemDict isKindOfClass:[NSDictionary class]]) continue;
            XCSongComment *comment = [[XCSongComment alloc] initWithDictionary:itemDict];
            if (!comment || !comment.commentId) continue;
            idIndex[comment.commentId] = comment;
            [allComments addObject:comment];
        }

        // 第二遍：O(n) 计算层级，使用索引查父评论，不再重复 alloc
        for (XCSongComment *comment in allComments) {
            XCSongCommentFloorItem *item = [[XCSongCommentFloorItem alloc] init];
            item.comment = comment;
            item.floorLevel = [self calculateFloorLevelForComment:comment withIndex:idIndex];
            item.showReplyLine = item.floorLevel > 0;
            [tempItems addObject:item];
        }
    }

    self.floorItems = [tempItems copy];

    // 是否还有更多
    self.hasMore = [dict[@"hasMore"] boolValue] || [dict[@"more"] boolValue];

    // 下一页时间戳
    if (tempItems.count > 0) {
        XCSongCommentFloorItem *lastItem = [tempItems lastObject];
        self.nextTime = [NSString stringWithFormat:@"%.0f", lastItem.comment.timestamp * 1000];
    }
}

#pragma mark - 层级计算

/// 使用 commentId 索引计算层级，O(depth) 无重复对象创建
- (NSInteger)calculateFloorLevelForComment:(XCSongComment *)comment
                                 withIndex:(NSDictionary<NSString *, XCSongComment *> *)idIndex {
    // 没有 parentCommentId，说明是直接回复楼主，层级为1
    if (!comment.parentCommentId || comment.parentCommentId.length == 0) {
        return 1;
    }

    // 通过索引 O(1) 找父评论
    XCSongComment *parent = idIndex[comment.parentCommentId];
    if (!parent) {
        return 1;
    }

    return [self calculateFloorLevelForComment:parent withIndex:idIndex] + 1;
}

#pragma mark - 公共方法

- (XCSongCommentFloorItem *)itemAtIndex:(NSInteger)index {
    if (index >= 0 && index < self.floorItems.count) {
        return self.floorItems[index];
    }
    return nil;
}

- (NSInteger)totalCount {
    return self.floorItems.count;
}

- (void)appendItemsFromFloorList:(XCSongCommentFloorList *)nextPage {
    if (!nextPage || nextPage.floorItems.count == 0) return;
    NSMutableArray *merged = [NSMutableArray arrayWithArray:self.floorItems];
    [merged addObjectsFromArray:nextPage.floorItems];
    self.floorItems = [merged copy];
    self.hasMore    = nextPage.hasMore;
    self.nextTime   = nextPage.nextTime;
}

@end
