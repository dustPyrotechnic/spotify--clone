//
//  MainTabBarControllerViewController.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/11/22.
//

#import "MainTabBarController.h"

#import <CoreGraphics/CoreGraphics.h>

// 引入四个页面部分内容
#import "HomePageViewController.h"



// 引入附加视图
#import "XCMusicPlayerAccessoryView.h"

@interface MainTabBarController ()

@end

@implementation MainTabBarController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.

  HomePageViewController* homePageController = [[HomePageViewController alloc] init];
  UINavigationController* homePageNavigationController = [[UINavigationController alloc] initWithRootViewController:homePageController];

  UIViewController* musicWarehousePageController = [[UIViewController alloc] init];
  UINavigationController* musicWarehouseNavigationController = [[UINavigationController alloc] initWithRootViewController:musicWarehousePageController];

  UIViewController* newFoundingViewController = [[UIViewController alloc] init];
  UINavigationController* newFoundingNavigationController = [[UINavigationController alloc] initWithRootViewController:newFoundingViewController];

  UIViewController* broadCastPageViewController = [[UIViewController alloc] init];
  UINavigationController* broadCasrPageNavigationController = [[UINavigationController alloc] initWithRootViewController:broadCastPageViewController];

  UIImage* homePageImage = [UIImage systemImageNamed:@"house"];
  UIImage* selectedHomePageImage = [UIImage systemImageNamed:@"house.fill"];

  UIImage* musicWarehouseImage = [UIImage systemImageNamed:@"music.pages"];
  UIImage* selectedMusicWarehouseImage = [UIImage systemImageNamed:@"music.pages.fill"];

  UIImage* newFoundingImage = [UIImage systemImageNamed:@"star.bubble"];
  UIImage* selectedNewFoundingImage = [UIImage systemImageNamed:@"star.bubble.fill"];

  UIImage* broadCastImage = [UIImage systemImageNamed:@"wave.3.up"];
  UIImage* selectedBroadCastImage = [UIImage systemImageNamed:@"wave.3.up.fill"];
  
  homePageNavigationController.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Home" image:homePageImage selectedImage:selectedHomePageImage];
  musicWarehouseNavigationController.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Music Warehouse" image:musicWarehouseImage selectedImage:selectedMusicWarehouseImage];
  newFoundingNavigationController.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"New Founding" image:newFoundingImage selectedImage:selectedNewFoundingImage];
  broadCasrPageNavigationController.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Broad Cast" image:broadCastImage selectedImage:selectedBroadCastImage];

  self.viewControllers = @[homePageNavigationController, musicWarehouseNavigationController, newFoundingNavigationController, broadCasrPageNavigationController];
  self.delegate = self;
  self.tabBar.tintColor = [UIColor systemGreenColor];
  // iOS26收起tabbar部分
  self.tabBar.layer.borderWidth = 0;

  self.tabBarMinimizeBehavior = UITabBarMinimizeBehaviorOnScrollDown;




  XCMusicPlayerAccessoryView* musicPayerAccessoryView = [[XCMusicPlayerAccessoryView alloc] initWithFrame:CGRectMake(20, 20, self.view.bounds.size.width - 40, 40) withImage:[UIImage imageNamed:@"1.jpeg"] andTitle:@"测试歌曲" withSonger:@"测试歌手" withCondition:NO];
  self.bottomAccessory = [[UITabAccessory alloc] initWithContentView:musicPayerAccessoryView];
  //TODO: 完成附加视图更新，根据tabbar来进行元素更新
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
