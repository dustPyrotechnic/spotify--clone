# 内存缓存集成指南

## 1. 文件结构

```
Spotify - clone/
└── 10. 内存缓存/
    ├── XCMusicMemoryCache.h
    └── XCMusicMemoryCache.m
```

## 2. Debug 日志说明

所有日志都带有前缀，方便在 Xcode 控制台筛选：

| 前缀 | 含义 |
|------|------|
| `[MemoryCache]` | 缓存管理器日志 |
| `[PlayerModel]` | 播放器日志 |

### 2.1 缓存相关日志

```
✅  成功/命中
❌  失败/未命中
⚠️  警告
🚀  开始操作
📥  下载完成
📝  写入文件
🧹  清理
ℹ️  信息
🎵  播放相关
```

### 2.2 播放器相关日志

```
🎵  歌曲变更
🎧  创建播放器
▶️  播放
⏸️  暂停
⏭️  下一首
⏮️  上一首
🌐  网络请求
🔮  预加载
🔍  查找
🔒  锁屏信息
```

## 3. 在 XCMusicPlayerModel 中使用

### 修改头文件
```objc
// XCMusicPlayerModel.h 添加导入
#import "XCMusicMemoryCache.h"
```

### 修改播放方法
```objc
// XCMusicPlayerModel.m

- (void)playSong:(XC_YYSongData *)song {
    if (!song) return;
    
    // 1. 检查内存缓存
    NSURL *localURL = [[XCMusicMemoryCache sharedInstance] localURLForSongId:song.songId];
    if (localURL) {
        NSLog(@"[Player] 使用内存缓存播放");
        [self playWithLocalURL:localURL];
        [[XCMusicMemoryCache sharedInstance] setCurrentPlayingSong:song.songId];
        return;
    }
    
    // 2. 网络播放
    [self playWithRemoteURL:[NSURL URLWithString:song.songURL]];
    
    // 3. 后台下载缓存
    [[XCMusicMemoryCache sharedInstance] downloadAndCache:song];
}

- (void)playNext {
    // 预加载下下首
    NSInteger nextIndex = (self.currentIndex + 2) % self.playlist.count;
    XC_YYSongData *nextSong = self.playlist[nextIndex];
    [[XCMusicMemoryCache sharedInstance] downloadAndCache:nextSong];
    
    // 播放下一首
    NSInteger targetIndex = (self.currentIndex + 1) % self.playlist.count;
    [self playSong:self.playlist[targetIndex]];
}
```

## 4. 使用场景示例

### 场景 1：用户快速切歌
```
用户点击歌曲A -> 开始下载到内存 -> 播放
用户点击歌曲B -> 开始下载到内存 -> 播放
用户点击歌曲A -> 直接从内存读取 -> 瞬间播放 ✅
```

### 场景 2：列表循环播放
```
播放歌曲1 -> 自动缓存歌曲2、3到内存
切歌到歌曲2 -> 瞬间播放（已缓存）
切歌到歌曲3 -> 瞬间播放（已缓存）
```

## 5. 限制说明

| 情况 | 行为 |
|------|------|
| App 被杀 | 缓存清空（纯内存） |
| 内存不足 | NSCache 自动释放非当前播放歌曲 |
| 歌曲 > 20MB | 跳过缓存，直接播放 |
| 缓存 > 100MB | NSCache 自动淘汰最久未访问的 |

## 6. 调试技巧

### 查看缓存日志
在 Xcode 控制台搜索 `[MemoryCache]` 筛选所有缓存相关日志。

### 查看播放日志
在 Xcode 控制台搜索 `[PlayerModel]` 筛选所有播放器相关日志。

### 测试缓存是否生效
```objc
// 在任意 ViewController 中调用
[[XCMusicPlayerModel sharedInstance] testMemoryCache];
```

**预期输出**：
```
=================================================================
[PlayerModel] 🧪 开始内存缓存测试
=================================================================
[PlayerModel] 🧪 测试1: 查询未缓存的歌曲...
[MemoryCache] ❌ 未命中缓存: test_song_123
[PlayerModel]    结果: 未缓存✅
[PlayerModel] 🧪 测试2: 写入测试数据...
[MemoryCache] ✅ 已写入缓存: test_song_123 (0.00 MB)
[PlayerModel] 🧪 测试3: 再次查询...
[MemoryCache] ✅ 命中缓存: test_song_123 (大小: 0.00 MB)
[PlayerModel]    结果: 已缓存✅
...
=================================================================
[PlayerModel] 🧪 内存缓存测试结束
=================================================================
```

## 7. 常见问题排查

### 问题 1：缓存始终不命中
**检查点**：
- 查看日志中是否有 `[MemoryCache] ✅ 已写入缓存`
- 检查 songId 是否一致（大小写敏感）
- 检查 `downloadAndCache:` 是否被调用

### 问题 2：预加载不生效
**检查点**：
- 查看日志中是否有 `[PlayerModel] 🔮 预加载歌曲`
- 检查播放列表是否正确设置
- 检查 songUrl 是否有效

### 问题 3：内存警告后播放失败
**检查点**：
- 查看日志中是否有 `[MemoryCache] ⚠️ 收到系统内存警告`
- 确认当前播放歌曲是否被设置保护 `[MemoryCache] 🎵 当前播放歌曲变更`

## 8. 关闭 Debug 日志（生产环境）

如需关闭日志，可在两个文件中添加以下宏：

```objc
// 在 .m 文件顶部添加
#ifdef DEBUG
    #define MCLog(fmt, ...) NSLog(fmt, ##__VA_ARGS__)
#else
    #define MCLog(...) 
#endif

// 然后替换所有 NSLog 为 MCLog
```
