//
//  XCLocalPlaylistInfo.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/20.
//
//  本地播放列表扩展信息
//  用于存储播放列表的本地元数据（歌曲数量、创建时间等）
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - 播放列表类型枚举
typedef NS_ENUM(NSInteger, XCPlaylistType) {
    XCPlaylistTypeSystem = 0,    // 系统默认播放列表（如"喜爱的歌曲"）
    XCPlaylistTypeUserCreated    // 用户创建的播放列表
};

#pragma mark - 播放列表排序类型枚举
typedef NS_ENUM(NSInteger, XCPlaylistSortType) {
    XCPlaylistSortTypeCreateDateDesc = 0,    // 最近创建（默认）
    XCPlaylistSortTypeModifyDateDesc,        // 最近修改
    XCPlaylistSortTypeNameAsc,               // 名称 A-Z
    XCPlaylistSortTypeNameDesc,              // 名称 Z-A
    XCPlaylistSortTypeSongCountDesc          // 最多歌曲
};

#pragma mark - XCLocalPlaylistInfo 类
/// 本地播放列表扩展信息
/// 存储在本地，不依赖网络 API
@interface XCLocalPlaylistInfo : NSObject <NSSecureCoding>

#pragma mark - 基础信息
/// 播放列表ID（唯一标识）
@property (nonatomic, copy) NSString* playlistId;
/// 播放列表名称（冗余存储，方便本地排序）
@property (nonatomic, copy) NSString* playlistName;

#pragma mark - 统计信息
/// 歌曲数量
@property (nonatomic, assign) NSInteger songCount;

#pragma mark - 时间信息
/// 创建时间
@property (nonatomic, strong) NSDate* createDate;
/// 最后修改时间
@property (nonatomic, strong) NSDate* modifyDate;

#pragma mark - 属性信息
/// 播放列表类型
@property (nonatomic, assign) XCPlaylistType playlistType;
/// 是否置顶
@property (nonatomic, assign) BOOL isPinned;
/// 封面图片本地路径（如果有自定义封面）
@property (nonatomic, copy, nullable) NSString* localCoverPath;

#pragma mark - 初始化方法
/// 便捷构造方法
/// @param playlistId 播放列表ID
/// @param name 播放列表名称
+ (instancetype)infoWithPlaylistId:(NSString*)playlistId name:(NSString*)name;

#pragma mark - 便捷属性
/// 格式化的时间描述（如"2周前"）
- (NSString*)timeDescription;
/// 格式化歌曲数量（如"50首"）
- (NSString*)songCountText;

@end

NS_ASSUME_NONNULL_END
