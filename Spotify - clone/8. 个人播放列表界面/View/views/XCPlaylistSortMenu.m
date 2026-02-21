//
//  XCPlaylistSortMenu.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/20.
//

#import "XCPlaylistSortMenu.h"
#import <Masonry/Masonry.h>

#pragma mark - 常量
static const CGFloat kMenuHeight = 380.0;
static const CGFloat kRowHeight = 56.0;
static const CGFloat kCornerRadius = 20.0;

@interface XCPlaylistSortMenu () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UIView* backdropView;
@property (nonatomic, strong) UIView* containerView;
@property (nonatomic, strong) UILabel* titleLabel;
@property (nonatomic, strong) UITableView* tableView;
@property (nonatomic, strong) UIButton* closeButton;
@property (nonatomic, copy) XCPlaylistSortMenuHandler handler;
@property (nonatomic, assign) XCPlaylistSortType selectedSortType;
@end

@implementation XCPlaylistSortMenu

#pragma mark - 显示方法
+ (void)showInView:(UIView*)view
   currentSortType:(XCPlaylistSortType)currentSortType
           handler:(XCPlaylistSortMenuHandler)handler {
    
    XCPlaylistSortMenu* menu = [[XCPlaylistSortMenu alloc] initWithFrame:view.bounds];
    menu.currentSortType = currentSortType;
    menu.selectedSortType = currentSortType;
    menu.handler = handler;
    [view addSubview:menu];
    
    [menu showAnimation];
}

#pragma mark - 初始化
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupView];
    }
    return self;
}

#pragma mark - 视图设置
- (void)setupView {
    self.backgroundColor = [UIColor clearColor];
    
    // 背景遮罩
    self.backdropView = [[UIView alloc] init];
    self.backdropView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
    self.backdropView.alpha = 0;
    [self addSubview:self.backdropView];
    
    UITapGestureRecognizer* tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(backdropTapped:)];
    [self.backdropView addGestureRecognizer:tapGesture];
    
    // 内容容器
    self.containerView = [[UIView alloc] init];
    self.containerView.backgroundColor = [UIColor systemBackgroundColor];
    self.containerView.layer.cornerRadius = kCornerRadius;
    self.containerView.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    self.containerView.clipsToBounds = YES;
    [self addSubview:self.containerView];
    
    // 标题
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = @"排序方式";
    self.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    self.titleLabel.textColor = [UIColor labelColor];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.containerView addSubview:self.titleLabel];
    
    // 关闭按钮
    self.closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.closeButton setImage:[UIImage systemImageNamed:@"xmark"] forState:UIControlStateNormal];
    self.closeButton.tintColor = [UIColor secondaryLabelColor];
    [self.closeButton addTarget:self action:@selector(closeButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.containerView addSubview:self.closeButton];
    
    // 表格视图
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.scrollEnabled = NO;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = kRowHeight;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"SortCell"];
    [self.containerView addSubview:self.tableView];
    
    // 设置约束
    [self.backdropView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self);
    }];
    
    [self.containerView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.bottom.equalTo(self);
        make.height.mas_equalTo(kMenuHeight);
    }];
    
    [self.titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.containerView).offset(20);
        make.centerX.equalTo(self.containerView);
    }];
    
    [self.closeButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.containerView).offset(-16);
        make.centerY.equalTo(self.titleLabel);
        make.width.height.mas_equalTo(32);
    }];
    
    [self.tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.titleLabel.mas_bottom).offset(10);
        make.left.right.bottom.equalTo(self.containerView);
    }];
}

#pragma mark - 动画
- (void)showAnimation {
    // 初始位置在屏幕下方
    [self.containerView mas_updateConstraints:^(MASConstraintMaker *make) {
        make.bottom.equalTo(self).offset(kMenuHeight);
    }];
    [self layoutIfNeeded];
    
    // 动画进入
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.backdropView.alpha = 1.0;
        [self.containerView mas_updateConstraints:^(MASConstraintMaker *make) {
            make.bottom.equalTo(self);
        }];
        [self layoutIfNeeded];
    } completion:nil];
}

- (void)dismiss {
    [UIView animateWithDuration:0.25 animations:^{
        self.backdropView.alpha = 0;
        [self.containerView mas_updateConstraints:^(MASConstraintMaker *make) {
            make.bottom.equalTo(self).offset(kMenuHeight);
        }];
        [self layoutIfNeeded];
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

#pragma mark - 事件处理
- (void)backdropTapped:(UITapGestureRecognizer*)gesture {
    [self dismiss];
}

- (void)closeButtonTapped:(id)sender {
    [self dismiss];
}

#pragma mark - UITableViewDataSource
- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section {
    return 5; // 5 种排序方式
}

- (UITableViewCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath {
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"SortCell" forIndexPath:indexPath];
    cell.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    
    XCPlaylistSortType sortType = indexPath.row;
    NSString* title = [self titleForSortType:sortType];
    NSString* iconName = [self iconForSortType:sortType];
    
    // 配置 Cell
    cell.textLabel.text = title;
    cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightRegular];
    cell.textLabel.textColor = [UIColor labelColor];
    cell.imageView.image = [UIImage systemImageNamed:iconName];
    cell.imageView.tintColor = [UIColor secondaryLabelColor];
    
    // 选中标记
    if (sortType == self.selectedSortType) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
        cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
        cell.textLabel.textColor = [UIColor systemGreenColor];
        cell.imageView.tintColor = [UIColor systemGreenColor];
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate
- (void)tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    XCPlaylistSortType sortType = indexPath.row;
    self.selectedSortType = sortType;
    
    // 回调
    if (self.handler) {
        self.handler(sortType);
    }
    
    [self dismiss];
}

#pragma mark - 辅助方法
- (NSString*)titleForSortType:(XCPlaylistSortType)sortType {
    switch (sortType) {
        case XCPlaylistSortTypeCreateDateDesc:
            return @"最近创建";
        case XCPlaylistSortTypeModifyDateDesc:
            return @"最近修改";
        case XCPlaylistSortTypeNameAsc:
            return @"名称 A-Z";
        case XCPlaylistSortTypeNameDesc:
            return @"名称 Z-A";
        case XCPlaylistSortTypeSongCountDesc:
            return @"最多歌曲";
        default:
            return @"未知";
    }
}

- (NSString*)iconForSortType:(XCPlaylistSortType)sortType {
    switch (sortType) {
        case XCPlaylistSortTypeCreateDateDesc:
            return @"calendar.badge.plus";
        case XCPlaylistSortTypeModifyDateDesc:
            return @"calendar.badge.clock";
        case XCPlaylistSortTypeNameAsc:
            return @"textformat.abc";
        case XCPlaylistSortTypeNameDesc:
            return @"textformat.abc.dottedunderline";
        case XCPlaylistSortTypeSongCountDesc:
            return @"number";
        default:
            return @"questionmark";
    }
}

@end
