//
//  AppDelegate.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/11/19.
//

#import "AppDelegate.h"
#import "11. 音频缓存/Tests/XCAudioCacheTestRunner.h"
#import "XCAudioCacheManager.h"
#import <SDWebImage/SDWebImage.h>

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  // Override point for customization after application launch.

  // 配置 SDWebImage 内存缓存限制，防止滑动时内存占用过高
  [self configureSDWebImageCache];
  
  [[XCAudioCacheManager sharedInstance] clearTempCache];
  [[XCAudioCacheManager sharedInstance] clearCompleteCache];

  return YES;
}

/// 配置 SDWebImage 缓存限制
- (void)configureSDWebImageCache {
  SDImageCacheConfig *config = [SDImageCache sharedImageCache].config;
  
  // 内存缓存成本限制：30MB（降低内存占用）
  config.maxMemoryCost = 30 * 1024 * 1024 / 4; // 假设每像素 4 字节
  
  // 内存缓存数量限制：最多 50 张图片
  config.maxMemoryCount = 50;
  
  // 禁用弱引用缓存（避免额外的内存占用）
  config.shouldUseWeakMemoryCache = NO;
  
  // 磁盘缓存 7 天过期
  config.maxDiskAge = 7 * 24 * 60 * 60;
  
  NSLog(@"[AppDelegate] SDWebImage 缓存配置完成：内存限制 30MB，最多 50 张图片");
}


#pragma mark - UISceneSession lifecycle


- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession options:(UISceneConnectionOptions *)options {
  // Called when a new scene session is being created.
  // Use this method to select a configuration to create the new scene with.
  return [[UISceneConfiguration alloc] initWithName:@"Default Configuration" sessionRole:connectingSceneSession.role];
}


- (void)application:(UIApplication *)application didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions {
  // Called when the user discards a scene session.
  // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
}

#pragma mark - Memory Management

/// 收到内存警告时清理图片缓存
- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
  NSLog(@"[AppDelegate] 收到内存警告，清理 SDWebImage 内存缓存");
  [[SDImageCache sharedImageCache] clearMemory];
}

@end
