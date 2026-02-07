//
//  XC-YYAlbumData.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/1/12.
//

#import "XC-YYAlbumData.h"

@implementation XC_YYAlbumData
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
