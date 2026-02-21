//
//  XCPersonalModel.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/1.
//

#import "XCPersonalModel.h"
#import "XC-YYAlbumData.h"
#import "XC-YYSongData.h"

#pragma mark - 通知常量定义
NSString* const XCPlaylistDataChangedNotification = @"XCPlaylistDataChangedNotification";
NSString* const XCPlaylistSearchCompletedNotification = @"XCPlaylistSearchCompletedNotification";
NSString* const XCPlaylistCreatedNotification = @"XCPlaylistCreatedNotification";
NSString* const XCPlaylistDeletedNotification = @"XCPlaylistDeletedNotification";

#pragma mark - 存储常量
static NSString* const kStorageKeyPlaylists = @"XCPersonalModel_Playlists";
static NSString* const kStorageKeyPlaylistInfos = @"XCPersonalModel_PlaylistInfos";
static NSString* const kStorageKeySortType = @"XCPersonalModel_SortType";

@interface XCPersonalModel ()

#pragma mark - 内部属性（可读写）
@property (nonatomic, strong, readwrite) NSMutableArray<XC_YYAlbumData*>* allPlaylists;
@property (nonatomic, strong, readwrite) NSMutableArray<XC_YYAlbumData*>* filteredPlaylists;
@property (nonatomic, strong, readwrite) NSMutableDictionary<NSString*, XCLocalPlaylistInfo*>* playlistInfos;
@property (nonatomic, assign, readwrite) XCPlaylistSortType currentSortType;
@property (nonatomic, copy, readwrite, nullable) NSString* currentSearchText;

#pragma mark - 内部队列
/// 数据操作队列（并发队列，用于文件IO）
@property (nonatomic, strong) dispatch_queue_t dataQueue;

@end

@implementation XCPersonalModel

#pragma mark - 单例模式
static XCPersonalModel* instance = nil;

+ (void)load {
    instance = [[super allocWithZone:NULL] init];
}

+ (instancetype)sharedInstance {
    return instance;
}

+ (instancetype)allocWithZone:(struct _NSZone*)zone {
    return [self sharedInstance];
}

- (id)copyWithZone:(NSZone*)zone {
    return self;
}

- (id)mutableCopyWithZone:(NSZone*)zone {
    return self;
}

#pragma mark - 初始化
- (instancetype)init {
    self = [super init];
    if (self) {
        _allPlaylists = [[NSMutableArray alloc] init];
        _filteredPlaylists = [[NSMutableArray alloc] init];
        _playlistInfos = [[NSMutableDictionary alloc] init];
        _currentSortType = XCPlaylistSortTypeCreateDateDesc;
        _currentSearchText = nil;
        _dataQueue = dispatch_queue_create("com.spotifyclone.personalmodel", DISPATCH_QUEUE_CONCURRENT);
        
        // 加载保存的排序偏好
        NSInteger savedSortType = [[NSUserDefaults standardUserDefaults] integerForKey:kStorageKeySortType];
        _currentSortType = (XCPlaylistSortType)savedSortType;
    }
    return self;
}

#pragma mark - 数据加载/保存
- (void)loadPlaylistsFromLocalWithCompletion:(nullable void(^)(BOOL success))completion {
    dispatch_async(self.dataQueue, ^{
        BOOL success = NO;
        
        @try {
            // 从 UserDefaults 加载播放列表数据
            NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
            NSData* playlistsData = [defaults objectForKey:kStorageKeyPlaylists];
            NSData* infosData = [defaults objectForKey:kStorageKeyPlaylistInfos];
            
            // 解码播放列表数据
            if (playlistsData) {
                NSArray* decodedArray = [NSKeyedUnarchiver unarchivedObjectOfClasses:[NSSet setWithObjects:
                                                                                    [NSArray class],
                                                                                    [XC_YYAlbumData class],
                                                                                    [NSString class],
                                                                                    [NSNumber class],
                                                                                    nil]
                                                                            fromData:playlistsData
                                                                               error:nil];
                if (decodedArray) {
                    self.allPlaylists = [decodedArray mutableCopy];
                }
            }
            
            // 解码扩展信息数据
            if (infosData) {
                NSDictionary* decodedDict = [NSKeyedUnarchiver unarchivedObjectOfClasses:[NSSet setWithObjects:
                                                                                        [NSDictionary class],
                                                                                        [XCLocalPlaylistInfo class],
                                                                                        [NSString class],
                                                                                        nil]
                                                                                fromData:infosData
                                                                                   error:nil];
                if (decodedDict) {
                    self.playlistInfos = [decodedDict mutableCopy];
                }
            }
            
            // 如果没有数据，创建默认播放列表
            if (self.allPlaylists.count == 0) {
                [self createDefaultPlaylists];
            }
            
            // 应用当前搜索和排序
            [self applyFilterAndSort];
            
            success = YES;
            NSLog(@"[XCPersonalModel] 数据加载成功，共 %lu 个播放列表", (unsigned long)self.allPlaylists.count);
        }
        @catch (NSException* exception) {
            NSLog(@"[XCPersonalModel] 数据加载失败: %@", exception.reason);
            success = NO;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            // 发送数据变更通知
            [[NSNotificationCenter defaultCenter] postNotificationName:XCPlaylistDataChangedNotification
                                                                object:self];
            if (completion) {
                completion(success);
            }
        });
    });
}

