//
//  XCMusicPlayerViewController.h
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/12/1.
//

#import <UIKit/UIKit.h>
#import "XCMusicPlayerView.h"
#import "XCMusicPlayerModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface XCMusicPlayerViewController : UIViewController
@property (nonatomic, strong) XCMusicPlayerView* mainView;
@property (nonatomic, strong) XCMusicPlayerModel* musicPlayerModel;
@property (nonatomic, assign) BOOL isPlaying;

#pragma mark - Phase 3: 评论面板

/// 显示评论面板
- (void)showCommentPanel;

/// 隐藏评论面板
- (void)hideCommentPanel;

/// 评论面板是否可见
- (BOOL)isCommentPanelVisible;

@end

NS_ASSUME_NONNULL_END
