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
- (void)getDataOfAllAlbumsWithCompletion:(void(^)(BOOL success)) completion;
@end

NS_ASSUME_NONNULL_END
