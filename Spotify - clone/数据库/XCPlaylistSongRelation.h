//
//  XCPlaylistSongRelation.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/22.
//
//  播放列表与歌曲的多对多关联表模型
//  职责：存储 playlistId + songId + addedTime + sortOrder
//  三表设计：同一首歌加入多个播放列表时，songs 表只存一条，关联存此表

#import <Foundation/Foundation.h>
#import <WCDBObjc/WCDBObjc.h>

NS_ASSUME_NONNULL_BEGIN

@interface XCPlaylistSongRelation : NSObject <WCTTableCoding>

/// 播放列表 ID（外键 → playlists.albumId）
@property (nonatomic, copy) NSString *playlistId;
/// 歌曲 ID（外键 → songs.songId）
@property (nonatomic, copy) NSString *songId;
/// 加入时间戳，Unix 毫秒，用于排序
@property (nonatomic, assign) NSInteger addedTime;
/// 手动排序序号（预留，默认 0）
@property (nonatomic, assign) NSInteger sortOrder;

WCDB_PROPERTY(playlistId)
WCDB_PROPERTY(songId)
WCDB_PROPERTY(addedTime)
WCDB_PROPERTY(sortOrder)

@end

NS_ASSUME_NONNULL_END
