//
//  XC-YYAlbumData.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/1/12.
//

#import "XC-YYAlbumData.h"

#pragma mark - NSCoding Keys
static NSString* const kCodingKeyCoverImgUrl = @"coverImgUrl";
static NSString* const kCodingKeyName = @"name";
static NSString* const kCodingKeyAlbumId = @"albumId";
static NSString* const kCodingKeyArtistName = @"artistName";
static NSString* const kCodingKeyAuthorId = @"authorId";

@implementation XC_YYAlbumData

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

#pragma mark - NSSecureCoding
+ (BOOL)supportsSecureCoding {
    return YES;
}

- (void)encodeWithCoder:(NSCoder*)coder {
    [coder encodeObject:self.coverImgUrl forKey:kCodingKeyCoverImgUrl];
    [coder encodeObject:self.name forKey:kCodingKeyName];
    [coder encodeObject:self.albumId forKey:kCodingKeyAlbumId];
    [coder encodeObject:self.artistName forKey:kCodingKeyArtistName];
    [coder encodeObject:self.authorId forKey:kCodingKeyAuthorId];
}

- (instancetype)initWithCoder:(NSCoder*)coder {
    self = [super init];
    if (self) {
        _coverImgUrl = [coder decodeObjectOfClass:[NSString class] forKey:kCodingKeyCoverImgUrl];
        _name = [coder decodeObjectOfClass:[NSString class] forKey:kCodingKeyName];
        _albumId = [coder decodeObjectOfClass:[NSString class] forKey:kCodingKeyAlbumId];
        _artistName = [coder decodeObjectOfClass:[NSString class] forKey:kCodingKeyArtistName];
        _authorId = [coder decodeObjectOfClass:[NSString class] forKey:kCodingKeyAuthorId];
    }
    return self;
}

#pragma mark - Description
- (NSString*)description {
    return [NSString stringWithFormat:@"<%@: %p> id=%@, name=%@, artist=%@",
            NSStringFromClass([self class]),
            self,
            self.albumId,
            self.name,
            self.artistName];
}

@end
