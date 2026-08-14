//
//  XCPersonalModel.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/1.
//

#import <Foundation/Foundation.h>

#import "XC-YYSongData.h"
#import "XC-YYAlbumData.h"

NS_ASSUME_NONNULL_BEGIN

@interface XCPersonalModel : NSObject

/// 播放列表数组（从 DB 加载）
@property (nonatomic, strong) NSMutableArray<XC_YYAlbumData *> *playlists;

+ (instancetype)sharedInstance;

/// 从数据库重新加载所有播放列表
- (void)loadPlaylists;

/// 新建播放列表，成功返回新建对象，失败返回 nil
- (nullable XC_YYAlbumData *)createPlaylistWithName:(NSString *)name;

/// 删除指定播放列表（喜爱的歌曲不可删除）
/// @return YES 删除成功并已从数组移除，NO 删除失败
- (BOOL)deletePlaylistAtIndex:(NSInteger)index;

@end

NS_ASSUME_NONNULL_END
