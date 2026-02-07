//
//  XC-YYSongData.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/1/18.
//

#import "XC-YYSongData.h"
#import "WCDBObjc.h"

@interface XC_YYSongData () <WCTTableCoding>
@end

@implementation XC_YYSongData

#pragma mark - 初始化

- (instancetype)init {
    self = [super init];
    if (self) {
        // 基础字段初始化
        _name = @"";
        _songId = @"";
        _mainIma = @"";
        _songUrl = nil;
        
        // 新增字段初始化
        _artist = @"";
        _artistId = @"";
        _artists = nil;
        _albumName = @"";
        _albumId = @"";
        _duration = 0;
        _mvId = 0;
        _trackNumber = 0;
        _alias = nil;
        _popularity = 0;
        _fee = 0;
    }
    return self;
}

#pragma mark - YYModel 配置

+ (nullable NSDictionary<NSString *, id> *)modelCustomPropertyMapper {
    return @{
        // 基础字段映射（保持原有配置）
        @"songId": @[@"id", @"albumId"],
        @"mainIma": @[@"al.picUrl", @"coverUrl"],
        
        // 新增字段映射
        @"albumName": @"al.name",
        @"albumId": @"al.id",
        @"duration": @"dt",
        @"mvId": @"mv",
        @"trackNumber": @"no",
        @"popularity": @"pop",
        @"alias": @"alia",
        @"fee": @"fee"
        // 注意：artist 和 artistId 通过 modelCustomTransformFromDictionary 处理
    };
}

/// 自定义转换：处理 artists 数组，提取主艺术家
- (BOOL)modelCustomTransformFromDictionary:(NSDictionary *)dic {
    // 处理 artists 数组（ar 字段）
    NSArray *arArray = dic[@"ar"];
    if (arArray && [arArray isKindOfClass:[NSArray class]] && arArray.count > 0) {
        // 保存完整数组
        self.artists = arArray;
        
        // 提取第一个作为主艺术家
        NSDictionary *firstArtist = arArray[0];
        if ([firstArtist isKindOfClass:[NSDictionary class]]) {
            // 歌手名
            NSString *artistName = firstArtist[@"name"];
            if (artistName) {
                self.artist = artistName;
            }
            // 歌手ID
            id artistIdValue = firstArtist[@"id"];
            if (artistIdValue) {
                self.artistId = [NSString stringWithFormat:@"%@", artistIdValue];
            }
        }
    }
    
    // 如果没有歌手，使用默认值
    if (!self.artist || self.artist.length == 0) {
        self.artist = @"未知艺术家";
    }
    
    // 如果没有专辑名，使用默认值
    if (!self.albumName || self.albumName.length == 0) {
        self.albumName = @"未知专辑";
    }
    
    return YES;
}

#pragma mark - 计算属性

/// 格式化时长：毫秒 -> "03:46"
- (NSString *)durationText {
    // 小于等于0时返回 "00:00"
    if (self.duration <= 0) {
        return @"00:00";
    }
    
    // 转换为秒
    NSInteger totalSeconds = self.duration / 1000;
    NSInteger minutes = totalSeconds / 60;
    NSInteger seconds = totalSeconds % 60;
    
    // 格式化：分:秒，不足两位补零
    return [NSString stringWithFormat:@"%02ld:%02ld", (long)minutes, (long)seconds];
}

/// 是否有MV
- (BOOL)hasMV {
    return self.mvId > 0;
}

/// 付费类型描述
- (NSString *)feeDescription {
    switch (self.fee) {
        case 0:
            return @"免费";
        case 1:
            return @"VIP";
        case 4:
            return @"付费";
        case 8:
            return @"试听";
        default:
            return @"未知";
    }
}

#pragma mark - 调试

/// 打印对象信息
- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p> {name: %@, artist: %@, album: %@, duration: %@}", 
            NSStringFromClass([self class]), 
            self,
            self.name,
            self.artist,
            self.albumName,
            self.durationText];
}

@end
