//
//  XCPersonalModel.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/1.
//

#import <Foundation/Foundation.h>

#import "XC-YYSongData.h"
#import "XC-YYAlbumData.h"


NS_ASSUME_NONNULL_BEGIN

@interface XCPersonalModel : NSObject
/// 存储个人播放列表的专辑
@property (nonatomic, strong) NSMutableArray<XC_YYAlbumData*>* personalAlbumArray;
@end

NS_ASSUME_NONNULL_END
