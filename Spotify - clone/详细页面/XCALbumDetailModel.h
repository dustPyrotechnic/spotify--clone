//
//  XCALbumDetailModel.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/12/9.
//

#import <Foundation/Foundation.h>

#import "XC-YYSongData.h"

NS_ASSUME_NONNULL_BEGIN

@interface XCALbumDetailModel : NSObject
/// 显示的图片URL
@property (nonatomic, strong) NSString* mainImaUrl;
/// 显示的编辑时间
@property (nonatomic, strong) NSString* timeStr;
/// 歌单，专辑，名字
@property (nonatomic, strong) NSString* playerlistName;
/// 显示的歌曲名单
@property (nonatomic, strong) NSMutableArray<XC_YYSongData*>* playerList;
@end

NS_ASSUME_NONNULL_END
