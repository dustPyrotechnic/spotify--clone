//
//  XCAudioSegmentInfo.h
//  Spotify - clone
//

#import <Foundation/Foundation.h>

/// L1 层缓存数据模型：音频分段信息
/// @discussion 封装单个音频分段的数据和元信息，存储于 NSCache(L1 层)
/// @note Key 格式: "{songId}_{segmentIndex}"
@interface XCAudioSegmentInfo : NSObject

/// 分段索引，从 0 开始
@property (nonatomic, assign) NSInteger index;

/// 在完整音频文件中的起始偏移量(字节)
@property (nonatomic, assign) int64_t offset;

/// 分段数据大小(字节)
/// @note 除最后一个分段外，通常为 kAudioSegmentSize(512KB)
@property (nonatomic, assign) NSInteger size;

/// 分段二进制数据
/// @warning 仅存在于 L1 层(NSCache)，不持久化到磁盘
@property (nonatomic, strong) NSData *data;

/// 是否已完成下载
@property (nonatomic, assign) BOOL isDownloaded;

/// 初始化方法
/// - Parameters:
///   - index: 分段索引
///   - offset: 文件起始偏移量
///   - size: 分段大小
- (instancetype)initWithIndex:(NSInteger)index offset:(int64_t)offset size:(NSInteger)size;

@end
