//
//  XCMusicPlayerModel.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/12/1.
//

#import <Foundation/Foundation.h>

#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface XCMusicPlayerModel : NSObject
@property (nonatomic, strong) AVPlayer *player;
+ (instancetype)sharedInstance;
- (void)testPlaySpotifySong;
- (void)testPlaySpotifySong2;
- (void)testPlayAppleMusicSong;
@end

NS_ASSUME_NONNULL_END
