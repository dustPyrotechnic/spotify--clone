//
//  XC-YYAlbumData.mm
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/1/12.
//

#import "XC-YYAlbumData.h"

@implementation XC_YYAlbumData

#pragma mark - WCDB

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
WCDB_PRIMARY(albumId)

#pragma mark - YYModel

+ (nullable NSDictionary<NSString *, id> *)modelCustomPropertyMapper {
  return @{
    @"name": @[@"name", @"albumName"],
    @"coverImgUrl" : @[@"coverImgUrl", @"coverUrl"],
    @"albumId":@[@"id",@"albumId"],
    @"artistName":@[@"creator.nickname", @"artistName"],
    @"authorId":@"creator.userId"
  };
}

- (BOOL)modelCustomTransformFromDictionary:(NSDictionary *)dic {
    if ([self.coverImgUrl hasPrefix:@"http://"]) {
        _coverImgUrl = [self.coverImgUrl stringByReplacingOccurrencesOfString:@"http://"
                                                         withString:@"https://"];
    }
    return YES;
}

@end
