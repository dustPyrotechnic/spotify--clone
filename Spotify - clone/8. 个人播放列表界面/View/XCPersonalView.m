//
//  XCPersonalView.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/1.
//

#import "XCPersonalView.h"
#import "cells/XCPersonalLoginView.h"
#import "cells/XCPersonalEmptyView.h"
#import <Masonry/Masonry.h>

#pragma mark - 布局配置常量
static const CGFloat kGridCellSpacing = 16.0;           // 网格间距
static const CGFloat kGridSectionInset = 16.0;          // 网格边距
static const CGFloat kListCellHeight = 80.0;            // 列表 Cell 高度
static const CGFloat kListCellSpacing = 0.0;            // 列表间距（使用分割线）
static const NSInteger kGridColumns = 2;                // 网格列数

@interface XCPersonalView () <UICollectionViewDelegateFlowLayout>

#pragma mark - 子视图（私有）
@property (nonatomic, strong, readwrite) UICollectionView* collectionView;
@property (nonatomic, strong, readwrite) UIView* emptyView;
@property (nonatomic, strong, readwrite) UIView* loginView;
@property (nonatomic, strong) UIActivityIndicatorView* loadingIndicator;

#pragma mark - 布局
@property (nonatomic, strong) UICollectionViewFlowLayout* gridLayout;
@property (nonatomic, strong) UICollectionViewFlowLayout* listLayout;

#pragma mark - 状态
@property (nonatomic, assign, readwrite) XCPlaylistViewMode currentViewMode;

@end

@implementation XCPersonalView

#pragma mark - 初始化
- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupLayouts];
        [self setupView];
        [self setupConstraints];
        
        // 默认视图模式（从 UserDefaults 读取）
        NSInteger savedMode = [[NSUserDefaults standardUserDefaults] integerForKey:@"XCPlaylistViewMode"];
        _currentViewMode = (savedMode == XCPlaylistViewModeList) ? XCPlaylistViewModeList : XCPlaylistViewModeGrid;
        
        // 默认登录状态
        _loginStatus = XCLoginStatusUnknown;
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupLayouts];
        [self setupView];
        [self setupConstraints];
        
        NSInteger savedMode = [[NSUserDefaults standardUserDefaults] integerForKey:@"XCPlaylistViewMode"];
        _currentViewMode = (savedMode == XCPlaylistViewModeList) ? XCPlaylistViewModeList : XCPlaylistViewModeGrid;
        _loginStatus = XCLoginStatusUnknown;
    }
    return self;
}

#pragma mark - 视图设置
- (void)setupView {
    self.backgroundColor = [UIColor systemBackgroundColor];
    
    // 创建集合视图
    [self setupCollectionView];
    
    // 创建空状态视图
    [self setupEmptyView];
    
    // 创建登录视图（预留）
    [self setupLoginView];
    
    // 创建加载指示器
    [self setupLoadingIndicator];
}

- (void)setupCollectionView {
    // 初始使用网格布局
    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero 
                                             collectionViewLayout:self.gridLayout];
    self.collectionView.backgroundColor = [UIColor systemBackgroundColor];
    self.collectionView.showsVerticalScrollIndicator = YES;
    self.collectionView.showsHorizontalScrollIndicator = NO;
    self.collectionView.alwaysBounceVertical = YES;
    self.collectionView.delegate = self;
    
    // 注册 Cell（具体 Cell 类由 Controller 注册）
    // 这里只是设置基本属性
    
    [self addSubview:self.collectionView];
}

- (void)setupEmptyView {
    self.emptyView = [[XCPersonalEmptyView alloc] init];
    self.emptyView.hidden = YES;
    self.emptyView.alpha = 0.0;
    
    // 设置空状态视图的代理回调
    if ([self.emptyView isKindOfClass:[XCPersonalEmptyView class]]) {
        __weak typeof(self) weakSelf = self;
        ((XCPersonalEmptyView*)self.emptyView).createButtonTapHandler = ^{
            if ([weakSelf.delegate respondsToSelector:@selector(personalViewDidTapCreateButton:)]) {
                [weakSelf.delegate personalViewDidTapCreateButton:weakSelf];
            }
        };
    }
    
    [self addSubview:self.emptyView];
}

