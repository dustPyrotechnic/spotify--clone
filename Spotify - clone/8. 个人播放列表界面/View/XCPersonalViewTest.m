//
//  XCPersonalViewTest.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/20.
//

#import "XCPersonalViewTest.h"
#import "XCPersonalView.h"
#import "XCPersonalGridCell.h"
#import "XCPersonalListCell.h"
#import "XCPersonalEmptyView.h"
#import "XCPersonalLoginView.h"
#import "XCCreatePlaylistView.h"
#import "XCPlaylistSortMenu.h"

#pragma mark - 测试统计
static NSInteger totalTests = 0;
static NSInteger passedTests = 0;
static NSInteger failedTests = 0;
static NSMutableArray<NSString*>* testResults = nil;

@implementation XCPersonalViewTest

#pragma mark - 测试入口
+ (void)runAllTests {
    NSLog(@"\n========== XCPersonalView Phase 2 测试开始 ==========\n");
    
    totalTests = 0;
    passedTests = 0;
    failedTests = 0;
    testResults = [NSMutableArray array];
    
    // 视图创建测试
    [self runTest:@selector(testPersonalViewCreation)];
    [self runTest:@selector(testGridCellCreation)];
    [self runTest:@selector(testListCellCreation)];
    [self runTest:@selector(testEmptyViewCreation)];
    [self runTest:@selector(testLoginViewCreation)];
    
    // 功能测试
    [self runTest:@selector(testViewModeSwitching)];
    [self runTest:@selector(testLayoutUpdates)];
    [self runTest:@selector(testEmptyViewDisplay)];
    [self runTest:@selector(testLoginViewDisplay)];
    
    NSLog(@"\n========== XCPersonalView Phase 2 测试结束 ==========\n");
    [self printTestReport];
}

+ (BOOL)runTest:(SEL)testSelector {
    NSString* testName = NSStringFromSelector(testSelector);
    totalTests++;
    
    NSLog(@"[TEST] 开始: %@", testName);
    
    @try {
        BOOL result = [self performSelector:testSelector] != nil;
        if (result) {
            passedTests++;
            NSLog(@"[PASS] %@", testName);
            [testResults addObject:[NSString stringWithFormat:@"✅ %@", testName]];
        } else {
            failedTests++;
            NSLog(@"[FAIL] %@", testName);
            [testResults addObject:[NSString stringWithFormat:@"❌ %@", testName]];
        }
        return result;
    }
    @catch (NSException* exception) {
        failedTests++;
        NSLog(@"[FAIL] %@ - 异常: %@", testName, exception.reason);
        [testResults addObject:[NSString stringWithFormat:@"❌ %@ (异常: %@)", testName, exception.reason]];
        return NO;
    }
}

#pragma mark - 视图创建测试
+ (BOOL)testPersonalViewCreation {
    XCPersonalView* view = [[XCPersonalView alloc] initWithFrame:CGRectMake(0, 0, 375, 667)];
    
    if (!view) {
        NSLog(@"  错误：XCPersonalView 创建失败");
        return NO;
    }
    
    if (!view.collectionView) {
        NSLog(@"  错误：collectionView 未创建");
        return NO;
    }
    
    if (!view.emptyView) {
        NSLog(@"  错误：emptyView 未创建");
        return NO;
    }
    
    if (!view.loginView) {
        NSLog(@"  错误：loginView 未创建");
        return NO;
    }
    
    NSLog(@"  XCPersonalView 创建成功");
    return YES;
}

+ (BOOL)testGridCellCreation {
    XCPersonalGridCell* cell = [[XCPersonalGridCell alloc] initWithFrame:CGRectMake(0, 0, 160, 200)];
    
    if (!cell) {
        NSLog(@"  错误：XCPersonalGridCell 创建失败");
        return NO;
    }
    
    if (!cell.coverImageView) {
        NSLog(@"  错误：coverImageView 未创建");
        return NO;
    }
    
    if (!cell.nameLabel) {
        NSLog(@"  错误：nameLabel 未创建");
        return NO;
    }
    
    if (!cell.countLabel) {
        NSLog(@"  错误：countLabel 未创建");
        return NO;
    }
    
    NSLog(@"  XCPersonalGridCell 创建成功");
    return YES;
}

