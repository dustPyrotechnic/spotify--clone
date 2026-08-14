//
//  XCSongComment.m
//  Spotify - clone
//
//  Created by Kimi on 2026/03/03.
//

#import "XCSongComment.h"

const NSInteger kXCLongCommentThreshold = 120;
const NSInteger kXCMaxCollapsedLines = 3;

@implementation XCSongComment

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
    
    // 基础信息
    self.commentId = [self stringFromValue:dict[@"commentId"]];
    self.content = [self stringFromValue:dict[@"content"]];
    
    // 用户信息
    NSDictionary *userDict = dict[@"user"];
    if ([userDict isKindOfClass:[NSDictionary class]]) {
        self.userId = [self stringFromValue:userDict[@"userId"]];
        self.nickname = [self stringFromValue:userDict[@"nickname"]];
        self.avatarUrl = [self stringFromValue:userDict[@"avatarUrl"]];
    }
    
    // 互动数据
    self.likedCount = [self integerFromValue:dict[@"likedCount"]];
    self.isLiked = [self boolFromValue:dict[@"liked"]];
    self.replyCount = [self integerFromValue:dict[@"replyCount"]];
    
    // 时间
    self.timestamp = [self longLongFromValue:dict[@"time"]] / 1000.0; // 毫秒转秒
    
    // 回复关系
    NSArray *beRepliedArray = dict[@"beReplied"];
    if ([beRepliedArray isKindOfClass:[NSArray class]] && beRepliedArray.count > 0) {
        NSDictionary *repliedDict = beRepliedArray.firstObject;
        if ([repliedDict isKindOfClass:[NSDictionary class]]) {
            self.replyToComment = [[XCSongComment alloc] initWithDictionary:repliedDict];
        }
    }
    
    // 父评论ID
    self.parentCommentId = [self stringFromValue:dict[@"parentCommentId"]];
    
    // 默认折叠
    self.isExpanded = NO;
}

#pragma mark - 计算属性

- (NSInteger)contentLength {
    return self.content.length;
}

- (BOOL)isLongComment {
    return self.contentLength > kXCLongCommentThreshold;
}

#pragma mark - 辅助方法

- (NSString *)stringFromValue:(id)value {
    if ([value isKindOfClass:[NSString class]]) {
        return value;
    } else if ([value isKindOfClass:[NSNumber class]]) {
        return [(NSNumber *)value stringValue];
    }
    return nil;
}

- (NSInteger)integerFromValue:(id)value {
    if ([value isKindOfClass:[NSNumber class]]) {
        return [(NSNumber *)value integerValue];
    } else if ([value isKindOfClass:[NSString class]]) {
        return [(NSString *)value integerValue];
    }
    return 0;
}

- (long long)longLongFromValue:(id)value {
    if ([value isKindOfClass:[NSNumber class]]) {
        return [(NSNumber *)value longLongValue];
    } else if ([value isKindOfClass:[NSString class]]) {
        return [(NSString *)value longLongValue];
    }
    return 0;
}

- (BOOL)boolFromValue:(id)value {
    if ([value isKindOfClass:[NSNumber class]]) {
        return [(NSNumber *)value boolValue];
    } else if ([value isKindOfClass:[NSString class]]) {
        return [(NSString *)value boolValue];
    }
    return NO;
}

#pragma mark - 调试

- (NSString *)description {
    NSString *preview = self.content.length > 0
        ? [self.content substringToIndex:MIN(20, self.content.length)]
        : @"(nil)";
    return [NSString stringWithFormat:@"<%@: %p> id=%@, user=%@, content=%@, isLong=%@",
            NSStringFromClass([self class]),
            self,
            self.commentId,
            self.nickname,
            preview,
            self.isLongComment ? @"YES" : @"NO"];
}

@end
