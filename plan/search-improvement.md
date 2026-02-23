# 搜索界面完善计划

## Context

当前搜索界面（`XCSearchViewController.mm`）的架构是完整的（三态状态机、分类浏览、预测/结果视图），但核心搜索逻辑全是占位符：
- `performSearchWithQuery:` 只返回假数据（"歌曲: query"、"专辑: query"）
- 热搜词是硬编码的静态数组，从不调用 API
- 输入时没有实时搜索建议
- 结果单元格是普通 `UITableViewCell`，没有封面图
- 点击结果没有任何操作（只有 NSLog）

底层设施（`XCSearchModel`、`XCNetworkManager`、`XCAlbumDetailCell`、`XCMusicPlayerModel`）全部就绪，只需接通。

---

## 唯一需要修改的文件

`Spotify - clone/5. TabBar附加视图，搜索部分/2. 搜索/XCSearchViewController.mm`

---

## 改动总览（20 处）

### 1. 新增 Import（文件顶部）
```objc
#import "XCMusicPlayerModel.h"
#import "XCAlbumDetailCell.h"
#import <SDWebImage/SDWebImage.h>
```

### 2. Interface Extension 新增属性，删除旧属性

删除：`@property (nonatomic, strong) NSMutableArray *searchResults;`

新增：
```objc
// 热搜与建议
@property (nonatomic, strong) NSArray<NSString *> *hotSearchTerms;
@property (nonatomic, strong) NSArray<NSString *> *currentSuggestions;
@property (nonatomic, assign) BOOL isShowingSuggestions;
@property (nonatomic, strong) NSTimer *suggestionDebounceTimer;

// 三类搜索结果（替换旧 searchResults）
@property (nonatomic, strong) NSArray<XC_YYSongData *>   *songResults;
@property (nonatomic, strong) NSArray<XC_YYAlbumData *>  *albumResults;
@property (nonatomic, strong) NSArray                    *artistResults;

// 分段控件
@property (nonatomic, assign) NSInteger selectedSegmentIndex;
@property (nonatomic, strong) UISegmentedControl *resultSegmentControl;

// 加载指示器 & 防抖查询保护
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, copy)   NSString *lastSearchQuery;
```

### 3. `setupData` — 初始化新属性
```objc
self.songResults = self.albumResults = self.artistResults = @[];
self.hotSearchTerms = self.currentSuggestions = @[];
self.selectedSegmentIndex = 0;
// 移除旧: self.searchResults = [NSMutableArray array];
```

### 4. `setupUI` — 添加分段控件 + 加载指示器 + 注册 XCAlbumDetailCell
- 在 view 顶部（safeArea 下方 8pt）加入 `UISegmentedControl`（歌曲 / 专辑 / 艺人），初始隐藏
- `resultTableView` 顶部约束从 `safeAreaTop` 改为 `segmentControl.bottom + 8`（用 `mas_remakeConstraints`）
- 加入 `UIActivityIndicatorView`（居中于结果区）
- `[_resultTableView registerClass:[XCAlbumDetailCell class] forCellReuseIdentifier:@"SongResultCell"]`

### 5. `transitionToState:animated:` — 随状态显示/隐藏分段控件
```objc
self.resultSegmentControl.hidden = (state != XCSearchStateResults);
// 其余动画代码不变
```

### 6. 新增 `segmentChanged:` 选择器
```objc
- (void)segmentChanged:(UISegmentedControl *)sender {
    self.selectedSegmentIndex = sender.selectedSegmentIndex;
    [self.resultTableView reloadData];
}
```

### 7. 新增 `loadHotSearches`（替换硬编码热搜）
```objc
- (void)loadHotSearches {
    [self.model fetchHotSearchesWithCompletion:^(NSArray<NSString *> *hotWords, NSError *error) {
        self.hotSearchTerms = hotWords.count > 0 ? hotWords : XCHotSearchTerms(); // 失败时降级
        [self.predictiveTableView reloadData];
    }];
}
```

### 8. 新增 `loadSuggestionsForQuery:` + `fireSuggestionTimer:`（防抖 0.3s）
- 每次输入先取消旧 Timer，0.3s 后调用 `fetchSuggestionsWithQuery:`
- 结果存入 `currentSuggestions`，设 `isShowingSuggestions = YES`，reload predictiveTableView

### 9. `searchBarTextDidBeginEditing:` — 加入 `loadHotSearches` 调用
```objc
self.isShowingSuggestions = NO;
self.currentSuggestions = @[];
[self loadHotSearches]; // 新增：API 获取热搜
```

