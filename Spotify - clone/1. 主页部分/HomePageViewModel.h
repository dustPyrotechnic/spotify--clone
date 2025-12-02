//
//  HomePageViewModel.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/11/22.
//

#import <Foundation/Foundation.h>

#import "XCAlbumSimpleData.h"

NS_ASSUME_NONNULL_BEGIN

@interface HomePageViewModel : NSObject
/// 二维数组，存储5个10个的数组
@property (nonatomic, strong) NSMutableArray* dataOfAllAlbums;
@property (atomic, assign) NSInteger offset;
// 拿到所有的网络数据
- (void) getDataOfAllAlbums;
@end

NS_ASSUME_NONNULL_END
