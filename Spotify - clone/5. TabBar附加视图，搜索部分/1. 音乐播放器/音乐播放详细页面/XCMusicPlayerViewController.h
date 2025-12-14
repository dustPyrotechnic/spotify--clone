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

@end

NS_ASSUME_NONNULL_END
