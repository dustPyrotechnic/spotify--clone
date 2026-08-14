# Instruments 使用指南（针对本项目）

> **适用场景**：排查 Spotify Clone iOS 项目内存泄漏和内存占用过高问题
> **Xcode 版本**：16.x

---

## 一、打开 Instruments

**方式一（推荐）**：菜单栏 `Xcode → Product → Profile`，快捷键 `⌘ + I`

**方式二**：先 `⌘ + B` 编译成功后，从 Xcode 启动模拟器，再 `⌘ + I`

> 注意：Instruments 需要在 **Release** 或 **Profiling** 配置下运行才能得到准确数据。默认 `⌘ + I` 会自动使用 Profiling 配置。

---

## 二、模板选择

进入 Instruments 后会弹出模板选择器，根据排查目标选择：

| 排查场景 | 推荐模板 | 说明 |
|----------|----------|------|
| 找循环引用导致的对象泄漏 | **Leaks** | 定期扫描堆，标记无法从根对象访问的对象 |
| 看内存整体增长趋势 | **Allocations** | 记录所有内存分配，支持按类型统计 |
| 定位野指针崩溃（EXC_BAD_ACCESS） | **Zombies** | 将已释放对象保留为僵尸对象，捕获悬空指针 |
| 快速查看整体内存压力 | **Activity Monitor** | 进程级别的内存/CPU 概览 |

---

## 三、Leaks 模板 — 排查循环引用

### 3.1 操作步骤

1. 选择 **Leaks** 模板，点击 **Choose**
2. 确认目标设备和应用已正确选中
3. 点击左上角红色圆形按钮 **Record** 开始录制
4. 在 App 中进行以下操作（触发潜在泄漏）：
   - 反复切换歌曲（至少 5 次）
   - 上下滚动首页列表
   - 进入歌曲详情页，然后返回（反复 3 次以上）
   - 进入搜索页，搜索并点击结果
   - 退出到后台再重新进入前台
5. 等待约 5–10 秒，Instruments 会自动执行一次泄漏扫描

### 3.2 读取结果

- 时间轴上出现**红色菱形 ◆**标记 → 发现泄漏
- 点击红色菱形，切换到底部的 **Leak Checks** 面板
- 面板中列出泄漏的类名、泄漏数量和泄漏大小
- 点击某条泄漏记录，右侧显示**调用栈**（Stack Trace）

### 3.3 定位到源码

1. 勾选右上角 **Hide System Libraries**（隐藏系统库调用）
2. 调用栈中加粗显示的帧是项目代码
3. **双击**该行 → 直接跳转到 Xcode 对应源码行

### 3.4 本项目重点关注

- `XCMusicPlayerModel` — 确认是否出现在泄漏列表中（NSTimer 循环引用）
- `NSTimer` — 若出现泄漏，关联查看调用栈是否来自 `startLockScreenProgressTimer`
- `AVPlayerItem` — 切歌后旧的 item 是否正常释放
- `HomePageViewCollectionViewCell` / `XCSearchResultCell` — Cell 是否因 block 无法释放

---

## 四、Allocations 模板 — 看内存增长趋势

### 4.1 操作步骤

1. 选择 **Allocations** 模板，点击 **Record**
2. 进行"切歌压力测试"：快速切换歌曲 10 次，每次间隔约 2 秒
3. 同时观察时间轴上的内存曲线

### 4.2 正常 vs 异常判断

| 情况 | 说明 |
|------|------|
| 内存升高后回落（锯齿状） | 正常，GC/ARC 在工作 |
| 内存持续升高，不回落 | 异常，存在泄漏或大对象未释放 |
| 内存突然大幅升高后不降 | 异常，大图/大数据未释放 |

### 4.3 Statistics 视图排查

1. 底部切换到 **Statistics** 标签
2. 点击 **# Net** 列标题，按净存活对象数**降序排列**
3. 重点关注以下类型：

   | 类名 | 可能问题 |
   |------|----------|
   | `AVPlayerItem` | 切歌后旧 item 未释放，token 泄漏 |
   | `XCMusicPlayerModel` | 单例本身的关联对象持续增长 |
   | `UIImage` | 专辑图片缓存无限制 |
   | `HomePageViewCollectionViewCell` | Cell 因 block 引用未进入复用池 |

4. 点击某个类名 → 展开查看所有存活实例的分配调用栈

---

## 五、Memory Graph — 最快定位循环引用

**无需 Instruments**，直接在 Xcode 调试时使用。

### 5.1 操作步骤

1. 在 Xcode 中正常运行 App（`⌘ + R`，Debug 模式）
2. 在 App 中操作一段时间（切歌、滚动列表等）
3. 点击 Xcode 底部调试栏的**内存图标**（Debug Memory Graph，三个圆圈连线图标）
4. Xcode 会暂停 App 并生成内存图快照

### 5.2 查找循环引用

1. 左侧对象列表中搜索 `XCMusicPlayerModel`
2. 查看右侧的对象引用图
3. 若出现**两个节点互相指向**（A → B → A），即为循环引用
4. 同样搜索 `NSTimer`，确认是否被单例持有

### 5.3 过滤技巧

- 左上角勾选 **Only show leak objects**（仅显示泄漏对象），排除正常对象的干扰
- 右键点击某个节点 → **Reveal in Navigator** 可跳转到对应实例

---

## 六、模拟内存警告 — 验证缓存回收

用于验证 `didReceiveMemoryWarning` / `NSCache` 的驱逐逻辑是否生效。

### 6.1 操作步骤

1. 在 Xcode 中运行 App
2. 菜单栏：`Debug → Simulate Memory Warning`
3. 观察 App 是否正常继续工作（不崩溃）

### 6.2 配合 Allocations 验证

1. 先用 Allocations 录制内存状态（记录基准值）
2. 触发 `Simulate Memory Warning`
3. 观察时间轴：**内存应明显下降**
4. 若内存不下降，说明 `didReceiveMemoryWarning` 中的缓存清理逻辑未执行或无效

---

## 七、快速排查流程（推荐顺序）

```
1. Memory Graph（Xcode 内置）
   → 用 5 分钟确认是否存在循环引用
   → 搜索 XCMusicPlayerModel、NSTimer

2. Leaks 模板
   → 切歌 + 滚动列表，确认红色菱形是否出现
   → 重点看 Cell 类和 PlayerModel

3. Allocations 模板
   → 切歌 10 次，观察内存曲线是否持续上升
   → Statistics 视图按 # Net 排序

4. 触发内存警告
   → 验证缓存清理是否生效
```

---

## 八、常见误区

| 误区 | 正确理解 |
|------|----------|
| Instruments 没有红色菱形就说明没有泄漏 | 循环引用对象仍然"可达"，不会被 Leaks 标记；需要用 Memory Graph 查 |
| 内存升高就一定是泄漏 | 正常的缓存策略也会占用内存；关键是内存能否在压力下回落 |
| 只在 Debug 模式下测试 | 必须在 Profiling 或 Release 配置下测试，Debug 模式有额外内存开销 |
| 只测一次就判断没问题 | 泄漏通常需要重复操作才能累积到可观测的量级 |
