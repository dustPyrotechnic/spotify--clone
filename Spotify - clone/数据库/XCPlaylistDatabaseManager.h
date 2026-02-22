//
//  XCPlaylistDatabaseManager.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/22.
//
//  三表规范化设计的 WCDB 数据库管理器
//  表结构：playlists (XC_YYAlbumData) + songs (XC_YYSongData) + playlist_song_relations (XCPlaylistSongRelation)
//  单例模式：饿汉式，+load 时自动初始化数据库

#import <Foundation/Foundation.h>
#import "XC-YYAlbumData.h"
#import "XC-YYSongData.h"
#import "XCPlaylistSongRelation.h"


NS_ASSUME_NONNULL_BEGIN

/// 播放列表排序类型
typedef NS_ENUM(NSInteger, XCPlaylistSortType) {
    XCPlaylistSortByUpdateTime = 0,   // 最近更新（默认）
    XCPlaylistSortByCreateTime = 1,   // 最近创建
    XCPlaylistSortByName       = 2,   // 名称 A-Z
};

@interface XCPlaylistDatabaseManager : NSObject

+ (instancetype)sharedInstance;

#pragma mark - 数据库初始化
/// 建三张表 + 确保内置「喜爱的歌曲」存在
- (void)initializeDatabaseIfNeeded;

#pragma mark - 播放列表 CRUD
/// 获取所有播放列表（喜爱的歌曲固定排首位，其余按 sortType 排序）
- (NSArray<XC_YYAlbumData *> *)getAllPlaylistsSortedBy:(XCPlaylistSortType)sortType;

/// 新建播放列表（自动生成 UUID 作为 albumId）
- (nullable XC_YYAlbumData *)createPlaylistWithName:(NSString *)name;

/// 删除播放列表及其关联记录（isFavorites=YES 时返回 NO，songs 表不受影响）
- (BOOL)deletePlaylistWithId:(NSString *)playlistId;

/// 修改播放列表名称
- (BOOL)renamePlaylist:(NSString *)playlistId newName:(NSString *)name;

/// 更新封面 URL
- (void)updateCoverUrl:(NSString *)coverUrl forPlaylistId:(NSString *)playlistId;

#pragma mark - 歌曲 CRUD
/// 两步查询：先查 relations 按 addedTime 排序，再查 songs 表
/// 返回值可直接赋给 XCALbumDetailModel.playerList
- (NSMutableArray<XC_YYSongData *> *)getSongsOfPlaylist:(NSString *)playlistId;

/// 添加歌曲：insertOrReplace 到 songs 表 + 插入 relation
/// @return YES 成功；NO 该歌曲已在此播放列表中
- (BOOL)addSong:(XC_YYSongData *)song toPlaylist:(NSString *)playlistId;

/// 从播放列表移除歌曲（仅删 relation，songs 表保留）
- (BOOL)removeSong:(NSString *)songId fromPlaylist:(NSString *)playlistId;

/// 检查歌曲是否已在播放列表中
- (BOOL)isSong:(NSString *)songId inPlaylist:(NSString *)playlistId;

/// 获取「喜爱的歌曲」播放列表（albumId 固定为 @"favorites"）
- (nullable XC_YYAlbumData *)getFavoritesPlaylist;

/// 清理孤立歌曲（不被任何 relation 引用的 songs 记录），返回清理数量
- (NSInteger)cleanOrphanSongs;

@end

NS_ASSUME_NONNULL_END
