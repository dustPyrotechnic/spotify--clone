//
//  XC-YYAlbumData.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/1/12.
//

#import <Foundation/Foundation.h>
#import <YYModel/YYModel.h>
#import <WCDBObjc/WCDBObjc.h>

NS_ASSUME_NONNULL_BEGIN

@interface XC_YYAlbumData : NSObject <YYModel, WCTTableCoding>
// 专辑数据（同时作为播放列表字段）
@property (nonatomic, copy) NSString* coverImgUrl;
@property (nonatomic, copy) NSString* name;
@property (nonatomic, copy) NSString* albumId;      // 主键
// 专辑作者数据
@property (nonatomic, copy) NSString* artistName;
@property (nonatomic, copy) NSString* authorId;

// 本地播放列表专用字段（不参与 YYModel 网络映射）
@property (nonatomic, assign) NSInteger createTime;   // 创建时间戳（Unix ms）
@property (nonatomic, assign) NSInteger updateTime;   // 最近更新时间（用于排序）
@property (nonatomic, assign) NSInteger songCount;    // 歌曲数量（冗余，避免 join）
@property (nonatomic, assign) BOOL isFavorites;       // 是否为内置「喜爱的歌曲」
@property (nonatomic, assign) NSInteger sortIndex;    // 手动排序序号（预留）

WCDB_PROPERTY(albumId)
WCDB_PROPERTY(name)
WCDB_PROPERTY(coverImgUrl)
WCDB_PROPERTY(artistName)
WCDB_PROPERTY(authorId)
WCDB_PROPERTY(createTime)
WCDB_PROPERTY(updateTime)
WCDB_PROPERTY(songCount)
WCDB_PROPERTY(isFavorites)
WCDB_PROPERTY(sortIndex)

@end

NS_ASSUME_NONNULL_END