- (void)setupLoginView {
    self.loginView = [[XCPersonalLoginView alloc] init];
    self.loginView.hidden = YES;
    self.loginView.alpha = 0.0;
    
    // 设置登录视图的代理回调
    if ([self.loginView isKindOfClass:[XCPersonalLoginView class]]) {
        __weak typeof(self) weakSelf = self;
        ((XCPersonalLoginView*)self.loginView).loginButtonTapHandler = ^{
            if ([weakSelf.delegate respondsToSelector:@selector(personalViewDidTapLoginButton:)]) {
                [weakSelf.delegate personalViewDidTapLoginButton:weakSelf];
            }
        };
    }
    
    [self addSubview:self.loginView];
}

- (void)setupLoadingIndicator {
    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.loadingIndicator.hidesWhenStopped = YES;
    self.loadingIndicator.color = [UIColor systemGreenColor];
    [self addSubview:self.loadingIndicator];
}

#pragma mark - 布局设置
- (void)setupLayouts {
    // 网格布局
    self.gridLayout = [[UICollectionViewFlowLayout alloc] init];
    self.gridLayout.minimumLineSpacing = kGridCellSpacing;
    self.gridLayout.minimumInteritemSpacing = kGridCellSpacing;
    self.gridLayout.sectionInset = UIEdgeInsetsMake(kGridSectionInset, kGridSectionInset, 
                                                     kGridSectionInset, kGridSectionInset);
    
    // 列表布局
    self.listLayout = [[UICollectionViewFlowLayout alloc] init];
    self.listLayout.minimumLineSpacing = kListCellSpacing;
    self.listLayout.minimumInteritemSpacing = 0;
    self.listLayout.sectionInset = UIEdgeInsetsZero;
}

- (void)setupConstraints {
    // CollectionView 约束
    [self.collectionView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self);
    }];
    
    // 空状态视图约束
    [self.emptyView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self);
        make.width.equalTo(self).multipliedBy(0.8);
        make.height.mas_equalTo(300);
    }];
    
    // 登录视图约束
    [self.loginView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self);
        make.width.equalTo(self).multipliedBy(0.8);
        make.height.mas_equalTo(300);
    }];
    
    // 加载指示器约束
    [self.loadingIndicator mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self);
    }];
}

#pragma mark - 布局计算
- (void)updateLayoutItemSize {
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    
    // 网格布局 Cell 大小
    CGFloat gridInset = kGridSectionInset * 2;
    CGFloat gridSpacing = kGridCellSpacing;
    CGFloat gridCellWidth = (screenWidth - gridInset - gridSpacing) / kGridColumns;
    CGFloat gridCellHeight = gridCellWidth + 50; // 封面 + 文字区域
    
    self.gridLayout.itemSize = CGSizeMake(gridCellWidth, gridCellHeight);
    
    // 列表布局 Cell 大小
    self.listLayout.itemSize = CGSizeMake(screenWidth, kListCellHeight);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self updateLayoutItemSize];
}

#pragma mark - 视图模式切换
- (void)switchToGridLayoutAnimated:(BOOL)animated {
    if (self.currentViewMode == XCPlaylistViewModeGrid) return;
    
    _currentViewMode = XCPlaylistViewModeGrid;
    [[NSUserDefaults standardUserDefaults] setInteger:XCPlaylistViewModeGrid forKey:@"XCPlaylistViewMode"];
    
    [self applyLayout:self.gridLayout animated:animated];
    
    // 通知代理
    if ([self.delegate respondsToSelector:@selector(personalView:didChangeViewMode:)]) {
        [self.delegate personalView:self didChangeViewMode:XCPlaylistViewModeGrid];
    }
}

- (void)switchToListLayoutAnimated:(BOOL)animated {
    if (self.currentViewMode == XCPlaylistViewModeList) return;
    
    _currentViewMode = XCPlaylistViewModeList;
    [[NSUserDefaults standardUserDefaults] setInteger:XCPlaylistViewModeList forKey:@"XCPlaylistViewMode"];
    
    [self applyLayout:self.listLayout animated:animated];
    
    // 通知代理
    if ([self.delegate respondsToSelector:@selector(personalView:didChangeViewMode:)]) {
        [self.delegate personalView:self didChangeViewMode:XCPlaylistViewModeList];
    }
}

- (void)toggleViewModeAnimated:(BOOL)animated {
    if (self.currentViewMode == XCPlaylistViewModeGrid) {
        [self switchToListLayoutAnimated:animated];
    } else {
        [self switchToGridLayoutAnimated:animated];
    }
}

- (void)applyLayout:(UICollectionViewLayout*)layout animated:(BOOL)animated {
    if (animated) {
        [UIView animateWithDuration:0.3 animations:^{
            [self.collectionView setCollectionViewLayout:layout animated:NO];
            [self.collectionView reloadData];
            [self.collectionView layoutIfNeeded];
        }];
    } else {
        [self.collectionView setCollectionViewLayout:layout animated:NO];
        [self.collectionView reloadData];
    }
}

