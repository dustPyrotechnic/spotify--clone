//
//  XCLocalPlaylistInfo.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/20.
//

#import "XCLocalPlaylistInfo.h"

#pragma mark - 常量定义
static NSString* const kCodingKeyPlaylistId = @"playlistId";
static NSString* const kCodingKeyPlaylistName = @"playlistName";
static NSString* const kCodingKeySongCount = @"songCount";
static NSString* const kCodingKeyCreateDate = @"createDate";
static NSString* const kCodingKeyModifyDate = @"modifyDate";
static NSString* const kCodingKeyPlaylistType = @"playlistType";
static NSString* const kCodingKeyIsPinned = @"isPinned";
static NSString* const kCodingKeyLocalCoverPath = @"localCoverPath";

@implementation XCLocalPlaylistInfo

#pragma mark - 初始化方法
- (instancetype)init {
    self = [super init];
    if (self) {
        _playlistId = @"";
        _playlistName = @"";
        _songCount = 0;
        _createDate = [NSDate date];
        _modifyDate = [NSDate date];
        _playlistType = XCPlaylistTypeUserCreated;
        _isPinned = NO;
        _localCoverPath = nil;
    }
    return self;
}

+ (instancetype)infoWithPlaylistId:(NSString*)playlistId name:(NSString*)name {
    XCLocalPlaylistInfo* info = [[XCLocalPlaylistInfo alloc] init];
    info.playlistId = playlistId ?: @"";
    info.playlistName = name ?: @"";
    info.createDate = [NSDate date];
    info.modifyDate = [NSDate date];
    return info;
}

#pragma mark - NSSecureCoding
+ (BOOL)supportsSecureCoding {
    return YES;
}

- (void)encodeWithCoder:(NSCoder*)coder {
    [coder encodeObject:self.playlistId forKey:kCodingKeyPlaylistId];
    [coder encodeObject:self.playlistName forKey:kCodingKeyPlaylistName];
    [coder encodeInteger:self.songCount forKey:kCodingKeySongCount];
    [coder encodeObject:self.createDate forKey:kCodingKeyCreateDate];
    [coder encodeObject:self.modifyDate forKey:kCodingKeyModifyDate];
    [coder encodeInteger:self.playlistType forKey:kCodingKeyPlaylistType];
    [coder encodeBool:self.isPinned forKey:kCodingKeyIsPinned];
    [coder encodeObject:self.localCoverPath forKey:kCodingKeyLocalCoverPath];
}

- (instancetype)initWithCoder:(NSCoder*)coder {
    self = [super init];
    if (self) {
        _playlistId = [coder decodeObjectOfClass:[NSString class] forKey:kCodingKeyPlaylistId] ?: @"";
        _playlistName = [coder decodeObjectOfClass:[NSString class] forKey:kCodingKeyPlaylistName] ?: @"";
        _songCount = [coder decodeIntegerForKey:kCodingKeySongCount];
        _createDate = [coder decodeObjectOfClass:[NSDate class] forKey:kCodingKeyCreateDate];
        _modifyDate = [coder decodeObjectOfClass:[NSDate class] forKey:kCodingKeyModifyDate];
        _playlistType = [coder decodeIntegerForKey:kCodingKeyPlaylistType];
        _isPinned = [coder decodeBoolForKey:kCodingKeyIsPinned];
        _localCoverPath = [coder decodeObjectOfClass:[NSString class] forKey:kCodingKeyLocalCoverPath];
    }
    return self;
}

#pragma mark - 便捷属性
- (NSString*)timeDescription {
    if (!self.modifyDate) {
        return @"未知时间";
    }
    
    NSDate* now = [NSDate date];
    NSTimeInterval interval = [now timeIntervalSinceDate:self.modifyDate];
    
    // 小于1分钟
    if (interval < 60) {
        return @"刚刚";
    }
    
    // 小于1小时
    NSInteger minutes = (NSInteger)(interval / 60);
    if (minutes < 60) {
        return [NSString stringWithFormat:@"%ld分钟前", (long)minutes];
    }
    
    // 小于24小时
    NSInteger hours = minutes / 60;
    if (hours < 24) {
        return [NSString stringWithFormat:@"%ld小时前", (long)hours];
    }
    
    // 小于7天
    NSInteger days = hours / 24;
    if (days < 7) {
        return [NSString stringWithFormat:@"%ld天前", (long)days];
    }
    
    // 小于30天
    NSInteger weeks = days / 7;
    if (weeks < 4) {
        return [NSString stringWithFormat:@"%ld周前", (long)weeks];
    }
    
    // 小于365天
    NSInteger months = days / 30;
    if (months < 12) {
        return [NSString stringWithFormat:@"%ld个月前", (long)months];
    }
    
    // 大于等于365天
    NSInteger years = days / 365;
    return [NSString stringWithFormat:@"%ld年前", (long)years];
}

- (NSString*)songCountText {
    if (self.songCount <= 0) {
        return @"0首";
    }
    return [NSString stringWithFormat:@"%ld首", (long)self.songCount];
}

#pragma mark - 描述方法
- (NSString*)description {
    return [NSString stringWithFormat:@"<%@: %p> id=%@, name=%@, count=%ld, type=%@",
            NSStringFromClass([self class]),
            self,
            self.playlistId,
            self.playlistName,
            (long)self.songCount,
            self.playlistType == XCPlaylistTypeSystem ? @"System" : @"User"];
}

@end
