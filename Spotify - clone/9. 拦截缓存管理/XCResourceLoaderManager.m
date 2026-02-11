//
//  XCResourceLoaderManager.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/5.
//

#import "XCResourceLoaderManager.h"

@implementation XCResourceLoaderManager
static XCResourceLoaderManager *instance = nil;

+ (void)load {
  instance = [[super allocWithZone:NULL] init];
}

+ (instancetype)sharedInstance {
  return instance;
}

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
- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest {
  NSLog(@"拦截请求: %@", loadingRequest.request.URL);
  return YES;
}

- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
  NSLog(@"取消请求: %@", loadingRequest.request.URL);
}

@end
