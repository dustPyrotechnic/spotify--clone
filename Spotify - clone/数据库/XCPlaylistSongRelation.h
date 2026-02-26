//
//  XCPlaylistSongRelation.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/22.
//

#import <Foundation/Foundation.h>
#import <WCDBObjc/WCDBObjc.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * 播放列表与歌曲的多对多关联记录
 * 对应数据库里的 `playlist_song_relations` 表
 * 同一首歌可以出现在多个播放列表，
 * 但 songs 表只存一份数据，重复引用靠这个关联表实现
 * - Note: 没有单独的主键字段，(playlistId + songId) 联合唯一
 *   addedTime 决定歌曲在列表内的展示顺序，即按照时间顺序来排列，如果之后有闲心可以加入用户自定义顺序
 */
@interface XCPlaylistSongRelation : NSObject <WCTTableCoding>

/// 播放列表 ID
@property (nonatomic, copy) NSString *playlistId;
/// 歌曲 ID
@property (nonatomic, copy) NSString *songId;
/// 加入时间戳，用于排序
@property (nonatomic, assign) NSInteger addedTime;
/// 手动排序序号（其实并没有什么用笑）
@property (nonatomic, assign) NSInteger sortOrder;

WCDB_PROPERTY(playlistId)
WCDB_PROPERTY(songId)
WCDB_PROPERTY(addedTime)
WCDB_PROPERTY(sortOrder)

@end

NS_ASSUME_NONNULL_END
