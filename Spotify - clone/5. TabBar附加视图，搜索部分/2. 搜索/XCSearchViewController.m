//
//  XCSearchViewController.m
//  Spotify - clone
//
//  Created by 红尘一笑 on 2025/12/5.
//

#import "XCSearchViewController.h"
#import "XCSearchView.h"
#import "XCSearchModel.h"

@interface XCSearchViewController ()

@end

@implementation XCSearchViewController
- (instancetype) init {
  self = [super init];
  if (self) {
    self.model = [[XCSearchModel alloc] init];

  }
  return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
  self.mainView = [[XCSearchView alloc] init];
  self.searchController = [[UISearchController alloc] init];
  self.navigationItem.searchController = self.searchController;
  self.definesPresentationContext = YES;
  if (self.searchController.active) {
    [self.searchController setActive:NO];
  }


}
- (void) updateSearchResultsForSearchController:(UISearchController *)searchController {

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
