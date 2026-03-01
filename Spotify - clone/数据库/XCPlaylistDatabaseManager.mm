//
//  XCPlaylistDatabaseManager.mm
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/22.
//
//  三表规范化设计：
//    "playlists"               → XC_YYAlbumData
//    "songs"                   → XC_YYSongData（每首歌只存一次）
//    "playlist_song_relations" → XCPlaylistSongRelation（多对多关联）

#import "XCPlaylistDatabaseManager.h"
#import <WCDBObjc/WCDBObjc.h>


@interface XCPlaylistDatabaseManager ()
@property (nonatomic, strong) WCTDatabase *database;
@end

@implementation XCPlaylistDatabaseManager

#pragma mark - 饿汉式单例

static XCPlaylistDatabaseManager *instance = nil;

/// +load 阶段触发，保证更早完成数据库初始化
+ (void)load {
  instance = [[super allocWithZone:NULL] init];
  [instance initializeDatabaseIfNeeded];
}

/// 返回全局唯一实例
+ (instancetype)sharedInstance {
  return instance;
}

/// 拦截 alloc，确保单例唯一性
+ (instancetype)allocWithZone:(struct _NSZone *)zone {
  return [self sharedInstance];
}

- (id)copyWithZone:(NSZone *)zone {
  return self;
}

- (id)mutableCopyWithZone:(NSZone *)zone {
  return self;
}

#pragma mark - 初始化

/**
 * 初始化数据库路径
 * 数据库文件放在 Application Support 目录，系统备份会包含它，
 */
- (instancetype)init {
  self = [super init];
  if (self) {
    NSString *appSupportDir = [NSSearchPathForDirectoriesInDomains(
      NSApplicationSupportDirectory, NSUserDomainMask, YES) firstObject];
    NSString *dbPath = [appSupportDir stringByAppendingPathComponent:@"XCPlaylist.db"];
    _database = [[WCTDatabase alloc] initWithPath:dbPath];
  }
  return self;
}

/// 创建三张表，并确保内置 喜爱的 列表存在
- (void)initializeDatabaseIfNeeded {
  // 建三张表
  [self.database createTable:@"playlists" withClass:XC_YYAlbumData.class];
  [self.database createTable:@"songs" withClass:XC_YYSongData.class];
  [self.database createTable:@"playlist_song_relations" withClass:XCPlaylistSongRelation.class];

  // 确保内置 喜爱的歌曲 存在
  XC_YYAlbumData *existing = [self.database getObjectOfClass:XC_YYAlbumData.class
                                                   fromTable:@"playlists"
                                                       where:XC_YYAlbumData.isFavorites == 1];

  if (!existing) {
    XC_YYAlbumData *favorites = [[XC_YYAlbumData alloc] init];
    favorites.albumId = @"favorites";
    favorites.name = @"喜爱的歌曲";
    favorites.isFavorites = YES;
    favorites.songCount = 0;
    NSInteger now = (NSInteger)([[NSDate date] timeIntervalSince1970] * 1000);
    favorites.createTime = now;
    favorites.updateTime = now;
    [self.database insertObject:favorites intoTable:@"playlists"];
  }
}

#pragma mark - 播放列表

/**
 * 获取全量播放列表
 *
 * 喜爱的歌曲 始终排在第一位，其余读取sortType 决定顺序
 * 两次查询结果拼接后返回，调用方可直接展示
 */
- (NSArray<XC_YYAlbumData *> *)getAllPlaylistsSortedBy:(XCPlaylistSortType)sortType {
  // 喜爱的歌曲置顶
  NSArray *favorites = [self.database getObjectsOfClass:XC_YYAlbumData.class
                                              fromTable:@"playlists"
                                                  where:XC_YYAlbumData.isFavorites == 1];



//  NSLog(@"%@",favorites);
  // 其余列表按排序类型
  NSArray *others;
  switch (sortType) {
    case XCPlaylistSortByCreateTime:
      others = [self.database getObjectsOfClass:XC_YYAlbumData.class
                                      fromTable:@"playlists"
                                          where:XC_YYAlbumData.isFavorites == 0
                                         orders:XC_YYAlbumData.createTime.asOrder(WCTOrderedDescending)];
      break;
    case XCPlaylistSortByName:
      others = [self.database getObjectsOfClass:XC_YYAlbumData.class
                                      fromTable:@"playlists"
                                          where:XC_YYAlbumData.isFavorites == 0
                                         orders:XC_YYAlbumData.name.asOrder(WCTOrderedAscending)];
      break;
    default: // XCPlaylistSortByUpdateTime
      others = [self.database getObjectsOfClass:XC_YYAlbumData.class
                                      fromTable:@"playlists"
                                          where:XC_YYAlbumData.isFavorites == 0
                                         orders:XC_YYAlbumData.updateTime.asOrder(WCTOrderedDescending)];
      break;
  }

  NSMutableArray *result = [NSMutableArray array];
  NSLog(@"进入判断");
  if (favorites) {
    [result addObjectsFromArray:favorites];
  }
  if (others) {
    [result addObjectsFromArray:others];
  }

  return result;
}

