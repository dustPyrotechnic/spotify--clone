# 搜索系统实现计划

## Context

当前搜索系统只是骨架：`XCSearchModel` 的三个方法全是 TODO（直接返回空数组），热词是硬编码字符串，搜索结果显示的是 mock `NSDictionary`。目标是接入网易云 API，实现完整可用的搜索功能。

---

## 涉及的文件

| 文件 | 改动 |
|------|------|
| `6. 网络请求部分/XCNetworkManager.h` | 声明 3 个新的网易云搜索方法 |
| `6. 网络请求部分/XCNetworkManager.mm` | 实现这 3 个方法 |
| `5. TabBar附加视图，搜索部分/2. 搜索/XCSearchModel.h` | 增加 2 个新方法声明 |
| `5. TabBar附加视图，搜索部分/2. 搜索/XCSearchModel.m` | 实现全部 5 个方法 |
| `5. TabBar附加视图，搜索部分/2. 搜索/XCSearchViewController.m` | 接真实数据 + 优化 UI |

---

## Step 1 — XCNetworkManager：新增搜索网络方法

**在 `.h` 中声明（`#pragma mark - 网易云 API` 区块下）：**

```objc
/// 网易云综合搜索，type: 1=单曲 10=专辑 100=艺人
- (void)searchFromWY:(NSString *)keywords
                type:(NSInteger)type
              offset:(NSInteger)offset
               limit:(NSInteger)limit
      withCompletion:(void(^)(BOOL success, id _Nullable result))completion;

/// 搜索建议（打字时实时调用）
- (void)searchSuggestFromWY:(NSString *)keywords
             withCompletion:(void(^)(BOOL success, NSArray<NSString *> * _Nullable suggestions))completion;

/// 热搜榜（返回关键词字符串数组）
- (void)searchHotDetailFromWYWithCompletion:(void(^)(BOOL success, NSArray<NSString *> * _Nullable hotWords))completion;
```

**在 `.mm` 中实现（复用现有 `AFHTTPSessionManager` 模式，baseURL = `https://1390963969-2g6ivueiij.ap-guangzhou.tencentscf.com`）：**

- `searchFromWY:` → `GET /cloudsearch?keywords=&type=&offset=&limit=`，返回 `responseObject[@"result"]`
- `searchSuggestFromWY:` → `GET /search/suggest?keywords=`，提取 `result.songs[].name` + `result.artists[].name` 合并为字符串数组
- `searchHotDetailFromWYWithCompletion:` → `GET /search/hot/detail`，提取 `data[].searchWord` 为字符串数组

---

## Step 2 — XCSearchModel：实现全部搜索方法

**在 `.h` 增加 2 个声明：**

```objc
/// 搜索建议（实时）
- (void)fetchSuggestionsWithQuery:(NSString *)query
                       completion:(void(^)(NSArray<NSString *> *suggestions, NSError *error))completion;

/// 获取热搜榜
- (void)fetchHotSearchesWithCompletion:(void(^)(NSArray<NSString *> *hotWords, NSError *error))completion;
```

**在 `.m` 实现所有方法（注入 `XCNetworkManager` 调用）：**

### searchSongsWithQuery:
调用 `searchFromWY:type:1`，从 `result[@"songs"]` 手动映射到 `XC_YYSongData`：
```
id      → songId (NSString)
name    → name
ar[0].name → artist
ar[0].id   → artistId (NSString)
al.name    → albumName
al.id      → albumId (NSString)
al.picUrl  → mainIma
dt         → duration
mv         → mvId
pop        → popularity
fee        → fee
```

### searchAlbumsWithQuery:
调用 `searchFromWY:type:10`，从 `result[@"albums"]` 映射到 `XC_YYAlbumData`：
```
id          → albumId (NSString)
name        → name
picUrl      → coverImgUrl
artist.name → artistName
artist.id   → authorId (NSString)
```

