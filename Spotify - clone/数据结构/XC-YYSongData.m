//
//  XC-YYSongData.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/1/18.
//

#import "XC-YYSongData.h"

@implementation XC_YYSongData
- (instancetype) init {
  self.name = [[NSString alloc] init];
  self.mainIma = [[UIImage alloc] init];
  self.songId = [[NSString alloc] init];
  self.songUrl = [[NSString alloc] init];
  return self;
}
@end
