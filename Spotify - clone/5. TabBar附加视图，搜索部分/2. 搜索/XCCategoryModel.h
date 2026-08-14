//
//  XCCategoryModel.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/22.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface XCCategoryModel : NSObject

/// 分类名称
@property (nonatomic, copy) NSString *name;
/// 背景颜色 Hex 字符串 (如 "#1DB954")
@property (nonatomic, copy) NSString *backgroundColorHex;
/// 预览封面图 URL
@property (nonatomic, copy) NSString *previewCoverUrl;

/// 获取默认分类列表
+ (NSArray<XCCategoryModel *> *)defaultCategories;

@end

NS_ASSUME_NONNULL_END
