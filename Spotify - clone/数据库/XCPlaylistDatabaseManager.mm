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

+ (void)load {
    instance = [[super allocWithZone:NULL] init];
    [instance initializeDatabaseIfNeeded];
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

#pragma mark - 初始化

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

- (void)initializeDatabaseIfNeeded {
    // 建三张表（字段新增时 WCDB 会自动 ALTER TABLE）
    [self.database createTable:@"playlists" withClass:XC_YYAlbumData.class];
    [self.database createTable:@"songs" withClass:XC_YYSongData.class];
    [self.database createTable:@"playlist_song_relations" withClass:XCPlaylistSongRelation.class];

    // 确保内置「喜爱的歌曲」存在
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

#pragma mark - 播放列表 CRUD

- (NSArray<XC_YYAlbumData *> *)getAllPlaylistsSortedBy:(XCPlaylistSortType)sortType {
    // 喜爱的歌曲置顶
    NSArray *favorites = [self.database getObjectsOfClass:XC_YYAlbumData.class
                                                fromTable:@"playlists"
                                                    where:XC_YYAlbumData.isFavorites == 1];

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
    if (favorites) [result addObjectsFromArray:favorites];
    if (others) [result addObjectsFromArray:others];
    return result;
}

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

- (BOOL)deletePlaylistWithId:(NSString *)playlistId {
    XC_YYAlbumData *playlist = [self.database getObjectOfClass:XC_YYAlbumData.class
                                                     fromTable:@"playlists"
                                                         where:XC_YYAlbumData.albumId == playlistId];
    if (!playlist || playlist.isFavorites) return NO;

    // 删关联记录（songs 表保留，其他列表仍可引用）
    [self.database deleteFromTable:@"playlist_song_relations"
                             where:XCPlaylistSongRelation.playlistId == playlistId];
    [self.database deleteFromTable:@"playlists"
                             where:XC_YYAlbumData.albumId == playlistId];
    return YES;
}

- (BOOL)renamePlaylist:(NSString *)playlistId newName:(NSString *)name {
    return [self.database updateTable:@"playlists"
                          setProperty:XC_YYAlbumData.name
                              toValue:name
                                where:XC_YYAlbumData.albumId == playlistId];
}

- (void)updateCoverUrl:(NSString *)coverUrl forPlaylistId:(NSString *)playlistId {
    [self.database updateTable:@"playlists"
                   setProperty:XC_YYAlbumData.coverImgUrl
                       toValue:coverUrl
                         where:XC_YYAlbumData.albumId == playlistId];
}

#pragma mark - 歌曲 CRUD

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

- (BOOL)removeSong:(NSString *)songId fromPlaylist:(NSString *)playlistId {
    BOOL success = [self.database deleteFromTable:@"playlist_song_relations"
                                           where:XCPlaylistSongRelation.playlistId == playlistId
                                                 && XCPlaylistSongRelation.songId == songId];
    if (success) {
        [self updateSongCountForPlaylistId:playlistId];
    }
    return success;
}

- (BOOL)isSong:(NSString *)songId inPlaylist:(NSString *)playlistId {
    XCPlaylistSongRelation *rel =
        [self.database getObjectOfClass:XCPlaylistSongRelation.class
                              fromTable:@"playlist_song_relations"
                                  where:XCPlaylistSongRelation.playlistId == playlistId
                                        && XCPlaylistSongRelation.songId == songId];
    return rel != nil;
}

- (nullable XC_YYAlbumData *)getFavoritesPlaylist {
    return [self.database getObjectOfClass:XC_YYAlbumData.class
                                 fromTable:@"playlists"
                                     where:XC_YYAlbumData.albumId == @"favorites"];
}

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

#pragma mark - 私有辅助方法

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

@end