/// 新建播放列表，albumId 用 UUID 自动生成
- (nullable XC_YYAlbumData *)createPlaylistWithName:(NSString *)name {
  XC_YYAlbumData *playlist = [[XC_YYAlbumData alloc] init];
  playlist.albumId = [[NSUUID UUID] UUIDString];
  playlist.name = name;
  playlist.isFavorites = NO;
  playlist.songCount = 0;
  NSInteger now = (NSInteger)([[NSDate date] timeIntervalSince1970] * 1000);
  playlist.createTime = now;
  playlist.updateTime = now;

  BOOL success = [self.database insertObject:playlist intoTable:@"playlists"];
  return success ? playlist : nil;
}

/**
 * 删除播放列表
 *
 * 内置喜爱的歌曲不允许删除，会直接返回 NO。
 * 删除时只清关联记录，songs 表里的歌曲数据保留，
 * 其他播放列表仍可继续引用同一首歌。
 */
- (BOOL)deletePlaylistWithId:(NSString *)playlistId {
  XC_YYAlbumData *playlist = [self.database getObjectOfClass:XC_YYAlbumData.class
                                                   fromTable:@"playlists"
                                                       where:XC_YYAlbumData.albumId == playlistId];
  if (!playlist || playlist.isFavorites) return NO;

  // 删关联记录 songs 表保留，其他列表仍可引用
  [self.database deleteFromTable:@"playlist_song_relations"
                           where:XCPlaylistSongRelation.playlistId == playlistId];
  [self.database deleteFromTable:@"playlists"
                           where:XC_YYAlbumData.albumId == playlistId];
  return YES;
}

/// 改名，直接 update name 字段
- (BOOL)renamePlaylist:(NSString *)playlistId newName:(NSString *)name {
  return [self.database updateTable:@"playlists"
                        setProperty:XC_YYAlbumData.name
                            toValue:name
                              where:XC_YYAlbumData.albumId == playlistId];
}

/// 更新封面 URL
- (void)updateCoverUrl:(NSString *)coverUrl forPlaylistId:(NSString *)playlistId {
  [self.database updateTable:@"playlists"
                 setProperty:XC_YYAlbumData.coverImgUrl
                     toValue:coverUrl
                       where:XC_YYAlbumData.albumId == playlistId];
}

#pragma mark - 歌曲

/**
 * 获取播放列表内的所有歌曲
 *
 * 两步查询：先从 relations 拿到有序的 songId 列表，
 * 再逐个去 songs 表查完整歌曲数据，保证顺序按加入时间升序。
 */
- (NSMutableArray<XC_YYSongData *> *)getSongsOfPlaylist:(NSString *)playlistId {
  // Step 1: 查 relations，按加入时间升序
  NSArray *relations = [self.database getObjectsOfClass:XCPlaylistSongRelation.class
                                              fromTable:@"playlist_song_relations"
                                                  where:XCPlaylistSongRelation.playlistId == playlistId
                                                 orders:XCPlaylistSongRelation.addedTime.asOrder()];

  NSMutableArray<XC_YYSongData *> *songs = [NSMutableArray array];
  // Step 2: 根据每个 relation 的 songId 查 songs 表
  for (XCPlaylistSongRelation *rel in relations) {
    XC_YYSongData *song = [self.database getObjectOfClass:XC_YYSongData.class
                                                fromTable:@"songs"
                                                    where:XC_YYSongData.songId == rel.songId];
    if (song) {
      [songs addObject:song];
    }
  }
  return songs;
}

/**
 * 添加歌曲到播放列表
 *
 * 若歌曲已在该列表中则直接返回 NO（幂等保护）。
 * 歌曲数据用 insertOrReplace，保证 songs 表每首歌只存一份。
 * 成功后同步更新歌曲计数和封面。
 */
- (BOOL)addSong:(XC_YYSongData *)song toPlaylist:(NSString *)playlistId {
  // 检查是否已存在关联
  XCPlaylistSongRelation *existing =
    [self.database getObjectOfClass:XCPlaylistSongRelation.class
                          fromTable:@"playlist_song_relations"
                              where:XCPlaylistSongRelation.playlistId == playlistId
                                    && XCPlaylistSongRelation.songId == song.songId];
  if (existing) return NO;

  // insertOrReplace 到 songs 表（同一首歌只存一次）
  [self.database insertOrReplaceObject:song intoTable:@"songs"];

  // 创建关联记录
  XCPlaylistSongRelation *rel = [[XCPlaylistSongRelation alloc] init];
  rel.playlistId = playlistId;
  rel.songId = song.songId;
  rel.addedTime = (NSInteger)([[NSDate date] timeIntervalSince1970] * 1000);
  rel.sortOrder = 0;

  BOOL success = [self.database insertObject:rel intoTable:@"playlist_song_relations"];
  if (success) {
    [self updateSongCountForPlaylistId:playlistId];
    [self updateCoverIfNeededForPlaylistId:playlistId withSongImgUrl:song.mainIma];
  }
  return success;
}