- (void)savePlaylistsToLocalWithCompletion:(nullable void(^)(BOOL success))completion {
    dispatch_async(self.dataQueue, ^{
        BOOL success = NO;
        
        @try {
            NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
            
            // 编码播放列表数据
            NSData* playlistsData = [NSKeyedArchiver archivedDataWithRootObject:self.allPlaylists
                                                          requiringSecureCoding:YES
                                                                          error:nil];
            // 编码扩展信息数据
            NSData* infosData = [NSKeyedArchiver archivedDataWithRootObject:self.playlistInfos
                                                      requiringSecureCoding:YES
                                                                      error:nil];
            
            if (playlistsData) {
                [defaults setObject:playlistsData forKey:kStorageKeyPlaylists];
            }
            if (infosData) {
                [defaults setObject:infosData forKey:kStorageKeyPlaylistInfos];
            }
            
            // 保存排序偏好
            [defaults setInteger:self.currentSortType forKey:kStorageKeySortType];
            
            [defaults synchronize];
            success = YES;
            NSLog(@"[XCPersonalModel] 数据保存成功");
        }
        @catch (NSException* exception) {
            NSLog(@"[XCPersonalModel] 数据保存失败: %@", exception.reason);
            success = NO;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(success);
            }
        });
    });
}

#pragma mark - 默认播放列表
- (void)createDefaultPlaylists {
    // 创建"喜爱的歌曲"默认播放列表
    XC_YYAlbumData* lovePlaylist = [[XC_YYAlbumData alloc] init];
    lovePlaylist.albumId = @"default_loved_songs";
    lovePlaylist.name = @"喜爱的歌曲";
    lovePlaylist.artistName = @"默认";
    
    [self.allPlaylists addObject:lovePlaylist];
    
    // 创建对应的扩展信息
    XCLocalPlaylistInfo* info = [XCLocalPlaylistInfo infoWithPlaylistId:lovePlaylist.albumId
                                                                   name:lovePlaylist.name];
    info.playlistType = XCPlaylistTypeSystem;
    info.isPinned = YES;
    self.playlistInfos[lovePlaylist.albumId] = info;
    
    NSLog(@"[XCPersonalModel] 创建默认播放列表");
}

