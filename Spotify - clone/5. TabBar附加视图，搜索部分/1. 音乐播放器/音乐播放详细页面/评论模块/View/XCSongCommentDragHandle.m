//
//  XCSongCommentDragHandle.m
//  Spotify - clone
//
//  Created by Kimi on 2026/03/03.
//

#import "XCSongCommentDragHandle.h"
#import <Masonry/Masonry.h>

@interface XCSongCommentDragHandle ()

@property (nonatomic, strong) UIView *indicatorView;

@end

@implementation XCSongCommentDragHandle

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    self.backgroundColor = [UIColor clearColor];
    
    // 创建指示条
    self.indicatorView = [[UIView alloc] init];
    self.indicatorView.backgroundColor = [UIColor colorWithWhite:0.6 alpha:0.5];
    self.indicatorView.layer.cornerRadius = 2;
    self.indicatorView.clipsToBounds = YES;
    
    [self addSubview:self.indicatorView];
    
    // 布局
    [self.indicatorView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self);
        make.width.mas_equalTo(36);
        make.height.mas_equalTo(4);
    }];
}

- (void)setDragging:(BOOL)dragging {
    [UIView animateWithDuration:0.2 animations:^{
        if (dragging) {
            self.indicatorView.backgroundColor = [UIColor colorWithWhite:0.8 alpha:0.8];
            self.indicatorView.transform = CGAffineTransformMakeScale(1.2, 1.2);
        } else {
            self.indicatorView.backgroundColor = [UIColor colorWithWhite:0.6 alpha:0.5];
            self.indicatorView.transform = CGAffineTransformIdentity;
        }
    }];
}

#pragma mark - Setter

- (void)setIndicatorColor:(UIColor *)indicatorColor {
    _indicatorColor = indicatorColor;
    self.indicatorView.backgroundColor = indicatorColor;
}

@end
