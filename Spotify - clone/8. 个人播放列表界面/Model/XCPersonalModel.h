//
//  XCPersonalModel.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/1.
//
//  Model 层 - 个人播放列表数据管理
//  职责：数据管理、业务逻辑、本地存储
//

#import <Foundation/Foundation.h>
#import "XC-YYAlbumData.h"
#import "XCLocalPlaylistInfo.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark - 通知常量
/// 播放列表数据变更通知
extern NSString* const XCPlaylistDataChangedNotification;
/// 播放列表搜索完成通知
extern NSString* const XCPlaylistSearchCompletedNotification;
/// 播放列表创建成功通知（userInfo 包含 playlistId）
extern NSString* const XCPlaylistCreatedNotification;
/// 播放列表删除成功通知（userInfo 包含 playlistId）
extern NSString* const XCPlaylistDeletedNotification;

#pragma mark - XCPersonalModel 类
/// 个人播放列表数据管理器（MVC 中的 Model 层）
/// 负责：数据管理、业务逻辑、本地存储
/// 不依赖 UI，可独立测试
@interface XCPersonalModel : NSObject

#pragma mark - 数据属性（只读）
/// 所有播放列表（原始数据）
@property (nonatomic, strong, readonly) NSMutableArray<XC_YYAlbumData*>* allPlaylists;
/// 过滤后的播放列表（展示用）
@property (nonatomic, strong, readonly) NSMutableArray<XC_YYAlbumData*>* filteredPlaylists;
/// 本地扩展信息字典（key: playlistId, value: XCLocalPlaylistInfo）
@property (nonatomic, strong, readonly) NSMutableDictionary<NSString*, XCLocalPlaylistInfo*>* playlistInfos;
/// 当前排序方式
@property (nonatomic, assign, readonly) XCPlaylistSortType currentSortType;
/// 当前搜索关键词
@property (nonatomic, copy, readonly, nullable) NSString* currentSearchText;

#pragma mark - 单例访问
/// 获取单例实例
+ (instancetype)sharedInstance;

#pragma mark - 数据加载/保存
/// 从本地加载播放列表数据
/// @param completion 完成回调（主线程）
- (void)loadPlaylistsFromLocalWithCompletion:(nullable void(^)(BOOL success))completion;

/// 保存播放列表数据到本地
/// @param completion 完成回调（主线程）
- (void)savePlaylistsToLocalWithCompletion:(nullable void(^)(BOOL success))completion;

#pragma mark - 播放列表 CRUD 操作
/// 创建新的播放列表
/// @param name 播放列表名称
/// @param completion 完成回调（主线程），返回创建结果和 playlistId
- (void)createPlaylistWithName:(NSString*)name
                    completion:(nullable void(^)(BOOL success, NSString* _Nullable playlistId))completion;

/// 删除播放列表
/// @param playlistId 播放列表ID
/// @param completion 完成回调（主线程）
- (void)deletePlaylistWithId:(NSString*)playlistId
                  completion:(nullable void(^)(BOOL success))completion;

/// 更新播放列表名称
/// @param playlistId 播放列表ID
/// @param name 新名称
/// @param completion 完成回调（主线程）
- (void)updatePlaylistWithId:(NSString*)playlistId
                        name:(NSString*)name
                  completion:(nullable void(^)(BOOL success))completion;

/// 更新播放列表歌曲数量
/// @param playlistId 播放列表ID
/// @param songCount 歌曲数量
- (void)updatePlaylistSongCount:(NSString*)playlistId
                      songCount:(NSInteger)songCount;

#pragma mark - 搜索/排序/筛选
/// 根据搜索文本过滤播放列表
/// @param searchText 搜索文本（nil 或空字符串表示显示全部）
- (void)filterPlaylistsWithSearchText:(nullable NSString*)searchText;

/// 按指定类型排序播放列表
/// @param sortType 排序类型
- (void)sortPlaylistsByType:(XCPlaylistSortType)sortType;

/// 清除搜索，显示全部播放列表
- (void)clearFilter;

#pragma mark - 扩展信息查询
/// 获取播放列表的本地扩展信息
/// @param playlistId 播放列表ID
/// @return 扩展信息对象（如果不存在则返回 nil）
- (nullable XCLocalPlaylistInfo*)infoForPlaylist:(NSString*)playlistId;

/// 获取播放列表的歌曲数量
/// @param playlistId 播放列表ID
/// @return 歌曲数量（如果没有记录返回 0）
- (NSInteger)songCountForPlaylist:(NSString*)playlistId;

#pragma mark - 测试辅助方法
/// 清空所有数据（仅用于测试）
- (void)clearAllDataForTesting;

/// 添加测试数据（仅用于测试）
/// @param count 测试数据数量
- (void)addTestDataForTesting:(NSInteger)count;

/// 验证数据一致性（仅用于测试）
/// @return 是否一致
- (BOOL)verifyDataConsistencyForTesting;

@end

NS_ASSUME_NONNULL_END
