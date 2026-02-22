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

@end
