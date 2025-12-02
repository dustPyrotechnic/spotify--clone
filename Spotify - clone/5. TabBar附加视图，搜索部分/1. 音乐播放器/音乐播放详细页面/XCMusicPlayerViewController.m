//
//  XCMusicPlayerViewController.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/12/1.
//

#import "XCMusicPlayerViewController.h"
#import "XCMusicPlayerView.h"
#import "XCMusicPlayerModel.h"

@interface XCMusicPlayerViewController ()

@end

@implementation XCMusicPlayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
  self.musicPlayerModel = [XCMusicPlayerModel sharedInstance];
  self.mainView = [[XCMusicPlayerView alloc] init];
  self.mainView.frame = self.view.bounds;
  [self.view addSubview:_mainView];

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
