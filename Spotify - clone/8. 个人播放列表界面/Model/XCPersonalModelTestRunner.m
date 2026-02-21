//
//  XCPersonalModelTestRunner.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/20.
//

#import "XCPersonalModelTestRunner.h"
#import "XCPersonalModelTest.h"

static NSDictionary* lastResults = nil;

@implementation XCPersonalModelTestRunner

+ (void)runTests {
    NSLog(@"\n");
    NSLog(@"╔══════════════════════════════════════════════════════════╗");
    NSLog(@"║                                                          ║");
    NSLog(@"║       XCPersonalModel Phase 1 测试启动                   ║");
    NSLog(@"║       Model 层单元测试                                   ║");
    NSLog(@"║                                                          ║");
    NSLog(@"╚══════════════════════════════════════════════════════════╝");
    NSLog(@"\n");
    
    [XCPersonalModelTest runAllTests];
    
    lastResults = [XCPersonalModelTest testStatistics];
}

+ (void)runTestsAndShowResultInViewController:(UIViewController*)viewController {
    // 先运行测试
    [self runTests];
    
    // 构建结果消息
    NSDictionary* stats = lastResults;
    NSInteger total = [stats[@"total"] integerValue];
    NSInteger passed = [stats[@"passed"] integerValue];
    NSInteger failed = [stats[@"failed"] integerValue];
    double passRate = [stats[@"passRate"] doubleValue];
    
    NSString* title = failed == 0 ? @"✅ Phase 1 测试通过" : @"⚠️ Phase 1 测试有失败";
    
    NSString* message = [NSString stringWithFormat:
                         @"总测试: %ld\n"
                         @"通过: %ld\n"
                         @"失败: %ld\n"
                         @"通过率: %.1f%%",
                         (long)total, (long)passed, (long)failed, passRate];
    
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    
    [viewController presentViewController:alert animated:YES completion:nil];
}

+ (NSDictionary*)lastTestResults {
    return lastResults;
}

@end
