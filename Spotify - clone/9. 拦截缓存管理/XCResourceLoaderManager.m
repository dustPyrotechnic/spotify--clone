//
//  XCResourceLoaderManager.m
//  Spotify - clone
//

#import "XCResourceLoaderManager.h"

@implementation XCResourceLoaderManager
static XCResourceLoaderManager *instance = nil;

// 使用 +load 方法实现饿汉式单例，在类加载时即创建实例
+ (void)load {
  instance = [[super allocWithZone:NULL] init];
}

+ (instancetype)sharedInstance {
  return instance;
}

// 重写 allocWithZone 阻止通过 alloc 创建新实例
+ (instancetype)allocWithZone:(struct _NSZone *)zone {
  return [self sharedInstance];
}

- (id)copyWithZone:(NSZone *)zone {
  return self;
}

- (id)mutableCopyWithZone:(NSZone *)zone {
  return self;
}

#pragma mark - AVAssetResourceLoaderDelegate
// 拦截 AVPlayer 的资源加载请求，返回 YES 表示接管此请求的处理
- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest {
  NSLog(@"拦截请求: %@", loadingRequest.request.URL);
  return YES;
}

// 请求被取消时的回调，用于清理相关资源
- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
  NSLog(@"取消请求: %@", loadingRequest.request.URL);
}

@end
