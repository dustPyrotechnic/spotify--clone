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
/// 当前正在播放的歌
@property (nonatomic, strong) XC_YYSongData* nowPlayingSong;

+ (instancetype)sharedInstance;

// 测试方法
- (void)testPlaySpotifySong;
- (void)testPlaySpotifySong2;
- (void)testPlayAppleMusicSong;

#pragma mark - 播放控制
/// 根据id信息直接播放歌曲内容（带内存缓存）
- (void)playMusicWithId:(NSString *)songId;
/// 播放下一首
- (void)playNextSong;
/// 播放上一首
- (void)playPreviousSong;
/// 暂停播放
- (void)pauseMusic;
/// 继续播放
- (void)playMusic;

@end

NS_ASSUME_NONNULL_END
