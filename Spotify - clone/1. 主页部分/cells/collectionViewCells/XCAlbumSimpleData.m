//
//  XCAlbumSimpleData.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/11/28.
//

#import "XCAlbumSimpleData.h"

@implementation XCAlbumSimpleData
- (instancetype) init {
  self = [super init];
  if (self) {
    self.nameAlbum = [[NSString alloc] init];
    self.idOfAlbum = [[NSString alloc] init];
    self.imageURL = [[NSString alloc] init];
  }
  return self;
}
@end
