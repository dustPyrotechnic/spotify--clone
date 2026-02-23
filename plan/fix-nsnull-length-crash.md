# Fix: `-[NSNull length]: unrecognized selector` Crash

## Context

When the network API returns JSON with `null` values for string fields, YYModel assigns `[NSNull null]` (an NSNull singleton) to the corresponding `NSString *` properties instead of `nil` or `@""`. NSNull is a non-nil object that doesn't respond to NSString methods like `length`, `hasPrefix:`, `stringByReplacingOccurrencesOfString:`, etc. When any of these are called on an NSNull, the app crashes with:

```
-[NSNull length]: unrecognized selector sent to instance 0x1e5d83e80
```

Note: `if (picUrl)` does NOT protect against NSNull — NSNull is a non-nil object and passes the nil check, making it even harder to spot.

---

## Crash Locations & Fixes

### 1. `XC-YYAlbumData.mm` — line 40

**File:** `Spotify - clone/数据结构/XC-YYAlbumData.mm`

**Problem:** `self.coverImgUrl` could be NSNull when YYModel maps from JSON.

```objc
// Current — crashes if coverImgUrl is NSNull
- (BOOL)modelCustomTransformFromDictionary:(NSDictionary *)dic {
    if ([self.coverImgUrl hasPrefix:@"http://"]) {
```

**Fix:** Guard with `isKindOfClass:[NSString class]`:

```objc
- (BOOL)modelCustomTransformFromDictionary:(NSDictionary *)dic {
    if ([self.coverImgUrl isKindOfClass:[NSString class]] &&
        [self.coverImgUrl hasPrefix:@"http://"]) {
```

---

### 2. `XCCategoryCell.m` — line 84 and 101

**File:** `Spotify - clone/5. TabBar附加视图，搜索部分/2. 搜索/XCCategoryCell.m`

**Problem:** `model.previewCoverUrl` and `model.backgroundColorHex` may be NSNull.

```objc
// Line 84
if (model.previewCoverUrl.length > 0) {
// Line 101
if (hexString.length < 7) return UIColor.grayColor;
```

**Fix:**

```objc
// Line 84 — replace condition
if ([model.previewCoverUrl isKindOfClass:[NSString class]] && model.previewCoverUrl.length > 0) {

// Line 101 — replace condition (hexString comes from model.backgroundColorHex)
if (![hexString isKindOfClass:[NSString class]] || hexString.length < 7) return UIColor.grayColor;
```

---

### 3. `XCSearchViewController.mm` — lines 513, 542, 568–569

**File:** `Spotify - clone/5. TabBar附加视图，搜索部分/2. 搜索/XCSearchViewController.mm`

**Problem:** `song.mainIma`, `album.coverImgUrl`, and `picUrl` (from `artist[@"picUrl"]`) may be NSNull.

```objc
// Line 513
NSURL *imgUrl = song.mainIma.length > 0 ? [NSURL URLWithString:song.mainIma] : nil;

// Line 542
NSURL *imgUrl = album.coverImgUrl.length > 0 ? [NSURL URLWithString:album.coverImgUrl] : nil;

// Line 568–569
NSString *picUrl = artist[@"picUrl"] ?: artist[@"img1v1Url"];
NSURL *imgUrl = picUrl.length > 0 ? [NSURL URLWithString:picUrl] : nil;
```

**Fix:**

```objc
// Line 513
NSString *mainIma = [song.mainIma isKindOfClass:[NSString class]] ? song.mainIma : nil;
NSURL *imgUrl = mainIma.length > 0 ? [NSURL URLWithString:mainIma] : nil;

// Line 542
NSString *coverUrl = [album.coverImgUrl isKindOfClass:[NSString class]] ? album.coverImgUrl : nil;
NSURL *imgUrl = coverUrl.length > 0 ? [NSURL URLWithString:coverUrl] : nil;

// Line 568–569
id rawPicUrl = artist[@"picUrl"] ?: artist[@"img1v1Url"];
NSString *picUrl = [rawPicUrl isKindOfClass:[NSString class]] ? rawPicUrl : nil;
NSURL *imgUrl = picUrl.length > 0 ? [NSURL URLWithString:picUrl] : nil;
```

---

### 4. `XCSearchModel.mm` — line 73–74

**File:** `Spotify - clone/5. TabBar附加视图，搜索部分/2. 搜索/XCSearchModel.mm`

**Problem:** `dict[@"picUrl"]` returns NSNull from JSON; `if (picUrl)` doesn't filter it out, so `hasPrefix:` crashes.

```objc
NSString *picUrl = dict[@"picUrl"];
if (picUrl) {
    if ([picUrl hasPrefix:@"http://"]) {
```

**Fix:**

```objc
NSString *picUrl = dict[@"picUrl"];
if ([picUrl isKindOfClass:[NSString class]]) {
    if ([picUrl hasPrefix:@"http://"]) {
```

---

### 5. `XCPersonalViewController.mm` — line 252 (and similar line 335)

**File:** `Spotify - clone/8. 个人播放列表界面/XCPersonalViewController.mm`

**Problem:** `playlist.coverImgUrl` may be NSNull if YYModel mapped a null JSON value.

```objc
if (playlist.coverImgUrl.length > 0) {
```

**Fix:**

```objc
if ([playlist.coverImgUrl isKindOfClass:[NSString class]] && playlist.coverImgUrl.length > 0) {
```

Apply the same fix at line 335 if it has the same pattern.

---

## Files to Modify

| File | Lines |
|------|-------|
| `Spotify - clone/数据结构/XC-YYAlbumData.mm` | 40 |
| `Spotify - clone/5. TabBar附加视图，搜索部分/2. 搜索/XCCategoryCell.m` | 84, 101 |
| `Spotify - clone/5. TabBar附加视图，搜索部分/2. 搜索/XCSearchViewController.mm` | 513, 542, 568–569 |
| `Spotify - clone/5. TabBar附加视图，搜索部分/2. 搜索/XCSearchModel.mm` | 73–74 |
| `Spotify - clone/8. 个人播放列表界面/XCPersonalViewController.mm` | 252, 335 |

## Verification

1. Build the project — should compile without warnings on edited lines
2. Run on simulator, navigate to the Search tab and search for a term that returns results
3. Scroll through Song / Album / Artist segments — no crash
4. Navigate to personal playlist view — no crash when cover URLs are null
5. Check category list (XCCategoryCell) — cells with missing covers fall back to color background without crash
