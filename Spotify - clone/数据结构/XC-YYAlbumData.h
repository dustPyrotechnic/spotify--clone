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

/**
 * 专辑 / 本地播放列表数据模型
 *
 * 一鱼两吃：网络接口返回的专辑和用户在本地创建的播放列表共用这个类
 * 区别主要在 createTime / updateTime / isFavorites 这几个本地专用字段——
 * 网络专辑走 YYModel 反序列化，这些字段不参与映射，默认为零值即可
 *
 * - Important: albumId 是 WCDB 主键。本地列表用 UUID，
 *   内置「喜爱的歌曲」固定为字符串 "favorites"。
 */
@interface XC_YYAlbumData : NSObject <YYModel, WCTTableCoding>

// 专辑数据（同时作为播放列表字段）
/// 封面图片 URL
@property (nonatomic, copy) NSString* coverImgUrl;
/// 专辑或播放列表名称
@property (nonatomic, copy) NSString* name;



/// 主键网络专辑 = 接口 id，本地列表 = UUID
@property (nonatomic, copy) NSString* albumId;



// 专辑作者数据
/// 作者昵称，映射 creator.nickname
@property (nonatomic, copy) NSString* artistName;
/// 作者 ID，映射 creator.userId
@property (nonatomic, copy) NSString* authorId;

// 本地播放列表专用字段（不参与 YYModel 网络映射）
/// 创建时间戳，毫秒
@property (nonatomic, assign) NSInteger createTime;
/// 最近更新时间（用于排序）
@property (nonatomic, assign) NSInteger updateTime;
/// 歌曲数量（冗余字段，避免 join）
@property (nonatomic, assign) NSInteger songCount;
/// 是否为内置「喜爱的歌曲」，YES 时不允许删除
@property (nonatomic, assign) BOOL isFavorites;
/// 手动排序序号（预留，暂未启用）
@property (nonatomic, assign) NSInteger sortIndex;

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
