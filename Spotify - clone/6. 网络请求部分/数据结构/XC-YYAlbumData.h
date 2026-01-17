//
//  XC-YYAlbumData.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/1/12.
//

#import <Foundation/Foundation.h>
#import <YYModel/YYModel.h>

NS_ASSUME_NONNULL_BEGIN

@interface XC_YYAlbumData : NSObject <YYModel>
// 专辑数据
@property (nonatomic, copy) NSString* coverImgUrl;
@property (nonatomic, copy) NSString* name;
@property (nonatomic,copy) NSString* albumId;
// 专辑作者数据
@property (nonatomic, copy) NSString* authorName;
@property (nonatomic, copy) NSString* authorId;
@end

NS_ASSUME_NONNULL_END
