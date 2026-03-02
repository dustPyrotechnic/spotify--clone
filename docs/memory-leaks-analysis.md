# 内存泄漏静态分析报告

> **分析方式**：静态代码审查
> **分析时间**：2026-03-02
> **项目**：Spotify Clone iOS

---

## 优先级说明

| 级别 | 含义 |
|------|------|
| P1 | 立即修复 — 泄漏随运行时间持续累积，影响所有用户 |
| P2 | 本周修复 — 阻止 Cell / ViewController 正常释放 |
| P3 | 计划修复 — 优化性问题，影响相对较轻 |

---

## P1 — 立即修复

### 1. NSTimer 强引用单例（循环引用永不释放）

**文件**：`XCMusicPlayerModel.mm` ≈ 第 874 行，方法 `startLockScreenProgressTimer`

**问题描述**：

单例对象通过 `target:self` 创建 `NSTimer`，形成以下引用链：

```
单例(XCMusicPlayerModel) → NSTimer → target:self → 单例
```

- `NSTimer` 会强引用其 `target`，而 `target` 正是单例自身
- 单例本身永远不会 dealloc
- `NSTimer` 因此永远不会被 invalidate
- 锁屏进度定时器在每次触发后不断累积内存

**修复方向**：

改用 block 版本并配合 `__weak self`：

```objc
__weak typeof(self) weakSelf = self;
self.lockScreenTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                       repeats:YES
                                                         block:^(NSTimer *timer) {
    __strong typeof(weakSelf) strongSelf = weakSelf;
    if (!strongSelf) {
        [timer invalidate];
        return;
    }
    // 更新锁屏进度
}];
```

---

### 2. AVPlayer 时间观察者 Token 丢失

**文件**：`XCMusicPlayerModel.mm` ≈ 第 484 行，方法 `addProgressObserverForPreload`

**问题描述**：

`addPeriodicTimeObserverForInterval:queue:usingBlock:` 返回一个不透明的 token 对象，**必须**保存该 token 才能在不需要时移除观察者：

```objc
// 当前代码（推测）：未保存返回值
[self.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 1)
                                          queue:nil
                                     usingBlock:^(CMTime time) {
    // 回调
}];
```

- 每次调用 `addProgressObserverForPreload` 都会向 `AVPlayer` 注册一个新的时间观察者
- 由于 token 未保存，旧的观察者无法通过 `removeTimeObserver:` 移除
- 切换歌曲 10 次 → AVPlayer 内部累积 10 个未移除的时间观察者
- 每个观察者 block 都持有对象引用，造成持续内存增长

**修复方向**：

1. 在 `XCMusicPlayerModel` 中声明属性保存 token：
   ```objc
   @property (nonatomic, strong) id preloadProgressObserverToken;
   ```
2. 切歌或停止播放时先移除旧观察者：
   ```objc
   if (self.preloadProgressObserverToken) {
       [self.player removeTimeObserver:self.preloadProgressObserverToken];
       self.preloadProgressObserverToken = nil;
   }
   ```

---

## P2 — 本周修复

### 3. Cell 的 completion block 隐式强引用 self（多处）

**涉及文件**：

| 文件 | 大致位置 |
|------|----------|
| `HomePageViewCollectionViewCell.mm` | ≈ 第 74 行 |
| `XCSearchResultCell.mm` | 图片加载处 |
| `XCPersonalViewController.mm` | 图片加载处 |

**问题描述**：

`sd_setImageWithURL:completed:` 的 completion block 内直接引用 `self`：

```objc
[self.imageView sd_setImageWithURL:url completed:^(UIImage *image, NSError *error, ...) {
    self.titleLabel.text = @"loaded"; // ⚠️ 强引用 self
}];
```

- `SDWebImage` 会在内部队列上保留 block，直到图片加载完成
- 如果 Cell 进入复用池后图片仍未加载完成，Cell 被 block 强引用而无法释放
- 大量 Cell 堆积在内存中，无法通过 `UICollectionView` / `UITableView` 的复用机制回收

**修复方向**：

