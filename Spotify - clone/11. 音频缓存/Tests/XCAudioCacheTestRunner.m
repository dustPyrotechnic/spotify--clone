//
//  XCAudioCacheTestRunner.m
//  Spotify - clone
//

#import "XCAudioCacheTestRunner.h"
#import "XCAudioCachePhase1Test.h"
#import "XCAudioCachePhase2Test.h"
#import "XCAudioCachePhase3Test.h"
#import "XCAudioCachePhase4Test.h"
#import "XCAudioCachePhase5Test.h"
#import "XCAudioCachePhase6Test.h"
#import "../L1/XCMemoryCacheManager.h"

@implementation XCAudioCacheTestRunner

+ (void)showTestMenuFromViewController:(UIViewController *)viewController {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"音频缓存测试"
                                                                   message:@"选择要运行的测试"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    // Phase 1 测试
    [alert addAction:[UIAlertAction actionWithTitle:@"运行 Phase 1 测试 (基础设施)"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        [self runPhase1Test];
    }]];
    
    // Phase 2 测试
    [alert addAction:[UIAlertAction actionWithTitle:@"运行 Phase 2 测试 (缓存索引)"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        [self runPhase2Test];
    }]];
    
    // Phase 3 测试
    [alert addAction:[UIAlertAction actionWithTitle:@"运行 Phase 3 测试 (L1 NSCache)"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        [self runPhase3Test];
    }]];
    
    // Phase 4 测试
    [alert addAction:[UIAlertAction actionWithTitle:@"运行 Phase 4 测试 (L3 完整缓存+合并)"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        [self runPhase4Test];
    }]];
    
    // Phase 5 测试
    [alert addAction:[UIAlertAction actionWithTitle:@"运行 Phase 5 测试 (L2 临时缓存)"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        [self runPhase5Test];
    }]];
    
    // Phase 6 测试
    [alert addAction:[UIAlertAction actionWithTitle:@"运行 Phase 6 测试 (缓存整合)"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        [self runPhase6Test];
    }]];
    
    // 全部测试
    [alert addAction:[UIAlertAction actionWithTitle:@"运行全部测试"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *action) {
        [self runAllPhaseTests];
    }]];
    
    // 快速功能验证
    [alert addAction:[UIAlertAction actionWithTitle:@"快速功能验证"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        [self quickValidation];
    }]];
    
    // 取消
    [alert addAction:[UIAlertAction actionWithTitle:@"取消"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    
    // iPad 支持
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        alert.popoverPresentationController.sourceView = viewController.view;
        alert.popoverPresentationController.sourceRect = CGRectMake(viewController.view.bounds.size.width / 2.0,
                                                                     viewController.view.bounds.size.height / 2.0,
                                                                     1.0, 1.0);
    }
    
    [viewController presentViewController:alert animated:YES completion:nil];
}

+ (void)runAllPhaseTests {
    NSLog(@"\n\n========================================");
    NSLog(@"       音频缓存完整测试开始");
    NSLog(@"========================================\n");
    
    [self runPhase1Test];
    [self runPhase2Test];
    [self runPhase3Test];
    [self runPhase4Test];
    [self runPhase5Test];
    [self runPhase6Test];
    
    NSLog(@"\n========================================");
    NSLog(@"       音频缓存完整测试结束");
    NSLog(@"========================================\n");
    
    [self showAlertWithTitle:@"测试完成" message:@"请查看 Xcode 控制台输出测试结果"];
}

+ (void)runPhase1Test {
    NSLog(@"\n>>> 开始 Phase 1 测试...");
    [XCAudioCachePhase1Test runAllTests];
    NSLog(@"<<< Phase 1 测试结束\n");
}

+ (void)runPhase2Test {
    NSLog(@"\n>>> 开始 Phase 2 测试...");
    [XCAudioCachePhase2Test runAllTests];
    NSLog(@"<<< Phase 2 测试结束\n");
}

+ (void)runPhase3Test {
    NSLog(@"\n>>> 开始 Phase 3 测试...");
    [XCAudioCachePhase3Test runAllTests];
    NSLog(@"<<< Phase 3 测试结束\n");
}

+ (void)runPhase4Test {
    NSLog(@"\n>>> 开始 Phase 4 测试...");
    [XCAudioCachePhase4Test runAllTests];
    NSLog(@"<<< Phase 4 测试结束\n");
}

