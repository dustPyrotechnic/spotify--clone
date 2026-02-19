//
//  XCAudioCacheConst.h
//  Spotify - clone
//

#import <Foundation/Foundation.h>

/// 音频缓存系统常量定义
/// 包含所有缓存层级(L1/L2/L3)共享的常量和枚举定义

/// 分段大小：512KB
/// @note 平衡网络请求次数和内存碎片
static const NSUInteger kAudioSegmentSize = 512 * 1024;
/// L1 层(NSCache)内存限制：100MB
static const NSUInteger kAudioCacheMemoryLimit = 100 * 1024 * 1024;
/// L3 层(Cache)磁盘限制：1GB
static const NSUInteger kAudioCacheDiskLimit = 1024 * 1024 * 1024;
/// L2 层(Tmp)磁盘限制：500MB
static const NSUInteger kAudioCacheTempLimit = 500 * 1024 * 1024;
/// 临时文件过期时间：7天
/// @see XCTempCacheManager 用于清理过期临时文件
static const NSTimeInterval kAudioTempFileExpireTime = 7 * 24 * 60 * 60;

/// 音频文件状态枚举
/// @discussion 用于 XCAudioCacheManager 查询时返回当前缓存状态
typedef NS_ENUM(NSInteger, XCAudioFileCacheState) {
  /// 无任何缓存
  XCAudioFileCacheStateNone = 0,
  /// 仅有 L1 分段缓存在内存中
  XCAudioFileCacheStateInMemory = 1,
  /// 有 L2 临时文件（可能不完整）
  XCAudioFileCacheStateTempFile = 2,
  /// 有 L3 完整缓存
  XCAudioFileCacheStateComplete = 3
};

/// 预加载优先级枚举
/// @see XCPreloadManager
typedef NS_ENUM(NSInteger, XCAudioPreloadPriority) {
  XCAudioPreloadPriorityLow = 0,
  XCAudioPreloadPriorityNormal = 1,
  XCAudioPreloadPriorityHigh = 2
};
