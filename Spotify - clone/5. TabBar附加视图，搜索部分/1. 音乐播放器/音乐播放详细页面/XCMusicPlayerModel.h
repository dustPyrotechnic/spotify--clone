//
//  XCMusicPlayerModel.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/12/1.
//

#import <Foundation/Foundation.h>

#import <AVFoundation/AVFoundation.h>

#import "XC-YYSongData.h"

NS_ASSUME_NONNULL_BEGIN

@interface XCMusicPlayerModel : NSObject
/// 全局的音乐播放器
@property (nonatomic, strong) AVPlayer *player;
/// 播放列表
@property (nonatomic, strong) NSMutableArray<XC_YYSongData*>* playerlist;
// 当前正在播放的歌
@property (nonatomic, strong) XC_YYSongData* nowPlayingSong;

+ (instancetype)sharedInstance;

// 测试方法
- (void)testPlaySpotifySong;
- (void)testPlaySpotifySong2;
- (void)testPlayAppleMusicSong;
/// 根据id信息直接播放歌曲内容
- (void)playMusicWithId:(NSString *)songId;
@end

NS_ASSUME_NONNULL_END
