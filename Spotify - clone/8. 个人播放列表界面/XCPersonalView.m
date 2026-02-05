//
//  XCPersonalView.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/1.
//

#import "XCPersonalView.h"

#import <Masonry/Masonry.h>

@implementation XCPersonalView
- (instancetype) init {
  self = [super init];
  if (self) {
    self.backgroundColor = [UIColor systemBackgroundColor];
    self.tableView = [[UITableView alloc] init];

    [self addSubview:self.tableView];

    [self.tableView mas_makeConstraints:^(MASConstraintMaker *make) {
      make.size.mas_equalTo(self);
      make.center.mas_equalTo(self);
    }];
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
