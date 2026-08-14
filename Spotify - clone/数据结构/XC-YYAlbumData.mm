//
//  XC-YYAlbumData.mm
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/1/12.
//

#import "XC-YYAlbumData.h"

@implementation XC_YYAlbumData

#pragma mark - WCDB

/// WCDB 宏，生成表字段的 ORM 绑定代码
WCDB_IMPLEMENTATION(XC_YYAlbumData)
WCDB_SYNTHESIZE(albumId)
WCDB_SYNTHESIZE(name)
WCDB_SYNTHESIZE(coverImgUrl)
WCDB_SYNTHESIZE(artistName)
WCDB_SYNTHESIZE(authorId)
WCDB_SYNTHESIZE(createTime)
WCDB_SYNTHESIZE(updateTime)
WCDB_SYNTHESIZE(songCount)
WCDB_SYNTHESIZE(isFavorites)
WCDB_SYNTHESIZE(sortIndex)
/// albumId 作为主键
WCDB_PRIMARY(albumId)

#pragma mark - YYModel

/**
 * 字段映射表
 *
 * 网络接口和本地属性名有差异，比如创建者信息在 creator 嵌套对象里。
 * name / coverImgUrl / albumId 都支持多个备选 key，兼容不同接口格式。
 */
+ (nullable NSDictionary<NSString *, id> *)modelCustomPropertyMapper {
  return @{
    @"name": @[@"name", @"albumName"],
    @"coverImgUrl" : @[@"coverImgUrl", @"coverUrl"],
    @"albumId":@[@"id",@"albumId"],
    @"artistName":@[@"creator.nickname", @"artistName"],
    @"authorId":@"creator.userId"
  };
}

/// 修正 http 封面链接为 https，不然 ATS 会拦截请求
- (BOOL)modelCustomTransformFromDictionary:(NSDictionary *)dic {
  if ([self.coverImgUrl isKindOfClass:[NSString class]] &&
      [self.coverImgUrl hasPrefix:@"http://"]) {
    _coverImgUrl = [self.coverImgUrl stringByReplacingOccurrencesOfString:@"http://"
                                                       withString:@"https://"];
  }
  return YES;
}

@end
