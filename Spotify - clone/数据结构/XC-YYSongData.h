//
//  XC-YYSongData.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/1/18.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <YYModel/YYModel.h>
#import <WCDBObjc/WCDBObjc.h>

NS_ASSUME_NONNULL_BEGIN

@interface XC_YYSongData : NSObject <YYModel, WCTTableCoding>

#pragma mark - 基础信息
/// 歌曲名称
@property (nonatomic, strong) NSString *name;
/// 歌曲ID（主键）
@property (nonatomic, strong) NSString *songId;
/// 专辑封面URL（映射 al.picUrl）
@property (nonatomic, strong) NSString *mainIma;
/// 播放URL（通过 /song/url/v1 获取）
@property (nonatomic, strong, nullable) NSString *songUrl;

#pragma mark - 艺术家信息
/// 主艺术家名称（取 ar[0].name）
@property (nonatomic, strong) NSString *artist;
/// 主艺术家ID（取 ar[0].id）
@property (nonatomic, strong) NSString *artistId;
/// 所有艺术家数组（原始 ar 数组，不存入 WCDB）
@property (nonatomic, strong, nullable) NSArray *artists;

#pragma mark - 专辑信息
/// 专辑名称（映射 al.name）
@property (nonatomic, strong) NSString *albumName;
/// 专辑ID（映射 al.id）
@property (nonatomic, strong) NSString *albumId;

#pragma mark - 播放信息
/// 歌曲时长，单位毫秒（映射 dt）
@property (nonatomic, assign) NSInteger duration;
/// MV ID，0表示无MV（映射 mv）
@property (nonatomic, assign) NSInteger mvId;
/// 专辑内序号（映射 no）
@property (nonatomic, assign) NSInteger trackNumber;

#pragma mark - 其他信息
/// 歌曲别名数组（映射 alia，不存入 WCDB）
@property (nonatomic, strong, nullable) NSArray *alias;
/// 热度值 0-100（映射 pop）
@property (nonatomic, assign) NSInteger popularity;
/// 付费类型：0=免费, 1=VIP, 4=付费（映射 fee）
@property (nonatomic, assign) NSInteger fee;

#pragma mark - 计算属性（只读，不存入 WCDB）
/// 格式化时长，如 "03:46"
@property (nonatomic, copy, readonly) NSString *durationText;
/// 是否可播放MV
@property (nonatomic, assign, readonly) BOOL hasMV;
/// 付费类型描述
@property (nonatomic, copy, readonly) NSString *feeDescription;

// WCDB 字段绑定（13 个存储字段，不含 playlistId）
WCDB_PROPERTY(songId)
WCDB_PROPERTY(name)
WCDB_PROPERTY(mainIma)
WCDB_PROPERTY(songUrl)
WCDB_PROPERTY(artist)
WCDB_PROPERTY(artistId)
WCDB_PROPERTY(albumName)
WCDB_PROPERTY(albumId)
WCDB_PROPERTY(duration)
WCDB_PROPERTY(mvId)
WCDB_PROPERTY(trackNumber)
WCDB_PROPERTY(popularity)
WCDB_PROPERTY(fee)

@end

NS_ASSUME_NONNULL_END