#pragma mark - 状态显示
- (void)showEmptyView:(BOOL)show {
    if (show) {
        self.emptyView.hidden = NO;
        [UIView animateWithDuration:0.25 animations:^{
            self.emptyView.alpha = 1.0;
            self.collectionView.alpha = 0.0;
            self.loginView.alpha = 0.0;
        } completion:^(BOOL finished) {
            self.collectionView.hidden = YES;
            self.loginView.hidden = YES;
        }];
    } else {
        self.collectionView.hidden = NO;
        [UIView animateWithDuration:0.25 animations:^{
            self.emptyView.alpha = 0.0;
            self.collectionView.alpha = 1.0;
            self.loginView.alpha = 0.0;
        } completion:^(BOOL finished) {
            self.emptyView.hidden = YES;
            self.loginView.hidden = YES;
        }];
    }
}

- (void)showLoginView:(BOOL)show {
    if (show) {
        self.loginView.hidden = NO;
        [UIView animateWithDuration:0.25 animations:^{
            self.loginView.alpha = 1.0;
            self.collectionView.alpha = 0.0;
            self.emptyView.alpha = 0.0;
        } completion:^(BOOL finished) {
            self.collectionView.hidden = YES;
            self.emptyView.hidden = YES;
        }];
    } else {
        self.collectionView.hidden = NO;
        [UIView animateWithDuration:0.25 animations:^{
            self.loginView.alpha = 0.0;
            self.collectionView.alpha = 1.0;
            self.emptyView.alpha = 0.0;
        } completion:^(BOOL finished) {
            self.loginView.hidden = YES;
            self.emptyView.hidden = YES;
        }];
    }
}

- (void)showLoading:(BOOL)show {
    if (show) {
        [self.loadingIndicator startAnimating];
        self.collectionView.alpha = 0.5;
    } else {
        [self.loadingIndicator stopAnimating];
        self.collectionView.alpha = 1.0;
    }
}

#pragma mark - 刷新
- (void)reloadData {
    [self.collectionView reloadData];
}

- (void)reloadItemsAtIndexes:(NSArray<NSNumber*>*)indexes {
    NSMutableArray* indexPaths = [NSMutableArray array];
    for (NSNumber* index in indexes) {
        [indexPaths addObject:[NSIndexPath indexPathForItem:index.integerValue inSection:0]];
    }
    [self.collectionView reloadItemsAtIndexPaths:indexPaths];
}

#pragma mark - 便捷方法
- (CGSize)currentCellSize {
    if (self.currentViewMode == XCPlaylistViewModeGrid) {
        return self.gridLayout.itemSize;
    } else {
        return self.listLayout.itemSize;
    }
}

- (void)scrollToItemAtIndex:(NSInteger)index animated:(BOOL)animated {
    NSIndexPath* indexPath = [NSIndexPath indexPathForItem:index inSection:0];
    [self.collectionView scrollToItemAtIndexPath:indexPath 
                                atScrollPosition:UICollectionViewScrollPositionCenteredVertically 
                                        animated:animated];
}

#pragma mark - Setters
- (void)setLoginStatus:(XCLoginStatus)loginStatus {
    _loginStatus = loginStatus;
    
    // 根据登录状态更新 UI
    switch (loginStatus) {
        case XCLoginStatusNotLoggedIn:
        case XCLoginStatusLoginExpired:
            // 未登录或登录过期，显示登录提示
            [self showLoginView:YES];
            break;
            
        case XCLoginStatusUnknown:
        case XCLoginStatusLoggingIn:
            // 未知或正在登录，显示加载
            [self showLoading:YES];
            break;
            
        case XCLoginStatusLoggedIn:
            // 已登录，显示正常内容（由 Controller 控制空状态）
            [self showLoading:NO];
            break;
    }
    
    // 更新登录视图的状态
    if ([self.loginView isKindOfClass:[XCPersonalLoginView class]]) {
        ((XCPersonalLoginView*)self.loginView).loginStatus = loginStatus;
    }
}

#pragma mark - UICollectionViewDelegateFlowLayout
- (CGSize)collectionView:(UICollectionView*)collectionView 
                  layout:(UICollectionViewLayout*)collectionViewLayout 
  sizeForItemAtIndexPath:(NSIndexPath*)indexPath {
    return [self currentCellSize];
}

@end
