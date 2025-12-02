//
//  HomePageView.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/11/22.
//

#import "HomePageView.h"

@implementation HomePageView
- (instancetype) initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];

  // 完成自定义操作
  self.mainTableView = [[UITableView alloc] init];
  self.mainTableView.frame = frame;

  [self addSubview:self.mainTableView];

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
