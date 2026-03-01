//
//  XCPersonalModel.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/1.
//

#import "XCPersonalModel.h"
#import "XCPlaylistDatabaseManager.h"

@implementation XCPersonalModel

#pragma mark - 饿汉式单例

static XCPersonalModel *instance = nil;

+ (void)load {
    instance = [[super allocWithZone:NULL] init];
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
        _playlists = [[NSMutableArray alloc] init];
    }
    return self;
}

#pragma mark - 公开方法

- (void)loadPlaylists {
    NSArray *result = [[XCPlaylistDatabaseManager sharedInstance]
                       getAllPlaylistsSortedBy:XCPlaylistSortByUpdateTime];
    self.playlists = result ? [result mutableCopy] : [NSMutableArray array];
}

- (nullable XC_YYAlbumData *)createPlaylistWithName:(NSString *)name {
    XC_YYAlbumData *playlist = [[XCPlaylistDatabaseManager sharedInstance]
                                 createPlaylistWithName:name];
    if (playlist) {
        [self loadPlaylists];
    }
    return playlist;
}

- (BOOL)deletePlaylistAtIndex:(NSInteger)index {
    if (index < 0 || index >= self.playlists.count) {
        return NO;
    }
    
    XC_YYAlbumData *playlist = self.playlists[index];
    
    // 喜爱的歌曲不可删除
    if (playlist.isFavorites) {
        return NO;
    }
    
    // 从数据库删除
    BOOL success = [[XCPlaylistDatabaseManager sharedInstance] deletePlaylistWithId:playlist.albumId];
    
    if (success) {
        // 从数组中移除
        [self.playlists removeObjectAtIndex:index];
    }
    
    return success;
}

@end
