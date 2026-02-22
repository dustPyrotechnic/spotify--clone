//
//  MainTabBarControllerViewController.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/11/22.
//

#import "MainTabBarController.h"

#import "XCNetworkManager.h"

#import <CoreGraphics/CoreGraphics.h>
#import <UIKit/UIKit.h>

// 引入四个页面部分内容
#import "HomePageViewController.h"
#import "XCPersonalViewController.h"



// 引入附加视图
#import "XCMusicPlayerAccessoryView.h"
// 音乐播放详情页面
#import "XCMusicPlayerModel.h"
// 搜索界面
#import "XCSearchViewController.h"


// 测试
#import "XCMusicPlayerViewController.h"

@interface MainTabBarController ()
@property (nonatomic, assign) BOOL hasPresentedPlayer;
@property (nonatomic, strong) XCMusicPlayerAccessoryView *musicPlayerAccessoryView;
@end

@implementation MainTabBarController

- (void)viewDidLoad {
    [super viewDidLoad];
    UITab *homeTab = [[UITab alloc] initWithTitle:@"Home"
                                            image:[UIImage systemImageNamed:@"house"]
                                       identifier:@"Home"
                           viewControllerProvider:^UIViewController * _Nonnull(UITab * _Nonnull tab) {
        HomePageViewController *homePageController = [[HomePageViewController alloc] init];
        return [[UINavigationController alloc] initWithRootViewController:homePageController];
    }];

    UITab *musicTab = [[UITab alloc] initWithTitle:@"Music Warehouse"
                                             image:[UIImage systemImageNamed:@"music.pages"]
                                        identifier:@"MusicWarehouse"
                            viewControllerProvider:^UIViewController * _Nonnull(UITab * _Nonnull tab) {
      XCPersonalViewController *musicWarehousePageController = [[XCPersonalViewController alloc] init];
        return [[UINavigationController alloc] initWithRootViewController:musicWarehousePageController];
    }];

    UITab *foundingTab = [[UITab alloc] initWithTitle:@"New Founding"
                                                image:[UIImage systemImageNamed:@"star.bubble"]
                                           identifier:@"NewFounding"
                               viewControllerProvider:^UIViewController * _Nonnull(UITab * _Nonnull tab) {
        UIViewController *newFoundingViewController = [[UIViewController alloc] init];
        return [[UINavigationController alloc] initWithRootViewController:newFoundingViewController];
    }];

    UITab *broadcastTab = [[UITab alloc] initWithTitle:@"Broad Cast"
                                                 image:[UIImage systemImageNamed:@"wave.3.up"]
                                            identifier:@"BroadCast"
                                viewControllerProvider:^UIViewController * _Nonnull(UITab * _Nonnull tab) {
        UIViewController *broadCastPageViewController = [[UIViewController alloc] init];
        return [[UINavigationController alloc] initWithRootViewController:broadCastPageViewController];
    }];

    UISearchTab *searchTab = [[UISearchTab alloc] initWithViewControllerProvider:^UIViewController * _Nonnull(UITab * _Nonnull tab) {
      XCSearchViewController *searchViewController = [[XCSearchViewController alloc] init];
      UINavigationController* navigationVC = [[UINavigationController alloc] initWithRootViewController:searchViewController];
      //TODO: 完成点击搜索框的变形机制
      return navigationVC;
    }];
    searchTab.automaticallyActivatesSearch = NO;
    


    self.tabs = @[homeTab, musicTab, foundingTab, broadcastTab, searchTab];


    self.delegate = self;
    self.tabBar.tintColor = [UIColor systemGreenColor];

    self.tabBar.layer.borderWidth = 0;

    self.tabBarMinimizeBehavior = UITabBarMinimizeBehaviorOnScrollDown;
    
    // 初始化底部播放条
    self.musicPlayerAccessoryView = [[XCMusicPlayerAccessoryView alloc] initWithFrame:CGRectMake(20, 20, self.view.bounds.size.width - 40, 40) withImage:[UIImage imageNamed:@"1.jpeg"] andTitle:@"测试歌曲" withSonger:@"测试歌手" withCondition:NO];

    __weak typeof(self) weakSelf = self;
    self.musicPlayerAccessoryView.presentPlayerViewControllerBlock = ^(XCMusicPlayerViewController * _Nonnull playerVC) {
        [weakSelf presentViewController:playerVC animated:YES completion:nil];
    };

    self.bottomAccessory = [[UITabAccessory alloc] initWithContentView:self.musicPlayerAccessoryView];
    
    // 注册通知监听
    [self registerNotifications];
    
    // 同步当前播放状态
    XCMusicPlayerModel *model = [XCMusicPlayerModel sharedInstance];
    if (model.nowPlayingSong) {
        [self.musicPlayerAccessoryView updateWithSong:model.nowPlayingSong];
        // 使用 Model 维护的播放状态
        [self.musicPlayerAccessoryView updatePlayState:model.isPlaying];
    }

//  XCMusicPlayerModel* model = [XCMusicPlayerModel sharedInstance];
//  [model testPlayAppleMusicSong];
//  [[XCNetworkManager sharedInstance] testAPIFullFlowWithCompletion:^(BOOL success, NSString * _Nonnull message) {
//        if (success) {
//            NSLog(@"测试成功: %@", message);
//          [[XCNetworkManager sharedInstance] testAPIClearStoredTokens];
//        } else {
//            NSLog(@"测试失败: %@", message);
//          [[XCNetworkManager sharedInstance] testAPIClearStoredTokens];
//        }
//  }];
  /*
  [[XCNetworkManager sharedInstance] loginWithAccount:@"admin" password:@"admin123" completion:^(BOOL success, NSString * _Nullable accessToken, NSString * _Nullable refreshToken, NSDictionary * _Nullable userInfo, NSError * _Nullable error) {
    NSLog(@"登录成功");
  }];
   */


}

- (void)dealloc {
    // 移除通知监听
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - 通知注册

- (void)registerNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleNowPlayingSongDidChange:)
                                                 name:XCMusicPlayerNowPlayingSongDidChangeNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handlePlaybackStateDidChange:)
                                                 name:XCMusicPlayerPlaybackStateDidChangeNotification
                                               object:nil];
}

#pragma mark - 通知处理

- (void)handleNowPlayingSongDidChange:(NSNotification *)notification {
    XC_YYSongData *song = notification.userInfo[@"song"];
    if ([song isKindOfClass:[NSNull class]]) song = nil;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.musicPlayerAccessoryView updateWithSong:song];
        // 播放新歌曲时，自动将播放状态设为"播放中"（显示暂停按钮）
        [self.musicPlayerAccessoryView updatePlayState:YES];
    });
}

- (void)handlePlaybackStateDidChange:(NSNotification *)notification {
    BOOL isPlaying = [notification.userInfo[@"isPlaying"] boolValue];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.musicPlayerAccessoryView updatePlayState:isPlaying];
    });
}

- (void) tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController {
  NSLog(@"didSelectViewController: %@", viewController);
  UIImpactFeedbackGenerator* feedbackGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
  [feedbackGenerator prepare];
  [feedbackGenerator impactOccurred];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