#pragma mark - 播放列表 CRUD 操作
- (void)createPlaylistWithName:(NSString*)name
                    completion:(nullable void(^)(BOOL success, NSString* _Nullable playlistId))completion {
    if (!name || name.length == 0) {
        NSLog(@"[XCPersonalModel] 创建失败：名称为空");
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, nil);
            });
        }
        return;
    }
    
    // 检查是否已存在相同名称的播放列表
    for (XC_YYAlbumData* playlist in self.allPlaylists) {
        if ([playlist.name isEqualToString:name]) {
            NSLog(@"[XCPersonalModel] 创建失败：名称已存在");
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(NO, nil);
                });
            }
            return;
        }
    }
    
    dispatch_async(self.dataQueue, ^{
        // 生成唯一ID
        NSString* playlistId = [NSString stringWithFormat:@"user_%@_%ld",
                                [[NSUUID UUID] UUIDString],
                                (long)[[NSDate date] timeIntervalSince1970]];
        
        // 创建播放列表对象
        XC_YYAlbumData* playlist = [[XC_YYAlbumData alloc] init];
        playlist.albumId = playlistId;
        playlist.name = name;
        playlist.artistName = @"红尘一笑"; // 当前用户
        
        // 创建扩展信息
        XCLocalPlaylistInfo* info = [XCLocalPlaylistInfo infoWithPlaylistId:playlistId name:name];
        info.playlistType = XCPlaylistTypeUserCreated;
        
        // 添加到数据集合
        [self.allPlaylists insertObject:playlist atIndex:0]; // 插入到头部
        self.playlistInfos[playlistId] = info;
        
        // 应用当前搜索和排序
        [self applyFilterAndSort];
        
        // 保存到本地
        [self savePlaylistsToLocalWithCompletion:nil];
        
        NSLog(@"[XCPersonalModel] 创建播放列表成功: %@ (%@)", name, playlistId);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            // 发送通知
            [[NSNotificationCenter defaultCenter] postNotificationName:XCPlaylistDataChangedNotification
                                                                object:self];
            [[NSNotificationCenter defaultCenter] postNotificationName:XCPlaylistCreatedNotification
                                                                object:self
                                                              userInfo:@{@"playlistId": playlistId,
                                                                         @"playlistName": name}];
            if (completion) {
                completion(YES, playlistId);
            }
        });
    });
}

- (void)deletePlaylistWithId:(NSString*)playlistId
                  completion:(nullable void(^)(BOOL success))completion {
    if (!playlistId || playlistId.length == 0) {
        if (completion) {
            completion(NO);
        }
        return;
    }
    
    dispatch_async(self.dataQueue, ^{
        BOOL found = NO;
        
        // 查找并移除
        for (NSInteger i = 0; i < self.allPlaylists.count; i++) {
            XC_YYAlbumData* playlist = self.allPlaylists[i];
            if ([playlist.albumId isEqualToString:playlistId]) {
                // 不能删除系统默认播放列表
                XCLocalPlaylistInfo* info = self.playlistInfos[playlistId];
                if (info && info.playlistType == XCPlaylistTypeSystem) {
                    NSLog(@"[XCPersonalModel] 删除失败：不能删除系统播放列表");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (completion) {
                            completion(NO);
                        }
                    });
                    return;
                }
                
                [self.allPlaylists removeObjectAtIndex:i];
                [self.playlistInfos removeObjectForKey:playlistId];
                found = YES;
                break;
            }
        }
        
        if (found) {
            // 应用当前搜索和排序
            [self applyFilterAndSort];
            
            // 保存到本地
            [self savePlaylistsToLocalWithCompletion:nil];
            
            NSLog(@"[XCPersonalModel] 删除播放列表成功: %@", playlistId);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:XCPlaylistDataChangedNotification
                                                                    object:self];
                [[NSNotificationCenter defaultCenter] postNotificationName:XCPlaylistDeletedNotification
                                                                    object:self
                                                                  userInfo:@{@"playlistId": playlistId}];
                if (completion) {
                    completion(YES);
                }
            });
        } else {
            NSLog(@"[XCPersonalModel] 删除失败：播放列表不存在");
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) {
                    completion(NO);
                }
            });
        }
    });
}

- (void)updatePlaylistWithId:(NSString*)playlistId
                        name:(NSString*)name
                  completion:(nullable void(^)(BOOL success))completion {
    if (!playlistId || !name || name.length == 0) {
        if (completion) {
            completion(NO);
        }
        return;
    }
    
    dispatch_async(self.dataQueue, ^{
        BOOL found = NO;
        
        for (XC_YYAlbumData* playlist in self.allPlaylists) {
            if ([playlist.albumId isEqualToString:playlistId]) {
                playlist.name = name;
                
                // 更新扩展信息
                XCLocalPlaylistInfo* info = self.playlistInfos[playlistId];
                if (info) {
                    info.playlistName = name;
                    info.modifyDate = [NSDate date];
                }
                
                found = YES;
                break;
            }
        }
        
        if (found) {
            [self applyFilterAndSort];
            [self savePlaylistsToLocalWithCompletion:nil];
            
            NSLog(@"[XCPersonalModel] 更新播放列表成功: %@ -> %@", playlistId, name);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:XCPlaylistDataChangedNotification
                                                                    object:self];
                if (completion) {
                    completion(YES);
                }
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) {
                    completion(NO);
                }
            });
        }
    });
}