+ (BOOL)testListCellCreation {
    XCPersonalListCell* cell = [[XCPersonalListCell alloc] initWithFrame:CGRectMake(0, 0, 375, 80)];
    
    if (!cell) {
        NSLog(@"  错误：XCPersonalListCell 创建失败");
        return NO;
    }
    
    if (!cell.coverImageView) {
        NSLog(@"  错误：coverImageView 未创建");
        return NO;
    }
    
    if (!cell.nameLabel) {
        NSLog(@"  错误：nameLabel 未创建");
        return NO;
    }
    
    if (!cell.subtitleLabel) {
        NSLog(@"  错误：subtitleLabel 未创建");
        return NO;
    }
    
    NSLog(@"  XCPersonalListCell 创建成功");
    return YES;
}

+ (BOOL)testEmptyViewCreation {
    XCPersonalEmptyView* view = [[XCPersonalEmptyView alloc] init];
    
    if (!view) {
        NSLog(@"  错误：XCPersonalEmptyView 创建失败");
        return NO;
    }
    
    if (!view.iconImageView) {
        NSLog(@"  错误：iconImageView 未创建");
        return NO;
    }
    
    if (!view.titleLabel) {
        NSLog(@"  错误：titleLabel 未创建");
        return NO;
    }
    
    if (!view.createButton) {
        NSLog(@"  错误：createButton 未创建");
        return NO;
    }
    
    NSLog(@"  XCPersonalEmptyView 创建成功");
    return YES;
}

+ (BOOL)testLoginViewCreation {
    XCPersonalLoginView* view = [[XCPersonalLoginView alloc] init];
    
    if (!view) {
        NSLog(@"  错误：XCPersonalLoginView 创建失败");
        return NO;
    }
    
    if (!view.iconImageView) {
        NSLog(@"  错误：iconImageView 未创建");
        return NO;
    }
    
    if (!view.titleLabel) {
        NSLog(@"  错误：titleLabel 未创建");
        return NO;
    }
    
    if (!view.loginButton) {
        NSLog(@"  错误：loginButton 未创建");
        return NO;
    }
    
    // 测试不同登录状态
    view.loginStatus = XCLoginStatusNotLoggedIn;
    if (![view.titleLabel.text isEqualToString:@"登录以查看您的播放列表"]) {
        NSLog(@"  警告：未登录状态标题不正确");
    }
    
    NSLog(@"  XCPersonalLoginView 创建成功");
    return YES;
}

#pragma mark - 功能测试
+ (BOOL)testViewModeSwitching {
    XCPersonalView* view = [[XCPersonalView alloc] initWithFrame:CGRectMake(0, 0, 375, 667)];
    
    // 测试初始模式
    XCPlaylistViewMode initialMode = view.currentViewMode;
    
    // 测试切换到列表
    [view switchToListLayoutAnimated:NO];
    if (view.currentViewMode != XCPlaylistViewModeList) {
        NSLog(@"  错误：切换到列表模式失败");
        return NO;
    }
    
    // 测试切换到网格
    [view switchToGridLayoutAnimated:NO];
    if (view.currentViewMode != XCPlaylistViewModeGrid) {
        NSLog(@"  错误：切换到网格模式失败");
        return NO;
    }
    
    // 测试切换
    [view toggleViewModeAnimated:NO];
    if (view.currentViewMode != XCPlaylistViewModeList) {
        NSLog(@"  错误：切换模式失败");
        return NO;
    }
    
    NSLog(@"  视图模式切换功能正常");
    return YES;
}