1. 在 `prepareForReuse` 中取消进行中的加载：
   ```objc
   - (void)prepareForReuse {
       [super prepareForReuse];
       [self.imageView sd_cancelCurrentImageLoad];
   }
   ```

2. block 内改用 `__weak self`：
   ```objc
   __weak typeof(self) weakSelf = self;
   [self.imageView sd_setImageWithURL:url completed:^(UIImage *image, NSError *error, ...) {
       weakSelf.titleLabel.text = @"loaded";
   }];
   ```

---

### 4. dispatch_async 嵌套中意外使用 self

**文件**：`XCMusicPlayerModel.mm` ≈ 第 378–404 行

**问题描述**：

外层已经声明了 `weakSelf`，但内层嵌套的 `dispatch_async` block 仍直接使用 `self`：

```objc
__weak typeof(self) weakSelf = self;
dispatch_async(queue, ^{
    // 外层 block 使用 weakSelf ✅
    [weakSelf doSomething];

    dispatch_async(dispatch_get_main_queue(), ^{
        // 内层 block 意外使用 self ⚠️
        self.label.text = @"done";
    });
});
```

- 内层 block 捕获的是 `self`（强引用），而非 `weakSelf`
- 若此时对象应该被释放，内层 block 会阻止 dealloc
- 在异步链较长的场景下（网络请求 → 解码 → 主线程刷新），泄漏窗口更宽

**修复方向**：

内层 block 应使用外层已声明的 `weakSelf`，或在外层 block 开始时先转为 `strongSelf`：

```objc
__weak typeof(self) weakSelf = self;
dispatch_async(queue, ^{
    __strong typeof(weakSelf) strongSelf = weakSelf;
    if (!strongSelf) return;

    [strongSelf doSomething];

    dispatch_async(dispatch_get_main_queue(), ^{
        strongSelf.label.text = @"done"; // strongSelf 在外层 block 作用域内
    });
});
```

---

## P3 — 计划修复

### 5. 网络请求 completion block 未 weakify self

**文件**：`XCNetworkManager.mm` ≈ 第 130 行

**问题**：completion block 直接捕获 `self`，网络请求期间持有者对象无法释放。优先级较低，因为请求完成后 block 即释放。

---

### 6. loadingTasks 字典无超时清理

**文件**：`XCResourceLoaderManager.mm`

**问题**：`loadingTasks` 字典持续累积加载任务对象，没有超时机制或定期清理逻辑。如果某个请求长时间挂起，其占用的资源（包括关联对象）将无法回收。

---

### 7. MPMediaItemArtwork requestHandler 长期持有大图

**文件**：`XCMusicPlayerModel.mm` ≈ 第 778 行

**问题**：`MPMediaItemArtwork` 的 `requestHandler` block 持有解码后的 `UIImage` 对象（可能数 MB），该 block 的生命周期与 `MPNowPlayingInfoCenter` 绑定，在歌曲切换后如果没有主动更新，旧图片会一直存在内存中。

---

## 总结

| 编号 | 文件 | 问题 | 优先级 |
|------|------|------|--------|
| 1 | `XCMusicPlayerModel.mm:874` | NSTimer + 单例循环引用 | P1 |
| 2 | `XCMusicPlayerModel.mm:484` | AVPlayer 时间观察者 token 丢失 | P1 |
| 3 | `HomePageViewCollectionViewCell.mm:74` | Cell block 强引用 self | P2 |
| 3 | `XCSearchResultCell.mm` | Cell block 强引用 self | P2 |
| 3 | `XCPersonalViewController.mm` | 图片加载 block 强引用 self | P2 |
| 4 | `XCMusicPlayerModel.mm:378` | 嵌套 dispatch_async 意外用 self | P2 |
| 5 | `XCNetworkManager.mm:130` | 网络 block 未 weakify | P3 |
| 6 | `XCResourceLoaderManager.mm` | loadingTasks 无超时清理 | P3 |
| 7 | `XCMusicPlayerModel.mm:778` | MPMediaItemArtwork 大图持有 | P3 |
