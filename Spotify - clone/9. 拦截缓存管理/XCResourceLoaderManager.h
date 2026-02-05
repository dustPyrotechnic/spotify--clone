//
//  XCResourceLoaderManager.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/5.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface XCResourceLoaderManager : NSObject <AVAssetResourceLoaderDelegate>
+ (instancetype)sharedInstance;
@end

NS_ASSUME_NONNULL_END