+ (void)runPhase5Test {
    NSLog(@"\n>>> 开始 Phase 5 测试...");
    [XCAudioCachePhase5Test runAllTests];
    NSLog(@"<<< Phase 5 测试结束\n");
}

+ (void)runPhase6Test {
    NSLog(@"\n>>> 开始 Phase 6 测试...");
    [XCAudioCachePhase6Test runAllTests];
    NSLog(@"<<< Phase 6 测试结束\n");
}

+ (void)quickValidation {
    NSLog(@"\n========== 快速功能验证 ==========");
    
    XCMemoryCacheManager *manager = [XCMemoryCacheManager sharedInstance];
    [manager clearAllCache];
    
    // 测试 1: 基础存储和读取
    NSLog(@"[验证1] 基础存储和读取...");
    NSString *songId = @"test_quick_001";
    NSData *testData = [@"Hello Phase 3!" dataUsingEncoding:NSUTF8StringEncoding];
    
    [manager storeSegmentData:testData forSongId:songId segmentIndex:0];
    NSData *readData = [manager segmentDataForSongId:songId segmentIndex:0];
    
    if (readData && [readData isEqualToData:testData]) {
        NSLog(@"✅ 基础存储/读取: 通过");
    } else {
        NSLog(@"❌ 基础存储/读取: 失败");
    }
    
    // 测试 2: 多分段管理
    NSLog(@"[验证2] 多分段管理...");
    for (NSInteger i = 0; i < 5; i++) {
        NSString *content = [NSString stringWithFormat:@"Segment %ld", (long)i];
        [manager storeSegmentData:[content dataUsingEncoding:NSUTF8StringEncoding]
                       forSongId:songId
                    segmentIndex:i];
    }
    
    NSInteger count = [manager segmentCountForSongId:songId];
    if (count == 5) {
        NSLog(@"✅ 多分段管理: 通过 (5个分段)");
    } else {
        NSLog(@"❌ 多分段管理: 失败 (期望5，实际%ld)", (long)count);
    }
    
    // 测试 3: 优先级管理
    NSLog(@"[验证3] 优先级管理...");
    [manager setCurrentSongPriority:songId];
    NSString *otherSong = @"other_song_002";
    [manager storeSegmentData:[@"other" dataUsingEncoding:NSUTF8StringEncoding]
                   forSongId:otherSong
                segmentIndex:0];
    
    [manager trimCache];
    
    BOOL prioritySongExists = [manager hasSegmentForSongId:songId segmentIndex:0];
    BOOL otherSongExists = [manager hasSegmentForSongId:otherSong segmentIndex:0];
    
    if (prioritySongExists && !otherSongExists) {
        NSLog(@"✅ 优先级管理: 通过 (优先歌曲保留，其他清理)");
    } else {
        NSLog(@"❌ 优先级管理: 失败");
    }
    
    // 测试 4: 统计功能
    NSLog(@"[验证4] 统计功能...");
    [manager clearAllCache];
    [manager storeSegmentData:[@"a" dataUsingEncoding:NSUTF8StringEncoding] forSongId:@"song1" segmentIndex:0];
    [manager storeSegmentData:[@"b" dataUsingEncoding:NSUTF8StringEncoding] forSongId:@"song2" segmentIndex:0];
    [manager storeSegmentData:[@"c" dataUsingEncoding:NSUTF8StringEncoding] forSongId:@"song3" segmentIndex:0];
    
    NSInteger songCount = [manager cachedSongCount];
    if (songCount == 3) {
        NSLog(@"✅ 统计功能: 通过 (3首歌曲)");
    } else {
        NSLog(@"❌ 统计功能: 失败 (期望3，实际%ld)", (long)songCount);
    }
    
    // 清理
    [manager clearAllCache];
    
    NSLog(@"========== 快速验证结束 ==========\n");
    
    [self showAlertWithTitle:@"快速验证完成" message:@"请查看 Xcode 控制台"];
}

+ (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    // 获取当前最顶层的视图控制器
    UIWindow *window = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                window = scene.windows.firstObject;
                break;
            }
        }
    } else {
        window = [UIApplication sharedApplication].keyWindow;
    }
    
    UIViewController *topController = window.rootViewController;
    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [topController presentViewController:alert animated:YES completion:nil];
}

@end
