//
//  XCSearchView.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/12/5.
//

#import "XCSearchView.h"

@implementation XCSearchView
- (instancetype) init {
  self = [super init];
  if (self) {
    self.searchController = [[UISearchController alloc] init];
    
  }
  return self;
}
/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end