### searchArtistsWithQuery:
调用 `searchFromWY:type:100`，从 `result[@"artists"]` 返回原始 `NSDictionary` 数组（当前无艺人详情页）。

### fetchSuggestionsWithQuery:
调用 `searchSuggestFromWY:`，直接回传字符串数组。

### fetchHotSearchesWithCompletion:
调用 `searchHotDetailFromWYWithCompletion:`，直接回传字符串数组。

---

## Step 3 — XCSearchViewController：接真实数据

### 3a. 热搜词改为 API 拉取

- 添加属性 `@property (nonatomic, strong) NSArray<NSString *> *hotSearchTerms;`
- 在 `viewDidLoad` 调用 `[self.model fetchHotSearchesWithCompletion:^(...) { self.hotSearchTerms = hotWords; [self.predictiveTableView reloadData]; }]`
- 将 `XCHotSearchTerms()` 函数替换为 `self.hotSearchTerms`（空时用短暂 loading indicator）

### 3b. 搜索防抖

- 添加属性 `@property (nonatomic, strong) NSTimer *searchDebounceTimer;`
- 在 `updateSearchResultsForSearchController:` 中：先 cancel timer，再延迟 0.4s 调用 `performSearchWithQuery:`

### 3c. 结果区加 UISegmentedControl

- 添加属性 `@property (nonatomic, strong) UISegmentedControl *resultTypeControl;`（单曲 / 专辑 / 艺人）
- 添加 `@property (nonatomic, assign) NSInteger currentResultType;`（默认 0 = 单曲）
- `resultTypeControl` 固定在 `resultTableView` 顶部（非 header，用 tableHeaderView）
- 切换 segment 时清空结果并重新搜索

### 3d. 结果数据改用真实模型

- `searchResults` 保留 `NSMutableArray`，元素改为 `XC_YYSongData` / `XC_YYAlbumData` / `NSDictionary`（艺人）
- 在 `performSearchWithQuery:` 中根据 `currentResultType` 分别调用对应搜索方法

### 3e. 结果 Cell 展示歌曲信息

对 `resultTableView` 的 cell：
- 使用 `UITableViewCellStyleSubtitle`
- `cell.textLabel.text` = 歌曲名 / 专辑名 / 艺人名
- `cell.detailTextLabel.text` = 艺人 + 专辑 / 专辑艺人 / （艺人子标题）
- 封面图：通过 `SDWebImage` 加载到 `cell.imageView`，设置占位图 `music.note` systemImage

### 3f. 结果点击行为

- 点击**单曲**：调用 `[XCMusicPlayerModel sharedInstance] playMusicWithId:song.songId]`（与现有播放器集成）
- 点击**专辑**：push `XCALbumDetailViewController`，传入 albumId 加载歌单详情（复用现有 `getDetailOfAlbumFromWY:ofAlbumId:withCompletion:`）
- 点击**艺人**：暂时 `NSLog`，无详情页

---

## 数据流

```
用户输入 → 防抖 0.4s
    ↓
XCSearchViewController.performSearchWithQuery:
    ↓
XCSearchModel.searchSongsWithQuery: (或 Albums / Artists)
    ↓
XCNetworkManager.searchFromWY:type:offset:limit:
    ↓
GET https://1390963969-2g6ivueiij.ap-guangzhou.tencentscf.com/cloudsearch
    ↓
手动 JSON → XC_YYSongData 映射
    ↓
回调 → self.searchResults → [resultTableView reloadData]
```

---

## 验证方式

1. 运行 App，进入搜索 Tab
2. 进入搜索状态，检查热搜榜是否显示真实网易云数据（非硬编码）
3. 搜索"周杰伦"，验证结果区显示真实歌曲列表（含封面图、艺人名）
4. 切换 Segment 到"专辑"，验证显示专辑结果
5. 点击歌曲，验证底部播放器开始播放
6. 点击专辑，验证跳转到 `XCALbumDetailViewController` 并加载歌曲列表
7. 快速连续输入字符，验证防抖生效（不会每字都触发网络请求）
