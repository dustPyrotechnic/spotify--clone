//
//  HomePageViewModel.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/11/22.
//

#import "HomePageViewModel.h"

#import "XCNetworkManager.h"


@implementation HomePageViewModel
- (instancetype) init {
  self.dataOfAllAlbums = [[NSMutableArray alloc] init];
  // 填充数组为空数组
  for (int i = 0; i < 5; i++) {
    NSMutableArray* albumArray = [[NSMutableArray alloc] init];
    for (int j = 0; j < 10; j++) {
      XCAlbumSimpleData* album = [[XCAlbumSimpleData alloc] init];
      album.imageURL = nil;
      album.nameAlbum = nil;
      album.idOfAlbum = nil;
      [albumArray addObject:album];
    }
    [self.dataOfAllAlbums addObject:albumArray];
  }
  return self;
}
// 共计50个
- (void) getDataOfAllAlbums {
  XCNetworkManager* networkManager = [XCNetworkManager sharedInstance];
  [networkManager getDataOfAllAlbums:self.dataOfAllAlbums];
}
@end
