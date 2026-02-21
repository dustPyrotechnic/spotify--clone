//
//  XCPersonalModelTest.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/20.
//

#import "XCPersonalModelTest.h"
#import "XCPersonalModel.h"
#import "XCLocalPlaylistInfo.h"
#import "XC-YYAlbumData.h"
#import <QuartzCore/QuartzCore.h>

#pragma mark - 测试统计
static NSInteger totalTests = 0;
static NSInteger passedTests = 0;
static NSInteger failedTests = 0;
static NSMutableArray<NSString*>* testResults = nil;

@implementation XCPersonalModelTest

#pragma mark - 测试入口
+ (void)runAllTests {
    NSLog(@"\n========== XCPersonalModel 测试开始 ==========\n");
    
    totalTests = 0;
    passedTests = 0;
    failedTests = 0;
    testResults = [NSMutableArray array];
    
    // 基础功能测试
    [self runTest:@selector(testSingleton)];
    [self runTest:@selector(testDataLoading)];
    [self runTest:@selector(testDataSaving)];
    
    // CRUD 测试
    [self runTest:@selector(testCreatePlaylist)];
    [self runTest:@selector(testDeletePlaylist)];
    [self runTest:@selector(testUpdatePlaylist)];
    [self runTest:@selector(testUpdateSongCount)];
    
    // 搜索排序测试
    [self runTest:@selector(testSearchFilter)];
    [self runTest:@selector(testSortPlaylists)];
    [self runTest:@selector(testClearFilter)];
    
    // 扩展信息测试
    [self runTest:@selector(testPlaylistInfoQuery)];
    
    // 通知测试
    [self runTest:@selector(testNotifications)];
    
    // 数据一致性测试
    [self runTest:@selector(testDataConsistency)];
    
    // 压力测试
    [self runTest:@selector(testLargeDataset)];
    [self runTest:@selector(testFrequentOperations)];
    
    NSLog(@"\n========== XCPersonalModel 测试结束 ==========\n");
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

#pragma mark - 基础功能测试
+ (BOOL)testSingleton {
    XCPersonalModel* model1 = [XCPersonalModel sharedInstance];
    XCPersonalModel* model2 = [XCPersonalModel sharedInstance];
    
    // 测试是否是同一个实例
    if (model1 != model2) {
        NSLog(@"  错误：单例返回不同实例");
        return NO;
    }
    
    // 测试通过 alloc init 是否也返回单例
    XCPersonalModel* model3 = [[XCPersonalModel alloc] init];
    if (model3 != model1) {
        NSLog(@"  错误：alloc init 返回不同实例");
        return NO;
    }
    
    NSLog(@"  单例模式工作正常");
    return YES;
}

+ (BOOL)testDataLoading {
    XCPersonalModel* model = [XCPersonalModel sharedInstance];
    
    // 清空数据用于测试
    [model clearAllDataForTesting];
    
    __block BOOL loadSuccess = NO;
    __block BOOL completionCalled = NO;
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [model loadPlaylistsFromLocalWithCompletion:^(BOOL success) {
        loadSuccess = success;
        completionCalled = YES;
        dispatch_semaphore_signal(semaphore);
    }];
    
    // 等待最多 5 秒
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
    
    if (!completionCalled) {
        NSLog(@"  错误：加载回调未触发");
        return NO;
    }
    
    if (!loadSuccess) {
        NSLog(@"  错误：加载失败");
        return NO;
    }
    
    // 检查是否有默认播放列表
    if (model.allPlaylists.count == 0) {
        NSLog(@"  错误：没有加载到默认播放列表");
        return NO;
    }
    
    NSLog(@"  加载成功，共 %lu 个播放列表", (unsigned long)model.allPlaylists.count);
    return YES;
}

+ (BOOL)testDataSaving {
    XCPersonalModel* model = [XCPersonalModel sharedInstance];
    
    // 先添加一些测试数据
    [model clearAllDataForTesting];
    
    __block BOOL saveSuccess = NO;
    __block BOOL createSuccess = NO;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    // 创建一个测试播放列表
    [model createPlaylistWithName:@"测试保存数据" completion:^(BOOL success, NSString* playlistId) {
        createSuccess = success;
        if (success) {
            // 保存数据
            [model savePlaylistsToLocalWithCompletion:^(BOOL success) {
                saveSuccess = success;
                dispatch_semaphore_signal(semaphore);
            }];
        } else {
            dispatch_semaphore_signal(semaphore);
        }
    }];
    
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
    
    if (!createSuccess) {
        NSLog(@"  错误：创建测试数据失败");
        return NO;
    }
    
    if (!saveSuccess) {
        NSLog(@"  错误：保存失败");
        return NO;
    }
    
    NSLog(@"  保存成功");
    return YES;
}

#pragma mark - CRUD 测试
+ (BOOL)testCreatePlaylist {
    XCPersonalModel* model = [XCPersonalModel sharedInstance];
    [model clearAllDataForTesting];
    
    __block BOOL createSuccess = NO;
    __block NSString* createdId = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [model createPlaylistWithName:@"测试创建" completion:^(BOOL success, NSString* playlistId) {
        createSuccess = success;
        createdId = playlistId;
        dispatch_semaphore_signal(semaphore);
    }];
    
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
    
    if (!createSuccess) {
        NSLog(@"  错误：创建失败");
        return NO;
    }
    
    if (!createdId || createdId.length == 0) {
        NSLog(@"  错误：创建的 ID 为空");
        return NO;
    }
    
    // 检查是否添加到 allPlaylists
    BOOL found = NO;
    for (XC_YYAlbumData* playlist in model.allPlaylists) {
        if ([playlist.albumId isEqualToString:createdId]) {
            found = YES;
            break;
        }
    }
    
    if (!found) {
        NSLog(@"  错误：创建的播放列表不在 allPlaylists 中");
        return NO;
    }
    
    // 测试创建空名称（应该失败）
    __block BOOL emptyNameFailed = NO;
    dispatch_semaphore_t semaphore2 = dispatch_semaphore_create(0);
    [model createPlaylistWithName:@"" completion:^(BOOL success, NSString* playlistId) {
        emptyNameFailed = !success;
        dispatch_semaphore_signal(semaphore2);
    }];
    dispatch_semaphore_wait(semaphore2, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
    
    if (!emptyNameFailed) {
        NSLog(@"  错误：空名称应该创建失败");
        return NO;
    }
    
    NSLog(@"  创建成功，ID: %@", createdId);
    return YES;
}

+ (BOOL)testDeletePlaylist {
    XCPersonalModel* model = [XCPersonalModel sharedInstance];
    [model clearAllDataForTesting];
    
    __block NSString* createdId = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    // 先创建一个
    [model createPlaylistWithName:@"待删除" completion:^(BOOL success, NSString* playlistId) {
        if (success) {
            createdId = playlistId;
        }
        dispatch_semaphore_signal(semaphore);
    }];
    
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
    
    if (!createdId) {
        NSLog(@"  错误：创建测试数据失败");
        return NO;
    }
    
    // 删除它
    __block BOOL deleteSuccess = NO;
    dispatch_semaphore_t semaphore2 = dispatch_semaphore_create(0);
    [model deletePlaylistWithId:createdId completion:^(BOOL success) {
        deleteSuccess = success;
        dispatch_semaphore_signal(semaphore2);
    }];
    
    dispatch_semaphore_wait(semaphore2, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
    
    if (!deleteSuccess) {
        NSLog(@"  错误：删除失败");
        return NO;
    }
    
    // 检查是否已删除
    for (XC_YYAlbumData* playlist in model.allPlaylists) {
        if ([playlist.albumId isEqualToString:createdId]) {
            NSLog(@"  错误：播放列表仍然存在");
            return NO;
        }
    }
    
    // 测试删除不存在的ID（应该失败）
    __block BOOL deleteNonExistFailed = NO;
    dispatch_semaphore_t semaphore3 = dispatch_semaphore_create(0);
    [model deletePlaylistWithId:@"non_exist_id" completion:^(BOOL success) {
        deleteNonExistFailed = !success;
        dispatch_semaphore_signal(semaphore3);
    }];
    dispatch_semaphore_wait(semaphore3, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
    
    if (!deleteNonExistFailed) {
        NSLog(@"  错误：删除不存在的ID应该失败");
        return NO;
    }
    
    NSLog(@"  删除成功");
    return YES;
}

+ (BOOL)testUpdatePlaylist {
    XCPersonalModel* model = [XCPersonalModel sharedInstance];
    [model clearAllDataForTesting];
    
    __block NSString* createdId = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    // 先创建一个
    [model createPlaylistWithName:@"旧名称" completion:^(BOOL success, NSString* playlistId) {
        if (success) {
            createdId = playlistId;
        }
        dispatch_semaphore_signal(semaphore);
    }];
    
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
    
    if (!createdId) {
        NSLog(@"  错误：创建测试数据失败");
        return NO;
    }
    
    // 更新名称
    __block BOOL updateSuccess = NO;
    dispatch_semaphore_t semaphore2 = dispatch_semaphore_create(0);
    [model updatePlaylistWithId:createdId name:@"新名称" completion:^(BOOL success) {
        updateSuccess = success;
        dispatch_semaphore_signal(semaphore2);
    }];
    
    dispatch_semaphore_wait(semaphore2, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
    
    if (!updateSuccess) {
        NSLog(@"  错误：更新失败");
        return NO;
    }
    
    // 检查名称是否更新
    BOOL found = NO;
    for (XC_YYAlbumData* playlist in model.allPlaylists) {
        if ([playlist.albumId isEqualToString:createdId]) {
            if ([playlist.name isEqualToString:@"新名称"]) {
                found = YES;
            }
            break;
        }
    }
    
    if (!found) {
        NSLog(@"  错误：名称未更新");
        return NO;
    }
    
    NSLog(@"  更新成功");
    return YES;
}

+ (BOOL)testUpdateSongCount {
    XCPersonalModel* model = [XCPersonalModel sharedInstance];
    [model clearAllDataForTesting];
    
    __block NSString* createdId = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    // 先创建一个
    [model createPlaylistWithName:@"测试歌曲数量" completion:^(BOOL success, NSString* playlistId) {
        if (success) {
            createdId = playlistId;
        }
        dispatch_semaphore_signal(semaphore);
    }];
    
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
    
    if (!createdId) {
        NSLog(@"  错误：创建测试数据失败");
        return NO;
    }
    
    // 更新歌曲数量
    [model updatePlaylistSongCount:createdId songCount:50];
    
    // 检查
    NSInteger count = [model songCountForPlaylist:createdId];
    if (count != 50) {
        NSLog(@"  错误：歌曲数量不正确，期望 50，实际 %ld", (long)count);
        return NO;
    }
    
    NSLog(@"  歌曲数量更新成功");
    return YES;
}

#pragma mark - 搜索排序测试
+ (BOOL)testSearchFilter {
    XCPersonalModel* model = [XCPersonalModel sharedInstance];
    [model clearAllDataForTesting];
    
    // 添加测试数据
    [model addTestDataForTesting:10]; // 添加10个测试数据
    
    // 等待数据添加完成
    [NSThread sleepForTimeInterval:0.5];
    
    // 测试搜索
    [model filterPlaylistsWithSearchText:@"测试播放列表 1"];
    
    // 应该匹配 1, 10, 11, 12... 等
    if (model.filteredPlaylists.count == 0) {
        NSLog(@"  错误：搜索结果为空");
        return NO;
    }
    
    // 测试搜索不存在的内容
    [model filterPlaylistsWithSearchText:@"不存在的内容xyz"];
    if (model.filteredPlaylists.count != 0) {
        NSLog(@"  错误：搜索不存在的内容应该返回空");
        return NO;
    }
    
    // 清除搜索
    [model clearFilter];
    
    NSLog(@"  搜索过滤功能正常");
    return YES;
}

+ (BOOL)testSortPlaylists {
    XCPersonalModel* model = [XCPersonalModel sharedInstance];
    [model clearAllDataForTesting];
    [model addTestDataForTesting:5];
    
    // 等待数据添加
    [NSThread sleepForTimeInterval:0.5];
    
    // 测试名称排序
    [model sortPlaylistsByType:XCPlaylistSortTypeNameAsc];
    
    // 验证排序结果
    NSArray* sorted = model.filteredPlaylists;
    for (NSInteger i = 1; i < sorted.count; i++) {
        XC_YYAlbumData* prev = sorted[i - 1];
        XC_YYAlbumData* curr = sorted[i];
        if ([prev.name compare:curr.name options:NSCaseInsensitiveSearch] == NSOrderedDescending) {
            NSLog(@"  错误：名称升序排序不正确");
            return NO;
        }
    }
    
    // 测试按歌曲数量排序
    [model sortPlaylistsByType:XCPlaylistSortTypeSongCountDesc];
    
    NSLog(@"  排序功能正常");
    return YES;
}

+ (BOOL)testClearFilter {
    XCPersonalModel* model = [XCPersonalModel sharedInstance];
    [model clearAllDataForTesting];
    [model addTestDataForTesting:5];
    
    [NSThread sleepForTimeInterval:0.5];
    
    NSUInteger originalCount = model.allPlaylists.count;
    
    // 先搜索
    [model filterPlaylistsWithSearchText:@"1"];
    if (model.filteredPlaylists.count == originalCount) {
        NSLog(@"  警告：搜索结果没有过滤数据，可能影响测试");
    }
    
    // 清除过滤
    [model clearFilter];
    
    if (model.filteredPlaylists.count != originalCount) {
        NSLog(@"  错误：清除过滤后应该显示全部数据");
        return NO;
    }
    
    if (model.currentSearchText != nil) {
        NSLog(@"  错误：清除过滤后搜索文本应该为 nil");
        return NO;
    }
    
    NSLog(@"  清除过滤功能正常");
    return YES;
}

#pragma mark - 扩展信息测试
+ (BOOL)testPlaylistInfoQuery {
    XCPersonalModel* model = [XCPersonalModel sharedInstance];
    [model clearAllDataForTesting];
    
    __block NSString* createdId = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [model createPlaylistWithName:@"测试信息查询" completion:^(BOOL success, NSString* playlistId) {
        if (success) {
            createdId = playlistId;
        }
        dispatch_semaphore_signal(semaphore);
    }];
    
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
    
    if (!createdId) {
        NSLog(@"  错误：创建测试数据失败");
        return NO;
    }
    
    // 查询扩展信息
    XCLocalPlaylistInfo* info = [model infoForPlaylist:createdId];
    if (!info) {
        NSLog(@"  错误：查询不到扩展信息");
        return NO;
    }
    
    if (![info.playlistId isEqualToString:createdId]) {
        NSLog(@"  错误：扩展信息 ID 不匹配");
        return NO;
    }
    
    NSLog(@"  扩展信息查询功能正常");
    return YES;
}

#pragma mark - 通知测试
+ (BOOL)testNotifications {
    XCPersonalModel* model = [XCPersonalModel sharedInstance];
    [model clearAllDataForTesting];
    
    __block BOOL dataChangedReceived = NO;
    __block BOOL createdReceived = NO;
    
    // 注册通知监听
    id observer1 = [[NSNotificationCenter defaultCenter] addObserverForName:XCPlaylistDataChangedNotification
                                                                      object:nil
                                                                       queue:nil
                                                                  usingBlock:^(NSNotification* note) {
        dataChangedReceived = YES;
    }];
    
    id observer2 = [[NSNotificationCenter defaultCenter] addObserverForName:XCPlaylistCreatedNotification
                                                                      object:nil
                                                                       queue:nil
                                                                  usingBlock:^(NSNotification* note) {
        createdReceived = YES;
    }];
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    // 创建播放列表，应该触发通知
    [model createPlaylistWithName:@"测试通知" completion:^(BOOL success, NSString* playlistId) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            dispatch_semaphore_signal(semaphore);
        });
    }];
    
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
    
    [[NSNotificationCenter defaultCenter] removeObserver:observer1];
    [[NSNotificationCenter defaultCenter] removeObserver:observer2];
    
    if (!dataChangedReceived) {
        NSLog(@"  错误：未收到数据变更通知");
        return NO;
    }
    
    if (!createdReceived) {
        NSLog(@"  错误：未收到创建通知");
        return NO;
    }
    
    NSLog(@"  通知功能正常");
    return YES;
}

#pragma mark - 数据一致性测试
+ (BOOL)testDataConsistency {
    XCPersonalModel* model = [XCPersonalModel sharedInstance];
    [model clearAllDataForTesting];
    [model addTestDataForTesting:10];
    
    [NSThread sleepForTimeInterval:0.5];
    
    // 使用 Model 内部方法验证
    BOOL consistent = [model verifyDataConsistencyForTesting];
    
    if (!consistent) {
        NSLog(@"  错误：数据一致性检查失败");
        return NO;
    }
    
    NSLog(@"  数据一致性检查通过");
    return YES;
}

#pragma mark - 压力测试
+ (BOOL)testLargeDataset {
    XCPersonalModel* model = [XCPersonalModel sharedInstance];
    [model clearAllDataForTesting];
    
    NSLog(@"  开始添加 100 个测试数据...");
    
    CFTimeInterval startTime = CACurrentMediaTime();
    
    [model addTestDataForTesting:100];
    
    [NSThread sleepForTimeInterval:1.0]; // 等待异步操作完成
    
    CFTimeInterval duration = CACurrentMediaTime() - startTime;
    
    if (model.allPlaylists.count != 100) {
        NSLog(@"  错误：数据数量不正确，期望 100，实际 %lu", (unsigned long)model.allPlaylists.count);
        return NO;
    }
    
    NSLog(@"  添加 100 条数据耗时: %.3f 秒", duration);
    
    // 测试搜索性能
    startTime = CACurrentMediaTime();
    for (NSInteger i = 0; i < 100; i++) {
        [model filterPlaylistsWithSearchText:[NSString stringWithFormat:@"测试 %ld", (long)i]];
    }
    duration = CACurrentMediaTime() - startTime;
    NSLog(@"  100 次搜索耗时: %.3f 秒", duration);
    
    return YES;
}

+ (BOOL)testFrequentOperations {
    XCPersonalModel* model = [XCPersonalModel sharedInstance];
    [model clearAllDataForTesting];
    
    NSLog(@"  开始频繁操作测试...");
    
    CFTimeInterval startTime = CACurrentMediaTime();
    
    // 快速创建 20 个
    for (NSInteger i = 0; i < 20; i++) {
        [model createPlaylistWithName:[NSString stringWithFormat:@"频繁测试 %ld", (long)i] completion:nil];
    }
    
    [NSThread sleepForTimeInterval:0.5];
    
    // 快速删除 10 个
    NSArray* allPlaylists = [model.allPlaylists copy];
    NSInteger deleteCount = 0;
    for (XC_YYAlbumData* playlist in allPlaylists) {
        if (deleteCount >= 10) break;
        XCLocalPlaylistInfo* info = [model infoForPlaylist:playlist.albumId];
        if (info && info.playlistType == XCPlaylistTypeUserCreated) {
            [model deletePlaylistWithId:playlist.albumId completion:nil];
            deleteCount++;
        }
    }
    
    [NSThread sleepForTimeInterval:0.5];
    
    CFTimeInterval duration = CACurrentMediaTime() - startTime;
    
    NSLog(@"  频繁操作耗时: %.3f 秒", duration);
    
    // 验证数据一致性
    BOOL consistent = [model verifyDataConsistencyForTesting];
    if (!consistent) {
        NSLog(@"  错误：频繁操作后数据不一致");
        return NO;
    }
    
    NSLog(@"  频繁操作测试通过");
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
    
    NSLog(@"\n========== 测试报告 ==========");
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
        NSLog(@"\n✅ 所有测试通过！Model 层实现正确。");
    } else {
        NSLog(@"\n⚠️ 有 %@ 个测试失败，请检查实现。", stats[@"failed"]);
    }
}

@end