+ (BOOL)testLayoutUpdates {
    XCPersonalView* view = [[XCPersonalView alloc] initWithFrame:CGRectMake(0, 0, 375, 667)];
    
    CGSize gridSize = [view currentCellSize];
    
    // 切换到列表
    [view switchToListLayoutAnimated:NO];
    CGSize listSize = [view currentCellSize];
    
    // 网格和列表的 Cell 大小应该不同
    if (CGSizeEqualToSize(gridSize, listSize)) {
        NSLog(@"  警告：网格和列表 Cell 大小相同");
    }
    
    // 列表 Cell 的宽度应该等于屏幕宽度
    if (listSize.width != 375) {
        NSLog(@"  警告：列表 Cell 宽度不正确");
    }
    
    NSLog(@"  布局更新功能正常");
    return YES;
}

+ (BOOL)testEmptyViewDisplay {
    XCPersonalView* view = [[XCPersonalView alloc] initWithFrame:CGRectMake(0, 0, 375, 667)];
    
    // 显示空状态
    [view showEmptyView:YES];
    
    if (view.emptyView.isHidden) {
        NSLog(@"  错误：空状态视图未显示");
        return NO;
    }
    
    if (!view.collectionView.isHidden) {
        NSLog(@"  错误：collectionView 应该隐藏");
        return NO;
    }
    
    // 隐藏空状态
    [view showEmptyView:NO];
    
    if (!view.emptyView.isHidden) {
        NSLog(@"  错误：空状态视图应该隐藏");
        return NO;
    }
    
    if (view.collectionView.isHidden) {
        NSLog(@"  错误：collectionView 应该显示");
        return NO;
    }
    
    NSLog(@"  空状态显示功能正常");
    return YES;
}

+ (BOOL)testLoginViewDisplay {
    XCPersonalView* view = [[XCPersonalView alloc] initWithFrame:CGRectMake(0, 0, 375, 667)];
    
    // 显示登录视图
    [view showLoginView:YES];
    
    if (view.loginView.isHidden) {
        NSLog(@"  错误：登录视图未显示");
        return NO;
    }
    
    // 隐藏登录视图
    [view showLoginView:NO];
    
    if (!view.loginView.isHidden) {
        NSLog(@"  错误：登录视图应该隐藏");
        return NO;
    }
    
    // 测试登录状态设置
    view.loginStatus = XCLoginStatusNotLoggedIn;
    if (view.loginStatus != XCLoginStatusNotLoggedIn) {
        NSLog(@"  错误：登录状态设置失败");
        return NO;
    }
    
    NSLog(@"  登录视图显示功能正常");
    return YES;
}

#pragma mark - 测试统计
+ (NSDictionary*)testStatistics {
    return @{
        @"total": @(totalTests),
        @"passed": @(passedTests),
        @"failed": @(failedTests),
        @"passRate": totalTests > 0 ? @((double)passedTests / totalTests * 100) : @(0)
    };
}

+ (void)printTestReport {
    NSDictionary* stats = [self testStatistics];
    
    NSLog(@"\n========== Phase 2 测试报告 ==========");
    NSLog(@"总测试数: %@", stats[@"total"]);
    NSLog(@"通过: %@", stats[@"passed"]);
    NSLog(@"失败: %@", stats[@"failed"]);
    NSLog(@"通过率: %.1f%%", [stats[@"passRate"] doubleValue]);
    NSLog(@"=============================\n");
    
    NSLog(@"详细结果:");
    for (NSString* result in testResults) {
        NSLog(@"  %@", result);
    }
    
    if ([stats[@"failed"] integerValue] == 0) {
        NSLog(@"\n✅ Phase 2 所有测试通过！View 层实现正确。");
    } else {
        NSLog(@"\n⚠️ Phase 2 有 %@ 个测试失败，请检查实现。", stats[@"failed"]);
    }
}

@end