### 10. `searchBarCancelButtonClicked:` — 清理 Timer 和建议状态

### 11. `updateSearchResultsForSearchController:` — 完全替换
输入时**不再立即搜索**，而是：
- 空文本 → `XCSearchStatePredictive`（清空建议）
- 有文本 → 保持 `XCSearchStatePredictive` + 调用 `loadSuggestionsForQuery:`（防抖建议）

### 12. `searchBarSearchButtonClicked:` — 替换为真正触发搜索
```objc
[searchBar resignFirstResponder];
[self saveRecentSearch:query];
[self.suggestionDebounceTimer invalidate];
[self transitionToState:XCSearchStateResults animated:YES];
[self performSearchWithQuery:query];
```
预测表点击词条时也走此同样逻辑。

### 13. `performSearchWithQuery:` — **核心替换**（假数据 → 真 API，三路并发）
```objc
self.lastSearchQuery = query;
[self.loadingIndicator startAnimating];
self.songResults = self.albumResults = self.artistResults = @[];
// 三路并发，用计数器等待全部完成后 reloadData
// 用 lastSearchQuery 防止过期回调覆盖新查询
[self.model searchSongsWithQuery:query offset:0 limit:30 completion:^(...){}];
[self.model searchAlbumsWithQuery:query offset:0 limit:20 completion:^(...){}];
[self.model searchArtistsWithQuery:query offset:0 limit:20 completion:^(...){}];
```

### 14. `numberOfRowsInSection:` — 替换
- 预测表 Section 0：`isShowingSuggestions ? currentSuggestions.count : recentSearches.count`
- 预测表 Section 1：`hotSearchTerms.count`
- 结果表：按 `selectedSegmentIndex` 返回对应数组 count

### 15. `cellForRowAtIndexPath:` — 替换为富单元格
- **歌曲（segment 0）**：复用 `XCAlbumDetailCell`，SDWebImage 加载 `song.mainIma`，显示 `name` + `artist`
- **专辑（segment 1）**：`UITableViewCellStyleSubtitle`，SDWebImage 加载 `album.coverImgUrl`
- **艺人（segment 2）**：`UITableViewCellStyleSubtitle`，圆形头像，加载 `picUrl`/`img1v1Url`
- 预测表：Section 0 根据 `isShowingSuggestions` 动态选取数组和图标（magnifyingglass vs clock）

### 16. `viewForHeaderInSection:` — Section 0 标题动态化
- 正在显示建议时：`@"搜索建议"`（无清除按钮）
- 显示历史时：`@"最近搜索"`（有清除按钮）

### 17. `heightForHeaderInSection:` — Section 1 无数据时返回 `CGFLOAT_MIN`

### 18. 新增 `heightForRowAtIndexPath:` — 歌曲行固定 68pt

### 19. `tableView:didSelectRowAtIndexPath:` — 替换
- 预测表：根据 `isShowingSuggestions` 选取正确词条 → 设搜索栏文字 → 调 `performSearchWithQuery:`
- 结果表歌曲：`XCMusicPlayerModel.playerlist = songResults` → `playMusicWithId:song.songId`
- 结果表专辑/艺人：NSLog 占位（TODO: 推入详情页）

### 20. 保留 `XCHotSearchTerms()` 静态函数作为降级备用

---

## 效果预期

| 场景 | 改动前 | 改动后 |
|------|--------|--------|
| 热搜词 | 8 个硬编码词 | API 实时获取，失败降级 |
| 输入时 | 立即显示假结果 | 防抖 0.3s 显示实时搜索建议 |
| 提交搜索 | 假占位数据 | 真实歌曲/专辑/艺人结果（三路并发） |
| 结果展示 | 纯文字 | 封面图 + 标题 + 副标题（歌曲用 XCAlbumDetailCell） |
| 结果筛选 | 无 | 歌曲 / 专辑 / 艺人 分段控件切换 |
| 点击结果 | NSLog | 歌曲 → 直接播放（XCMusicPlayerModel） |

---

## 验证方式

1. **Build** — 无编译错误
2. **热搜**：进入搜索页，不输入任何内容，Section 1 出现真实热搜词（非硬编码的8个词）
3. **建议**：输入"周"，0.3s 后 Section 0 从"最近搜索"切换为"搜索建议"并显示 API 返回的词条
4. **搜索**：点击建议词或键盘 Search → 切换到结果页，歌曲结果有封面图、标题、艺人名
5. **分段切换**：点击"专辑"tab，显示专辑结果；点击"艺人"tab 显示艺人列表
6. **播放**：点击任意歌曲结果 → mini player 启动，当前曲目更新
