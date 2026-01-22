//
//  XC-YYSongData.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/1/18.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface XC_YYSongData : NSObject
/// 歌曲的名字
@property (nonatomic, strong) NSString* name;
/// 歌曲的封面
@property (nonatomic, strong) UIImage* mainIma;
/// 歌曲的id信息
@property (nonatomic, strong) NSString* songId;
/// 播放歌曲的URL，网络或者本地
@property (nonatomic, strong) NSString* songUrl;


@end

NS_ASSUME_NONNULL_END
