//
//  XCResourceLoaderManager.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/5.
//

#import "XCResourceLoaderManager.h"

@implementation XCResourceLoaderManager
static XCResourceLoaderManager *instance = nil;
#pragma mark -单例模式
// 在 +load 方法中创建单例实例
+ (void)load {
  instance = [[super allocWithZone:NULL] init];
}
// 饿汉模式的全局访问点
+ (instancetype)sharedInstance {
  return instance;
}
// 重写 allocWithZone: 方法，确保无法通过 alloc 直接创建新实例
+ (instancetype)allocWithZone:(struct _NSZone *)zone {
  // 直接返回已经创建好的单例实例
  return [self sharedInstance];
}
// 重写 copy 和 mutableCopy 方法，防止实例被复制
- (id)copyWithZone:(NSZone *)zone {
  return self;
}
- (id)mutableCopyWithZone:(NSZone *)zone {
  return self;
}
#pragma mark -AVAssetResourceLoaderDelegate
- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest {
  NSLog(@"拦截到请求,url为： %@", loadingRequest.request.URL);

  // 返回NO,播放器报错
  return YES;
}

- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest {

}

@end
