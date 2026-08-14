//
//  XC-YYSongData.mm
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/1/18.
//

#import "XC-YYSongData.h"

@interface XC_YYSongData ()
@end

@implementation XC_YYSongData

#pragma mark - WCDB

// WCDB 宏展开，生成 ORM 所需的字段元数据
WCDB_IMPLEMENTATION(XC_YYSongData)
WCDB_SYNTHESIZE(songId)
WCDB_SYNTHESIZE(name)
WCDB_SYNTHESIZE(mainIma)
WCDB_SYNTHESIZE(songUrl)
WCDB_SYNTHESIZE(artist)
WCDB_SYNTHESIZE(artistId)
WCDB_SYNTHESIZE(albumName)
WCDB_SYNTHESIZE(albumId)
WCDB_SYNTHESIZE(duration)
WCDB_SYNTHESIZE(mvId)
WCDB_SYNTHESIZE(trackNumber)
WCDB_SYNTHESIZE(popularity)
WCDB_SYNTHESIZE(fee)
/// songId 声明为 WCDB 主键，唯一性辨别
WCDB_PRIMARY(songId)

#pragma mark - 初始化

/// 各字段置为安全的空初值，避免后续用到时崩溃
- (instancetype)init {
  self = [super init];
  if (self) {
    _name = @"";
    _songId = @"";
    _mainIma = @"";
    _songUrl = nil;
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

/**
 * 属性名 → JSON key 的映射表
 *
 * 网易云接口字段命名比较随意：时长叫 "dt"、mv 字段叫 "mv"、
 * 专辑信息藏在嵌套的 "al" 对象里。为了不污染属性名，统一在这里做映射。
 *
 * songId 支持两个备选 key，兼容歌曲列表和专辑详情两种接口结构。
 */
+ (nullable NSDictionary<NSString *, id> *)modelCustomPropertyMapper {
  return @{
    @"songId": @[@"id", @"albumId"],
    @"mainIma": @[@"al.picUrl", @"coverUrl"],
    @"albumName": @"al.name",
    @"albumId": @"al.id",
    @"duration": @"dt",
    @"mvId": @"mv",
    @"trackNumber": @"no",
    @"popularity": @"pop",
    @"alias": @"alia",
    @"fee": @"fee"
  };
}

/// 自定义转换：处理 artists 数组，提取主艺术家
- (BOOL)modelCustomTransformFromDictionary:(NSDictionary *)dic {
  NSArray *arArray = dic[@"ar"];
  if (arArray && [arArray isKindOfClass:[NSArray class]] && arArray.count > 0) {
    self.artists = arArray;

    NSDictionary *firstArtist = arArray[0];
    if ([firstArtist isKindOfClass:[NSDictionary class]]) {
      NSString *artistName = firstArtist[@"name"];
      if (artistName) {
        self.artist = artistName;
      }
      id artistIdValue = firstArtist[@"id"];
      if (artistIdValue) {
        self.artistId = [NSString stringWithFormat:@"%@", artistIdValue];
      }
    }
  }

  if (!self.artist || self.artist.length == 0) {
    self.artist = @"未知艺术家";
  }

  if (!self.albumName || self.albumName.length == 0) {
    self.albumName = @"未知专辑";
  }

  return YES;
}

#pragma mark - 计算属性

/// 把毫秒转成 mm:ss 格式字符串，duration <= 0 时返回 "00:00"
- (NSString *)durationText {
  if (self.duration <= 0) {
    return @"00:00";
  }
  NSInteger totalSeconds = self.duration / 1000;
  NSInteger minutes = totalSeconds / 60;
  NSInteger seconds = totalSeconds % 60;
  return [NSString stringWithFormat:@"%02ld:%02ld", (long)minutes, (long)seconds];
}

/// mvId 大于 0 就认为有 MV
- (BOOL)hasMV {
  return self.mvId > 0;
}

/**
 * 付费类型的可读描述
 *
 * - 0: 免费
 * - 1: VIP 专享
 * - 4: 付费专辑
 * - 8: 试听
 */
- (NSString *)feeDescription {
  switch (self.fee) {
    case 0:  return @"免费";
    case 1:  return @"VIP";
    case 4:  return @"付费";
    case 8:  return @"试听";
    default: return @"未知";
  }
}

#pragma mark - 调试

/// po 时输出有意义的信息，调 bug 方便
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
