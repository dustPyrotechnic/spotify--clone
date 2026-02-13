//
//  XCAudioSegmentInfo.m
//  Spotify - clone
//

#import "XCAudioSegmentInfo.h"

@implementation XCAudioSegmentInfo

- (instancetype)initWithIndex:(NSInteger)index offset:(int64_t)offset size:(NSInteger)size {
  self = [super init];
  if (self) {
      _index = index;
      _offset = offset;
      _size = size;
      _isDownloaded = NO;
  }
  return self;
}

@end
