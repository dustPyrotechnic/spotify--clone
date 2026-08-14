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

/**
 * 歌曲数据模型
 *
 * 同时遵循 YYModel 和 WCTTableCoding，一个类两用：
 * - JSON 解析：网络接口返回歌曲列表时直接 decode
 * - WCDB 持久化：本地播放列表存歌曲用这个表
 *
 * artists / alias 两个字段纯内存使用，不进 WCDB。
 *
 * - Note: songId 是主键，由 ``WCDB_PRIMARY`` 宏声明。
 * - Important: songUrl 不是初始化时拿到的，需要额外调 /song/url/v1 接口。
 */
@interface XC_YYSongData : NSObject <YYModel, WCTTableCoding>

#pragma mark - 基础信息
/// 歌曲名称
@property (nonatomic, strong) NSString *name;



/// 歌曲ID，数据库唯一辨别
@property (nonatomic, strong) NSString *songId;




/// 专辑封面URL（映射 al.picUrl）
@property (nonatomic, strong) NSString *mainIma;
/// 播放URL（没啥用，网络的url是有时限的，不下载就炸了）
@property (nonatomic, strong, nullable) NSString *songUrl;

#pragma mark - 艺术家信息

/// 主艺术家名称，取网络请求上的 ar[0].name，之后可以考虑拼接艺术家的名字
@property (nonatomic, strong) NSString *artist;
/// 主艺术家ID
@property (nonatomic, strong) NSString *artistId;
/// 所有艺术家数组
@property (nonatomic, strong, nullable) NSArray *artists;

#pragma mark - 专辑信息
/// 专辑名称al.name
@property (nonatomic, strong) NSString *albumName;

/// 专辑ID映射 al.id
@property (nonatomic, strong) NSString *albumId;

/// 歌曲时长，单位毫秒
@property (nonatomic, assign) NSInteger duration;
/// MV ID，0表示无MV，之后可以考虑加入视频播放，反正直接交给avplayer播放即可
@property (nonatomic, assign) NSInteger mvId;
/// 专辑内序号（映射 no）
@property (nonatomic, assign) NSInteger trackNumber;




// 下面是乱七八糟的玩意，没啥用但是还是存了
/// 歌曲别名数组（映射 alia，不存入 WCDB）
@property (nonatomic, strong, nullable) NSArray *alias;

/// 热度值 0-100（映射 pop）
@property (nonatomic, assign) NSInteger popularity;

/// 付费类型：0=免费, 1=VIP, 4=付费（映射 fee）
@property (nonatomic, assign) NSInteger fee;

#pragma mark - 计算属性
/// 格式化时长，把毫秒转换成可以读的几分几秒
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
