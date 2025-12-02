//
//  XCAlbumSimpleData.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/11/28.
//

#import <Foundation/Foundation.h>

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface XCAlbumSimpleData : NSObject
// 存储一张专辑或者播放列表的基本信息
/// 专辑的封面信息
@property (nonatomic, strong) NSString* imageURL;
/// 专辑的名字
@property (nonatomic, strong) NSString* nameAlbum;
/// 专辑的id信息
@property (nonatomic, strong) NSString* idOfAlbum;

@end


NS_ASSUME_NONNULL_END