- (void)updatePlaylistSongCount:(NSString*)playlistId
                      songCount:(NSInteger)songCount {
    if (!playlistId) return;
    
    XCLocalPlaylistInfo* info = self.playlistInfos[playlistId];
    if (info) {
        info.songCount = songCount;
        info.modifyDate = [NSDate date];
        [self savePlaylistsToLocalWithCompletion:nil];
    }
}

#pragma mark - 搜索/排序/筛选
- (void)filterPlaylistsWithSearchText:(nullable NSString*)searchText {
    self.currentSearchText = searchText;
    [self applyFilterAndSort];
    
    // 发送搜索完成通知
    [[NSNotificationCenter defaultCenter] postNotificationName:XCPlaylistSearchCompletedNotification
                                                        object:self
                                                      userInfo:@{@"searchText": searchText ?: @"",
                                                                 @"resultCount": @(self.filteredPlaylists.count)}];
}

- (void)sortPlaylistsByType:(XCPlaylistSortType)sortType {
    self.currentSortType = sortType;
    
    // 保存排序偏好
    [[NSUserDefaults standardUserDefaults] setInteger:sortType forKey:kStorageKeySortType];
    
    [self applyFilterAndSort];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:XCPlaylistDataChangedNotification
                                                        object:self];
}

- (void)clearFilter {
    self.currentSearchText = nil;
    [self applyFilterAndSort];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:XCPlaylistDataChangedNotification
                                                        object:self];
}

- (void)applyFilterAndSort {
    // 1. 应用搜索过滤
    if (self.currentSearchText && self.currentSearchText.length > 0) {
        NSPredicate* predicate = [NSPredicate predicateWithFormat:@"name CONTAINS[cd] %@",
                                  self.currentSearchText];
        NSArray* filtered = [self.allPlaylists filteredArrayUsingPredicate:predicate];
        self.filteredPlaylists = [filtered mutableCopy];
    } else {
        self.filteredPlaylists = [self.allPlaylists mutableCopy];
    }
    
    // 2. 应用排序
    [self applyCurrentSort];
}

- (void)applyCurrentSort {
    switch (self.currentSortType) {
        case XCPlaylistSortTypeCreateDateDesc: {
            // 按创建时间倒序（新的在前）
            [self.filteredPlaylists sortUsingComparator:^NSComparisonResult(XC_YYAlbumData* obj1, XC_YYAlbumData* obj2) {
                XCLocalPlaylistInfo* info1 = self.playlistInfos[obj1.albumId];
                XCLocalPlaylistInfo* info2 = self.playlistInfos[obj2.albumId];
                return [info2.createDate compare:info1.createDate];
            }];
            break;
        }
            
        case XCPlaylistSortTypeModifyDateDesc: {
            // 按修改时间倒序
            [self.filteredPlaylists sortUsingComparator:^NSComparisonResult(XC_YYAlbumData* obj1, XC_YYAlbumData* obj2) {
                XCLocalPlaylistInfo* info1 = self.playlistInfos[obj1.albumId];
                XCLocalPlaylistInfo* info2 = self.playlistInfos[obj2.albumId];
                return [info2.modifyDate compare:info1.modifyDate];
            }];
            break;
        }
            
        case XCPlaylistSortTypeNameAsc: {
            // 按名称升序
            [self.filteredPlaylists sortUsingComparator:^NSComparisonResult(XC_YYAlbumData* obj1, XC_YYAlbumData* obj2) {
                return [obj1.name compare:obj2.name options:NSCaseInsensitiveSearch];
            }];
            break;
        }
            
        case XCPlaylistSortTypeNameDesc: {
            // 按名称降序
            [self.filteredPlaylists sortUsingComparator:^NSComparisonResult(XC_YYAlbumData* obj1, XC_YYAlbumData* obj2) {
                return [obj2.name compare:obj1.name options:NSCaseInsensitiveSearch];
            }];
            break;
        }
            
        case XCPlaylistSortTypeSongCountDesc: {
            // 按歌曲数量降序
            [self.filteredPlaylists sortUsingComparator:^NSComparisonResult(XC_YYAlbumData* obj1, XC_YYAlbumData* obj2) {
                XCLocalPlaylistInfo* info1 = self.playlistInfos[obj1.albumId];
                XCLocalPlaylistInfo* info2 = self.playlistInfos[obj2.albumId];
                NSInteger count1 = info1 ? info1.songCount : 0;
                NSInteger count2 = info2 ? info2.songCount : 0;
                if (count1 < count2) return NSOrderedDescending;
                if (count1 > count2) return NSOrderedAscending;
                return NSOrderedSame;
            }];
            break;
        }
    }
}

