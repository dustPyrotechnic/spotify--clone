//
//  HomePageViewModel.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/11/22.
//

#import "HomePageViewModel.h"

#import "XCNetworkManager.h"
#import "XC-YYAlbumData.h"

@implementation HomePageViewModel
- (instancetype) init {
  self.dataOfAllAlbums = [[NSMutableArray alloc] init];
  // 填充空白数据
  for (int i = 0; i < 50; i++) {
    XC_YYAlbumData* whiteData = [[XC_YYAlbumData alloc] init];
    whiteData.name = @"";
    whiteData.coverImgUrl = @"";
    [self.dataOfAllAlbums addObject:whiteData];
  }

  self.offset = 0;
  return self;
}

- (void)getDataOfAllAlbumsWithCompletion:(void (^)(BOOL))completion {
  [[XCNetworkManager sharedInstance] getDataOfAllAlbumsFromWY:self.dataOfAllAlbums offset:self.offset limit:50 withCompletion:completion];
  self.offset += 50;
}
@end
