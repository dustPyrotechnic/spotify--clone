//
//  XCSearchSuggestionCell.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/23.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, XCSuggestionType) {
    XCSuggestionTypeRecent,      // 最近搜索
    XCSuggestionTypeSuggestion,  // 搜索建议
    XCSuggestionTypeHot          // 热门搜索
};

/// 搜索建议 Cell - 用于最近搜索、搜索建议和热门搜索
@interface XCSearchSuggestionCell : UITableViewCell

/// 建议类型
@property (nonatomic, assign) XCSuggestionType suggestionType;

/// 标题
@property (nonatomic, strong, readonly) UILabel *titleLabel;

/// 配置 Cell
- (void)configureWithText:(NSString *)text type:(XCSuggestionType)type;

@end

NS_ASSUME_NONNULL_END
