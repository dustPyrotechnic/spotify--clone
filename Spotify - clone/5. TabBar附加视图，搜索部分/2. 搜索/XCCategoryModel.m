//
//  XCCategoryModel.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/22.
//

#import "XCCategoryModel.h"

@implementation XCCategoryModel

+ (NSArray<XCCategoryModel *> *)defaultCategories {
    NSArray *categories = @[
        @{@"name": @"流行音乐", @"color": @"#E91E63"},
        @{@"name": @"摇滚经典", @"color": @"#3F51B5"},
        @{@"name": @"古典音乐", @"color": @"#9C27B0"},
        @{@"name": @"爵士乐", @"color": @"#FF9800"},
        @{@"name": @"说唱嘻哈", @"color": @"#795548"},
        @{@"name": @"电子音乐", @"color": @"#00BCD4"},
        @{@"name": @"民谣", @"color": @"#4CAF50"},
        @{@"name": @"蓝调", @"color": @"#2196F3"},
        @{@"name": @"乡村音乐", @"color": @"#8BC34A"},
        @{@"name": @"轻音乐", @"color": @"#607D8B"}
    ];
    
    NSMutableArray<XCCategoryModel *> *models = [NSMutableArray array];
    for (NSDictionary *dict in categories) {
        XCCategoryModel *model = [[XCCategoryModel alloc] init];
        model.name = dict[@"name"];
        model.backgroundColorHex = dict[@"color"];
        [models addObject:model];
    }
    return [models copy];
}

@end