#pragma mark - 扩展信息查询
- (nullable XCLocalPlaylistInfo*)infoForPlaylist:(NSString*)playlistId {
    if (!playlistId) return nil;
    return self.playlistInfos[playlistId];
}

- (NSInteger)songCountForPlaylist:(NSString*)playlistId {
    if (!playlistId) return 0;
    XCLocalPlaylistInfo* info = self.playlistInfos[playlistId];
    return info ? info.songCount : 0;
}

#pragma mark - 测试辅助方法
- (void)clearAllDataForTesting {
    dispatch_async(self.dataQueue, ^{
        [self.allPlaylists removeAllObjects];
        [self.filteredPlaylists removeAllObjects];
        [self.playlistInfos removeAllObjects];
        
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kStorageKeyPlaylists];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kStorageKeyPlaylistInfos];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:XCPlaylistDataChangedNotification
                                                                object:self];
        });
    });
}

- (void)addTestDataForTesting:(NSInteger)count {
    dispatch_async(self.dataQueue, ^{
        for (NSInteger i = 0; i < count; i++) {
            NSString* name = [NSString stringWithFormat:@"测试播放列表 %ld", (long)(i + 1)];
            
            NSString* playlistId = [NSString stringWithFormat:@"test_%@_%ld",
                                    [[NSUUID UUID] UUIDString],
                                    (long)[[NSDate date] timeIntervalSince1970]];
            
            XC_YYAlbumData* playlist = [[XC_YYAlbumData alloc] init];
            playlist.albumId = playlistId;
            playlist.name = name;
            playlist.artistName = @"红尘一笑";
            
            XCLocalPlaylistInfo* info = [XCLocalPlaylistInfo infoWithPlaylistId:playlistId name:name];
            info.playlistType = XCPlaylistTypeUserCreated;
            info.songCount = arc4random_uniform(100); // 随机歌曲数量
            
            // 创建时间分散
            NSTimeInterval offset = -(arc4random_uniform(30 * 24 * 60 * 60)); // 30天内
            info.createDate = [NSDate dateWithTimeIntervalSinceNow:offset];
            info.modifyDate = info.createDate;
            
            [self.allPlaylists addObject:playlist];
            self.playlistInfos[playlistId] = info;
        }
        
        [self applyFilterAndSort];
        [self savePlaylistsToLocalWithCompletion:nil];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:XCPlaylistDataChangedNotification
                                                                object:self];
        });
    });
}

- (BOOL)verifyDataConsistencyForTesting {
    // 验证数据一致性
    // 1. allPlaylists 和 playlistInfos 的 ID 应该对应
    for (XC_YYAlbumData* playlist in self.allPlaylists) {
        if (!self.playlistInfos[playlist.albumId]) {
            NSLog(@"[XCPersonalModel] 数据不一致: playlist %@ 没有对应的 info", playlist.albumId);
            return NO;
        }
    }
    
    // 2. 不应该有重复ID
    NSMutableSet* ids = [NSMutableSet set];
    for (XC_YYAlbumData* playlist in self.allPlaylists) {
        if ([ids containsObject:playlist.albumId]) {
            NSLog(@"[XCPersonalModel] 数据不一致: 重复的 playlist ID %@", playlist.albumId);
            return NO;
        }
        [ids addObject:playlist.albumId];
    }
    
    // 3. filteredPlaylists 应该是 allPlaylists 的子集
    for (XC_YYAlbumData* playlist in self.filteredPlaylists) {
        BOOL found = NO;
        for (XC_YYAlbumData* original in self.allPlaylists) {
            if ([original.albumId isEqualToString:playlist.albumId]) {
                found = YES;
                break;
            }
        }
        if (!found) {
            NSLog(@"[XCPersonalModel] 数据不一致: filtered playlist %@ 不在 allPlaylists 中", playlist.albumId);
            return NO;
        }
    }
    
    NSLog(@"[XCPersonalModel] 数据一致性检查通过");
    return YES;
}

@end
