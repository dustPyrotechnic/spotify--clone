//
//  XCSongCommentFloorViewController.h
//  Spotify - clone
//
//  楼层评论页面 - 展示某条评论的全部回复
//

#import <UIKit/UIKit.h>
#import "XCSongComment.h"

NS_ASSUME_NONNULL_BEGIN

/// 楼层评论页面
/// 通过 initWithComment:songId: 初始化后 present 展示
@interface XCSongCommentFloorViewController : UIViewController

/// 楼主评论（入口评论）
@property (nonatomic, strong, readonly) XCSongComment *parentComment;
/// 所属歌曲ID（用于网络请求）
@property (nonatomic, copy, readonly) NSString *songId;

/// 指定初始化方法
/// @param comment 被点击的楼主评论
/// @param songId 歌曲ID
- (instancetype)initWithComment:(XCSongComment *)comment songId:(NSString *)songId;

@end

NS_ASSUME_NONNULL_END
