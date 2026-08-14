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

/// 播放模式
typedef NS_ENUM(NSInteger, XCPlayMode) {
    XCPlayModeSequential = 0,  ///< 顺序播放
    XCPlayModeShuffle    = 1,  ///< 随机播放
};

// 通知常量定义
/// 当前播放歌曲变更通知
extern NSString * const XCMusicPlayerNowPlayingSongDidChangeNotification;
/// 播放状态变更通知
extern NSString * const XCMusicPlayerPlaybackStateDidChangeNotification;
/// 播放模式变更通知
extern NSString * const XCMusicPlayerPlayModeDidChangeNotification;
/// 歌曲 URL 获取失败通知（版权/网络原因），userInfo[@"songName"] 为歌曲名
extern NSString * const XCMusicPlayerURLFetchFailedNotification;

@interface XCMusicPlayerModel : NSObject
/// 全局的音乐播放器
@property (nonatomic, strong) AVPlayer *player;
/// 播放列表
@property (nonatomic, strong) NSMutableArray<XC_YYSongData*>* playerlist;
/// 当前正在播放的歌
@property (nonatomic, strong) XC_YYSongData* nowPlayingSong;
/// 播放状态（YES: 正在播放, NO: 暂停）
@property (nonatomic, assign, readonly) BOOL isPlaying;
/// 播放模式
@property (nonatomic, assign) XCPlayMode playMode;

/// 是否正在加载资源（用于快速打开播放页面时正确显示状态）
@property (nonatomic, assign, readonly) BOOL isLoading;

// Phase 8: 预加载触发标记（内部使用）
@property (nonatomic, assign) BOOL hasTriggeredPreload;

#pragma mark - 评论预加载（Phase 1: 歌曲评论）

/// 当前歌曲的预加载评论数据（仅当前歌曲，切歌时释放）
@property (nonatomic, strong, nullable) id preloadedCommentList;

/// 预加载评论数据（延迟2秒后执行）
- (void)preloadCommentsForSong:(NSString *)songId;

/// 获取预加载的评论数据
- (nullable id)getPreloadedCommentList;

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

#pragma mark - 锁屏信息更新
/// 更新锁屏播放信息
- (void)updateLockScreenInfo;
/// 开始定时更新锁屏进度
- (void)startLockScreenProgressTimer;
/// 停止定时更新锁屏进度
- (void)stopLockScreenProgressTimer;

@end

NS_ASSUME_NONNULL_END