/// 从播放列表移除歌曲，仅删 relation，songs 表不动
- (BOOL)removeSong:(NSString *)songId fromPlaylist:(NSString *)playlistId {
  BOOL success = [self.database deleteFromTable:@"playlist_song_relations"
                                         where:XCPlaylistSongRelation.playlistId == playlistId
                                               && XCPlaylistSongRelation.songId == songId];
  if (success) {
    [self updateSongCountForPlaylistId:playlistId];
  }
  return success;
}





/// 查 relation 是否存在来判断歌曲是否已在列表里
- (BOOL)isSong:(NSString *)songId inPlaylist:(NSString *)playlistId {
  XCPlaylistSongRelation *rel =
    [self.database getObjectOfClass:XCPlaylistSongRelation.class
                          fromTable:@"playlist_song_relations"
                              where:XCPlaylistSongRelation.playlistId == playlistId
                                    && XCPlaylistSongRelation.songId == songId];
  return rel != nil;
}


/// 直接按固定 albumId "favorites" 查内置列表
- (nullable XC_YYAlbumData *)getFavoritesPlaylist {
  return [self.database getObjectOfClass:XC_YYAlbumData.class
                               fromTable:@"playlists"
                                   where:XC_YYAlbumData.albumId == @"favorites"];
}
// 清理方法，清理表里的数据，在删除一个播放列表的时候使用，防止数据溢出来
/**
 * 清理孤立歌曲
 *
 * 找出 songs 表中没有被任何 relation 引用的记录并删除，释放空间。
 * 正常使用一般不会产生孤立歌曲，这个方法作为维护手段备用。
 */
- (NSInteger)cleanOrphanSongs {
  // 获取所有被任意 relation 引用的 songId
  NSArray *relations = [self.database getObjectsOfClass:XCPlaylistSongRelation.class
                                              fromTable:@"playlist_song_relations"];
  NSMutableSet *referencedIds = [NSMutableSet set];
  for (XCPlaylistSongRelation *rel in relations) {
    [referencedIds addObject:rel.songId];
  }

  // 获取 songs 表所有歌曲
  NSArray *allSongs = [self.database getObjectsOfClass:XC_YYSongData.class
                                             fromTable:@"songs"];
  NSInteger cleaned = 0;
  for (XC_YYSongData *song in allSongs) {
    if (![referencedIds containsObject:song.songId]) {
      [self.database deleteFromTable:@"songs"
                              where:XC_YYSongData.songId == song.songId];
      cleaned++;
    }
  }
  NSLog(@"[PlaylistDB] Cleaned %ld orphan songs", (long)cleaned);
  return cleaned;
}

#pragma mark - 辅助方法

/// 同步更新播放列表的歌曲计数和修改时间戳
- (void)updateSongCountForPlaylistId:(NSString *)playlistId {
  NSArray *relations = [self.database getObjectsOfClass:XCPlaylistSongRelation.class
                                              fromTable:@"playlist_song_relations"
                                                  where:XCPlaylistSongRelation.playlistId == playlistId];
  NSInteger count = relations.count;
  NSInteger now = (NSInteger)([[NSDate date] timeIntervalSince1970] * 1000);

  [self.database updateTable:@"playlists"
                 setProperty:XC_YYAlbumData.songCount
                     toValue:@(count)
                       where:XC_YYAlbumData.albumId == playlistId];
  [self.database updateTable:@"playlists"
                 setProperty:XC_YYAlbumData.updateTime
                     toValue:@(now)
                       where:XC_YYAlbumData.albumId == playlistId];
}

// 更新封面图片
/// 若列表封面为空，用第一首歌的封面顶上去
- (void)updateCoverIfNeededForPlaylistId:(NSString *)playlistId withSongImgUrl:(NSString *)imgUrl {
  if (!imgUrl || imgUrl.length == 0) return;

  XC_YYAlbumData *playlist = [self.database getObjectOfClass:XC_YYAlbumData.class
                                                   fromTable:@"playlists"
                                                       where:XC_YYAlbumData.albumId == playlistId];
  if (!playlist.coverImgUrl || playlist.coverImgUrl.length == 0) {
    [self.database updateTable:@"playlists"
                   setProperty:XC_YYAlbumData.coverImgUrl
                       toValue:imgUrl
                         where:XC_YYAlbumData.albumId == playlistId];
  }
}

// 获取播放列表第一首歌的封面URL
- (nullable NSString *)getFirstSongCoverOfPlaylist:(NSString *)playlistId {
    // 查询该播放列表中 addedTime 最早的一首歌
    NSArray *relations = [self.database getObjectsOfClass:XCPlaylistSongRelation.class
                                                fromTable:@"playlist_song_relations"
                                                    where:XCPlaylistSongRelation.playlistId == playlistId
                                                   orders:XCPlaylistSongRelation.addedTime.asOrder(WCTOrderedAscending)];
    
    if (relations.count == 0) return nil;
    
    XCPlaylistSongRelation *firstRelation = relations.firstObject;
    
    // 查询歌曲的封面
    XC_YYSongData *song = [self.database getObjectOfClass:XC_YYSongData.class
                                                fromTable:@"songs"
                                                    where:XC_YYSongData.songId == firstRelation.songId];
    
    return song.mainIma;
}

@end
