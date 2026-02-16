# 音频缓存机制实施计划表

## 项目信息
- **目标**: 实现 NSCache + Tmp + Cache 三层音频缓存架构
- **工期**: 约 25 天
- **开始日期**: 2026-02-12
- **核心设计**: NSCache 存分段，Tmp 存临时完整歌曲，Cache 只存完整歌曲

---

## 核心数据结构（Objective-C 版）

```objc
// ============================================
// XCAudioCacheConst.h
// ============================================
// 分段大小常量 512KB
static const NSUInteger kAudioSegmentSize = 512 * 1024;
static const NSUInteger kAudioCacheMemoryLimit = 100 * 1024 * 1024;  // 100MB
static const NSUInteger kAudioCacheDiskLimit = 1024 * 1024 * 1024;   // 1GB

// 歌曲缓存状态
typedef NS_ENUM(NSInteger, XCAudioFileCacheState) {
    XCAudioFileCacheStateNone = 0,        // 无任何缓存
    XCAudioFileCacheStateInMemory = 1,    // 仅有 L1 分段缓存在内存中
    XCAudioFileCacheStateTempFile = 2,    // 有 L2 临时文件（可能不完整）
    XCAudioFileCacheStateComplete = 3     // 有 L3 完整缓存
};

// ============================================
// XCAudioSegmentInfo.h
// ============================================
// L1 层使用：内存中的分段信息
@interface XCAudioSegmentInfo : NSObject
@property (nonatomic, assign) NSInteger index;        // 分段索引
@property (nonatomic, assign) int64_t offset;         // 起始位置
@property (nonatomic, assign) NSInteger size;         // 分段大小
@property (nonatomic, strong) NSData *data;           // 分段数据（在内存中）
@property (nonatomic, assign) BOOL isDownloaded;      // 是否已下载
@end

// ============================================
// XCAudioSongCacheInfo.h
// ============================================
// L3 层缓存索引模型：已完整缓存的歌曲元数据
// 仅当歌曲确认完整并移动到 L3 后，才会在 index.plist 中创建此记录
@interface XCAudioSongCacheInfo : NSObject
@property (nonatomic, copy) NSString *songId;               // 歌曲 ID
@property (nonatomic, assign) NSInteger totalSize;          // 音频文件总大小
@property (nonatomic, assign) NSTimeInterval cacheTime;     // 缓存到 L3 的时间戳
@property (nonatomic, assign) NSTimeInterval lastPlayTime;  // 最后播放时间戳（LRU 依据）
@property (nonatomic, assign) NSInteger playCount;          // 播放次数统计
@property (nonatomic, copy, nullable) NSString *md5Hash;    // 文件 MD5 校验值（可选）

/// 更新播放时间
- (void)updatePlayTime;
@end
```

**存储结构**:
```
NSCache (L1):
  Key: "{songId}_{segmentIndex}"  Value: NSData

Tmp/MusicTemp/ (L2):
  {songId}.mp3.tmp  - 临时完整歌曲文件（可能不完整，正在下载中）

Library/Caches/MusicCache/ (L3):
  {songId}.mp3      - 完整歌曲文件（确认完整后才存放）
  index.plist       - 缓存索引（XCAudioSongCacheInfo 数组）
```

---

## Phase 1: 基础设施搭建
**时间**: 第 1-2 天  
**状态**: ✅ 已完成

- [x] 1.1 创建 `11. 音频缓存/` 文件夹
- [x] 1.2 创建 `XCAudioCacheConst.h` 定义常量
- [x] 1.3 创建 `XCAudioSegmentInfo.h/m` 分段信息模型
- [x] 1.4 创建 `XCAudioSongCacheInfo.h/m` 歌曲缓存信息模型
- [x] 1.5 创建 `XCAudioCachePathUtils.h/m` 路径管理工具
- [x] 1.6 创建目录结构：
  - `tmp/MusicTemp/` - L2 临时完整歌曲
  - `Library/Caches/MusicCache/` - L3 完整歌曲 + 索引
- [x] 1.7 创建 `XCAudioCachePhase1Test.h/m` 测试类

**验证手段**:
```objc
// 1. 编译测试
// 确保所有头文件无编译错误

// 2. 目录创建测试
XCAudioCachePathUtils *utils = [XCAudioCachePathUtils sharedInstance];
NSLog(@"L2目录: %@", utils.tempDirectory);
NSLog(@"L3目录: %@", utils.cacheDirectory);
// 验证目录实际存在：
// - /tmp/MusicTemp/
// - /Library/Caches/MusicCache/

// 3. 模型类测试
XCAudioSongCacheInfo *info = [[XCAudioSongCacheInfo alloc] initWithSongId:@"test123" totalSize:5242880];
NSLog(@"songId: %@, totalSize: %ld", info.songId, (long)info.totalSize);
// 验证属性初始化正确
```

**新增测试文件**:
```
11. 音频缓存/
├── XCAudioCachePhase1Test.h/m      # Phase 1 测试类
```

**测试方法**:
```objc
// 在 AppDelegate 或 ViewController 中调用
[XCAudioCachePhase1Test runAllTests];
```

**测试输出示例**:
```
[Phase1Test] ========== Phase 1 Test Start ==========
[Phase1Test] Testing constants...
[Phase1Test] Constants OK
[Phase1Test] Testing directory creation...
[Phase1Test] Temp dir: /tmp/MusicTemp/
[Phase1Test] Cache dir: /Library/Caches/MusicCache/
[Phase1Test] Directory creation OK
[Phase1Test] Testing path utils...
[Phase1Test] Temp path: .../test123.mp3.tmp
[Phase1Test] Cache path: .../test123.mp3
[Phase1Test] Path utils OK
[Phase1Test] Testing XCAudioSegmentInfo...
[Phase1Test] SegmentInfo: index=5, offset=1024, size=512000
[Phase1Test] XCAudioSegmentInfo OK
[Phase1Test] Testing XCAudioSongCacheInfo...
[Phase1Test] SongCacheInfo: songId=song456, totalSize=5242880
[Phase1Test] XCAudioSongCacheInfo OK
[Phase1Test] ========== Phase 1 Test End ==========
```

**里程碑**: 基础结构可编译，目录创建成功，测试全部通过

---

## Phase 2: 缓存索引管理器
**时间**: 第 3-4 天  
**状态**: ✅ 已完成

- [x] 2.1 创建 `XCCacheIndexManager.h/m` 单例
- [x] 2.2 实现 `loadIndex` 从 plist 加载缓存索引
- [x] 2.3 实现 `saveIndex` 保存缓存索引到 plist
- [x] 2.4 实现 `addSongCacheInfo:` 添加歌曲缓存记录
- [x] 2.5 实现 `updatePlayTimeForSongId:` 更新播放时间
- [x] 2.6 实现 `removeSongCacheInfo:` 删除记录
- [x] 2.7 实现 `getSongCacheInfo:` 查询歌曲缓存状态
- [x] 2.8 实现 LRU 清理策略（按 lastPlayTime 排序删除）
- [x] 2.9 创建 `XCAudioCachePhase2Test.h/m` 测试类

**验证手段**:
```objc
// 1. 索引读写测试
XCCacheIndexManager *manager = [XCCacheIndexManager sharedInstance];

XCAudioSongCacheInfo *info = [[XCAudioSongCacheInfo alloc] initWithSongId:@"test_song_1" totalSize:5242880];
[info updatePlayTime];

[manager addSongCacheInfo:info];
// 验证 index.plist 文件已创建且内容正确

// 2. 查询测试
XCAudioSongCacheInfo *retrieved = [manager getSongCacheInfo:@"test_song_1"];
NSAssert([retrieved.songId isEqualToString:@"test_song_1"], @"查询失败");

// 3. LRU清理测试
// 添加多个记录，模拟访问时间差异
// 调用 cleanCacheToSize: 测试清理逻辑
// 验证旧记录被删除，新记录保留

// 4. 文件检查
// 沙盒路径验证：Library/Caches/MusicCache/index.plist
```

**里程碑**: 缓存索引读写正常，LRU 清理可用

---

## Phase 3: L1 层 - NSCache 分段缓存
**时间**: 第 5-6 天  
**状态**: ✅ 已完成

- [x] 3.1 创建 `XCMemoryCacheManager.h/m` 单例
- [x] 3.2 实现 `storeSegmentData:forSongId:segmentIndex:` 存储分段
- [x] 3.3 实现 `segmentDataForSongId:segmentIndex:` 读取分段
- [x] 3.4 实现 `hasSegmentForSongId:segmentIndex:` 检查是否存在
- [x] 3.5 实现 `getAllSegmentsForSongId:` 获取所有分段并排序
- [x] 3.6 实现 `clearSegmentsForSongId:` 清空指定歌曲所有分段
- [x] 3.7 实现 `setCurrentSongPriority:` 提升当前歌曲分段优先级
- [x] 3.8 内存警告时清理非当前播放歌曲的分段

**Key 格式**: `@{songId}_{segmentIndex}` (例如: "123456_0")

**新增测试文件**:
```
11. 音频缓存/
├── L1/XCMemoryCacheManager.h/m       # L1 层主管理器 [Phase 3]
└── Tests/XCAudioCachePhase3Test.h/m  # Phase 3 测试 [Phase 3]
```

**测试方法**:
```objc
// 在 AppDelegate 或 ViewController 中调用
[XCAudioCachePhase3Test runAllTests];
```

**测试输出示例**:
```
[Phase3Test] ========== Phase 3 Test Start ==========
[Phase3Test] Testing singleton...
[Phase3Test] Singleton OK
[Phase3Test] Testing store and retrieve segment...
[Phase3Test] Store and retrieve OK
[Phase3Test] Testing hasSegment...
[Phase3Test] hasSegment OK
[Phase3Test] Testing multiple segments...
[Phase3Test] Multiple segments OK
[Phase3Test] Testing getAllSegments...
[Phase3Test] getAllSegments OK
[Phase3Test] Testing clearSegmentsForSong...
[Phase3Test] clearSegmentsForSong OK
[Phase3Test] Testing priority song...
[Phase3Test] Priority song OK
[Phase3Test] Testing cache statistics...
[Phase3Test] Cache statistics OK
[Phase3Test] Testing concurrent access...
[Phase3Test] Concurrent access OK
[Phase3Test] ========== Phase 3 Test End ==========
```

**验证手段**:
```objc
// 1. 分段存储测试
XCMemoryCacheManager *manager = [XCMemoryCacheManager sharedInstance];
NSString *testData = @"Test segment data";
NSData *data = [testData dataUsingEncoding:NSUTF8StringEncoding];

[manager storeSegmentData:data forSongId:@"song_123" segmentIndex:0];

// 2. 分段读取测试
NSData *retrieved = [manager segmentDataForSongId:@"song_123" segmentIndex:0];
NSString *result = [[NSString alloc] initWithData:retrieved encoding:NSUTF8StringEncoding];
NSAssert([result isEqualToString:testData], @"分段读写失败");

// 3. 多分段测试
// 存储 song_123_0, song_123_1, song_123_2
// 调用 getAllSegmentsForSongId: 验证返回数组顺序正确

// 4. 存在性检查
BOOL exists = [manager hasSegmentForSongId:@"song_123" segmentIndex:0];
NSAssert(exists == YES, @"存在性检查失败");

// 5. 清理测试
[manager clearSegmentsForSongId:@"song_123"];
BOOL notExists = [manager hasSegmentForSongId:@"song_123" segmentIndex:0];
NSAssert(notExists == NO, @"清理失败");

// 6. 优先级测试
[manager setCurrentSongPriority:@"song_123"];
// 添加其他歌曲的分段，调用 trimCache，验证优先歌曲分段保留

// 7. 并发测试
// 100 个线程并发存储和读取，验证数据一致性

// 8. 内存监控
// 使用 Instruments 监控内存占用，确保无泄漏
```

**里程碑**: 内存分段缓存读写正常

---

## Phase 4: L3 层 - 完整歌曲缓存
**时间**: 第 7-8 天  
**状态**: ✅ 已完成

### 核心问题：如何从 L1 分段合成完整文件？

```
L1 (NSCache) 中的分段数据:
┌─────────┐  ┌─────────┐  ┌─────────┐
│ song_0  │  │ song_1  │  │ song_2  │  ...
│ 512KB   │  │ 512KB   │  │ 200KB   │
└────┬────┘  └────┬────┘  └────┬────┘
     │            │            │
     └────────────┼────────────┘
                  ▼
           ┌──────────────┐
           │   合并算法    │
           │  (顺序拼接)   │
           └──────┬───────┘
                  ▼
           ┌──────────────┐
           │ 完整歌曲.mp3  │  ← L3 层存储
           │  (1.2MB)     │     Library/Caches/MusicCache/
           └──────────────┘
```

### 任务清单

- [x] 4.1 创建 `XCPersistentCacheManager.h/m` 单例
- [x] 4.2 实现 `writeCompleteSongData:forSongId:` 写入完整歌曲到 L3
- [x] 4.3 实现 `cachedURLForSongId:` 获取完整歌曲文件 URL
- [x] 4.4 实现 `hasCompleteCacheForSongId:` 检查是否有完整缓存
- [x] 4.5 实现 `deleteCacheForSongId:` 删除完整缓存
- [x] 4.6 实现 `totalCacheSize` 统计 L3 总大小
- [x] 4.7 实现 `cleanCacheToSize:` LRU 清理到指定大小

### Phase 3 扩展（为合并做准备）

在 `XCMemoryCacheManager` 中新增方法：

- [x] 4.8 实现 `mergeAllSegmentsForSongId:` 内存合并（返回 NSData）
- [x] 4.9 实现 `writeMergedSegmentsToFile:forSongId:` 流式合并（推荐，省内存）
  - 使用 `NSFileHandle` 逐段追加写入
  - 避免大文件内存峰值

### 合并算法详解

**方案 A：内存合并（小文件 < 50MB）**
```objc
- (NSData *)mergeAllSegmentsForSongId:(NSString *)songId {
    NSArray<XCAudioSegmentInfo *> *segments = [self getAllSegmentsForSongId:songId];
    
    // 计算总大小
    NSInteger totalSize = 0;
    for (XCAudioSegmentInfo *seg in segments) {
        totalSize += seg.data.length;
    }
    
    // 创建缓冲区，顺序追加
    NSMutableData *mergedData = [NSMutableData dataWithCapacity:totalSize];
    for (XCAudioSegmentInfo *seg in segments) {
        [mergedData appendData:seg.data];
    }
    
    return mergedData; // 完整文件数据
}
```

**方案 B：流式合并（大文件推荐，内存友好）**
```objc
- (BOOL)writeMergedSegmentsToFile:(NSString *)filePath forSongId:(NSString *)songId {
    NSArray<XCAudioSegmentInfo *> *segments = [self getAllSegmentsForSongId:songId];
    
    // 创建空文件
    [[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil];
    
    // 使用 FileHandle 流式追加（内存只保持一段 512KB）
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:filePath];
    for (XCAudioSegmentInfo *seg in segments) {
        [handle writeData:seg.data];  // 写一段到磁盘
    }
    [handle closeFile];
    
    return YES;
}
```

### 数据流转流程（L1 → L3）

```
切歌时触发：
┌─────────────────────────────────────────────────────┐
│ 1. XCMusicPlayerModel 调用切歌                      │
│    [player playNextSong]                            │
└─────────────────────┬───────────────────────────────┘
                      ▼
┌─────────────────────────────────────────────────────┐
│ 2. 保存当前歌曲到 L2/L3                              │
│    XCMemoryCacheManager:                            │
│    - getAllSegmentsForSongId: (获取全部分段)         │
│    - writeMergedSegmentsToFile: (合并写入文件)       │
│    - clearSegmentsForSongId: (清空 L1)              │
└─────────────────────┬───────────────────────────────┘
                      ▼
┌─────────────────────────────────────────────────────┐
│ 3. 验证完整性，决定存放位置                           │
│    if (文件大小 == 歌曲总大小) {                     │
│        移动到 L3 (Library/Caches/MusicCache/)       │
│        XCCacheIndexManager addSongCacheInfo: (更新索引)
│    } else {                                         │
│        保留在 L2 (tmp/MusicTemp/)                   │
│    }                                                │
└─────────────────────────────────────────────────────┘
```

**注意**: L3 只存完整歌曲，不存分段！

**新增测试文件**:
```
11. 音频缓存/
├── L3/XCPersistentCacheManager.h/m     # L3 层 [Phase 4] ⬜
└── Tests/XCAudioCachePhase4Test.h/m    # Phase 4 测试 [Phase 4] ⬜
```

**验证手段**:

### A. L3 基础功能测试
```objc
// 1. 完整歌曲写入测试
XCPersistentCacheManager *manager = [XCPersistentCacheManager sharedInstance];
NSString *testSong = @"Complete song data simulation";
NSData *songData = [testSong dataUsingEncoding:NSUTF8StringEncoding];

BOOL success = [manager writeCompleteSongData:songData forSongId:@"song_456"];
NSAssert(success == YES, @"写入失败");

// 2. 文件验证
// 检查沙盒：Library/Caches/MusicCache/song_456.mp3
// 文件大小应与 songData.length 一致

// 3. 读取测试
NSURL *url = [manager cachedURLForSongId:@"song_456"];
NSAssert(url != nil, @"获取URL失败");
NSData *readData = [NSData dataWithContentsOfURL:url];
NSAssert([readData isEqualToData:songData], @"数据不一致");

// 4. 存在性检查
BOOL hasCache = [manager hasCompleteCacheForSongId:@"song_456"];
NSAssert(hasCache == YES, @"存在性检查失败");

// 5. 删除测试
[manager deleteCacheForSongId:@"song_456"];
BOOL notExists = [manager hasCompleteCacheForSongId:@"song_456"];
NSAssert(notExists == NO, @"删除失败");

// 6. 容量统计测试
// 写入多个文件，验证 totalCacheSize 返回正确
```

### B. 分段合并测试（关键）
```objc
// 7. 分段合并测试 - 内存方式
XCMemoryCacheManager *memoryManager = [XCMemoryCacheManager sharedInstance];

// 模拟存储 3 个分段
NSString *songId = @"merge_test_song";
[memoryManager storeSegmentData:[@"Part1_" dataUsingEncoding:NSUTF8StringEncoding] 
                     forSongId:songId segmentIndex:0];
[memoryManager storeSegmentData:[@"Part2_" dataUsingEncoding:NSUTF8StringEncoding] 
                     forSongId:songId segmentIndex:1];
[memoryManager storeSegmentData:[@"Part3" dataUsingEncoding:NSUTF8StringEncoding] 
                     forSongId:songId segmentIndex:2];

// 合并
NSData *merged = [memoryManager mergeAllSegmentsForSongId:songId];
NSString *result = [[NSString alloc] initWithData:merged encoding:NSUTF8StringEncoding];
NSAssert([result isEqualToString:@"Part1_Part2_Part3"], @"合并结果应该是 Part1_Part2_Part3");

// 8. 分段合并测试 - 文件方式（推荐）
NSString *tempPath = [[XCAudioCachePathUtils sharedInstance] tempFilePathForSongId:songId];
BOOL written = [memoryManager writeMergedSegmentsToFile:tempPath forSongId:songId];
NSAssert(written == YES, @"文件合并写入应该成功");

// 验证文件内容
NSData *fileData = [NSData dataWithContentsOfFile:tempPath];
NSString *fileContent = [[NSString alloc] initWithData:fileData encoding:NSUTF8StringEncoding];
NSAssert([fileContent isEqualToString:@"Part1_Part2_Part3"], @"文件内容应该正确");

// 9. 大文件合并测试（验证内存不爆）
// 创建 100 个 512KB 的分段（共 50MB）
// 使用 writeMergedSegmentsToFile: 流式写入
// 验证内存占用不超过 10MB
```

### C. L1 → L3 完整流程测试
```objc
// 10. 端到端流程测试
NSString *songId = @"end_to_end_test";
NSInteger expectedSize = 0;

// 步骤 1: 模拟播放时存储分段到 L1
for (NSInteger i = 0; i < 5; i++) {
    NSData *segment = [[NSString stringWithFormat:@"Segment%ld", (long)i] 
                       dataUsingEncoding:NSUTF8StringEncoding];
    [[XCMemoryCacheManager sharedInstance] storeSegmentData:segment 
                                                   forSongId:songId 
                                                segmentIndex:i];
    expectedSize += segment.length;
}

// 步骤 2: 模拟切歌，合并到 L3
NSString *cachePath = [[XCAudioCachePathUtils sharedInstance] cacheFilePathForSongId:songId];
[[XCMemoryCacheManager sharedInstance] writeMergedSegmentsToFile:cachePath forSongId:songId];

// 步骤 3: 更新索引
XCAudioSongCacheInfo *info = [[XCAudioSongCacheInfo alloc] initWithSongId:songId totalSize:expectedSize];
[[XCCacheIndexManager sharedInstance] addSongCacheInfo:info];

// 步骤 4: 清空 L1
[[XCMemoryCacheManager sharedInstance] clearSegmentsForSongId:songId];

// 步骤 5: 验证 L1 已清空，L3 存在
NSAssert([[XCMemoryCacheManager sharedInstance] segmentCountForSongId:songId] == 0, 
         @"L1 应该清空");
NSAssert([[XCCacheIndexManager sharedInstance] getSongCacheInfo:songId] != nil, 
         @"L3 索引应该存在");
```

### D. 其他测试
```objc
// 11. LRU清理测试
// 设置较小容量限制，触发清理，验证旧文件被删除

// 12. 关键规则验证：
// 检查 Library/Caches/MusicCache/ 下只有 .mp3 完整文件，无分段文件
```

**里程碑**: L3 完整歌曲缓存工作正常，分段合并功能正常

---

## Phase 5: L2 层 - 临时完整歌曲缓存
**时间**: 第 9-10 天  
**状态**: ⬜ 未开始

- [ ] 5.1 创建 `XCTempCacheManager.h/m` 单例
- [ ] 5.2 实现 `writeTempSongData:forSongId:` 追加写入临时文件
- [ ] 5.3 实现 `tempFileURLForSongId:` 获取临时文件 URL
- [ ] 5.4 实现 `isTempFileComplete:expectedSize:` 验证完整性
- [ ] 5.5 实现 `moveToPersistentCache:songId:` L2→L3 移动（验证完整后）
- [ ] 5.6 实现 `deleteTempFileForSongId:` 删除临时文件
- [ ] 5.7 实现定期清理过期临时文件（7 天）

**临时文件格式**: `{songId}.mp3.tmp`

**验证手段**:
```objc
// 1. 临时文件写入测试
XCTempCacheManager *manager = [XCTempCacheManager sharedInstance];
NSString *part1 = @"Part 1 data ";
NSString *part2 = @"Part 2 data";
NSData *data1 = [part1 dataUsingEncoding:NSUTF8StringEncoding];
NSData *data2 = [part2 dataUsingEncoding:NSUTF8StringEncoding];

[manager writeTempSongData:data1 forSongId:@"song_789"];
[manager writeTempSongData:data2 forSongId:@"song_789"];

// 2. 文件验证
// 检查沙盒：tmp/MusicTemp/song_789.mp3.tmp
// 文件内容应为 "Part 1 data Part 2 data"

// 3. 完整性验证测试
// 传入正确 size，验证返回 YES
// 传入错误 size，验证返回 NO

// 4. L2→L3 流转测试
BOOL moved = [manager moveToPersistentCache:@"song_789"];
NSAssert(moved == YES, @"移动失败");

// 验证：
// - tmp/MusicTemp/song_789.mp3.tmp 已不存在
// - Library/Caches/MusicCache/song_789.mp3 存在且内容正确

// 5. 删除测试
[manager deleteTempFileForSongId:@"song_789"];
// 验证 tmp 目录下无此文件

// 6. 过期清理测试
// 创建临时文件，修改创建时间为 8 天前
// 调用清理方法，验证旧文件被删除
```

**里程碑**: L2 临时缓存工作正常，L2→L3 流转正确

---

## Phase 6: 缓存管理器整合
**时间**: 第 11-13 天  
**状态**: ⬜ 未开始

- [ ] 6.1 创建 `XCAudioCacheManager.h/m` 主管理器单例
- [ ] 6.2 实现 `cachedURLForSongId:` 三级查询（L3→L2→返回 nil）
- [ ] 6.3 实现 `storeSegment:forSongId:segmentIndex:` 写入 L1
- [ ] 6.4 实现 `getSegmentForSongId:segmentIndex:` 查询分段（L1→网络）
- [ ] 6.5 实现 `finalizeCurrentSong:` L1→L2 流转（切歌时）
  - 将 L1 所有分段合并写入 L2 临时文件
  - 清空 L1 分段
- [ ] 6.6 实现 `confirmCompleteSong:expectedSize:` L2→L3 流转
  - 验证 L2 文件完整性
  - 移动到 L3
  - 更新索引
- [ ] 6.7 实现 `clearAllCache` 清理所有缓存

**数据流转**:
```
播放中 → L1 (NSCache 分段)
   ↓ 切歌
L1 分段合并 → L2 临时完整文件
   ↓ 确认完整
L2 → L3 永久完整文件
```

**验证手段**:
```objc
// 1. L3查询测试
// 预置 L3 文件，验证 cachedURLForSongId: 返回正确 URL

// 2. L2查询测试
// 删除 L3 文件，保留 L2 文件，验证返回 L2 URL

// 3. L1分段存储测试
NSData *segData = [@"segment" dataUsingEncoding:NSUTF8StringEncoding];
[[XCAudioCacheManager sharedInstance] storeSegment:segData 
                                           forSongId:@"song_abc" 
                                        segmentIndex:0];
// 验证 NSCache 中存在 "song_abc_0"

// 4. L1→L2流转测试（关键）
// 存储多个分段到 L1
[[XCAudioCacheManager sharedInstance] storeSegment:seg1 forSongId:@"song_def" segmentIndex:0];
[[XCAudioCacheManager sharedInstance] storeSegment:seg2 forSongId:@"song_def" segmentIndex:1];
[[XCAudioCacheManager sharedInstance] storeSegment:seg3 forSongId:@"song_def" segmentIndex:2];

// 调用 finalizeCurrentSong:
[[XCAudioCacheManager sharedInstance] finalizeCurrentSong:@"song_def"];

// 验证：
// - L1 中 "song_def_*" 分段已清空
// - tmp/MusicTemp/song_def.mp3.tmp 存在且内容为分段合并结果

// 5. L2→L3流转测试（关键）
NSInteger expectedSize = seg1.length + seg2.length + seg3.length;
[[XCAudioCacheManager sharedInstance] confirmCompleteSong:@"song_def" 
                                            expectedSize:expectedSize];

// 验证：
// - tmp/MusicTemp/song_def.mp3.tmp 已删除
// - Library/Caches/MusicCache/song_def.mp3 存在
// - index.plist 中 song_def 状态为 Complete

// 6. 清理测试
[[XCAudioCacheManager sharedInstance] clearAllCache];
// 验证所有层级缓存已清空
```

**里程碑**: 三级缓存联动正常，数据流转无误

---

## Phase 7: 预加载机制
**时间**: 第 14-15 天  
**状态**: ⬜ 未开始

- [ ] 7.1 创建 `XCPreloadManager.h/m` 预加载管理器
- [ ] 7.2 实现 `preloadSong:songId:` 开始预加载
- [ ] 7.3 实现分段预加载策略（优先加载前 3 个分段确保立即播放）
- [ ] 7.4 实现 `cancelPreloadForSongId:` 取消预加载
- [ ] 7.5 实现并发控制（最多 1 个预加载任务）
- [ ] 7.6 实现预加载进度回调

**预加载策略**:
- 下一首：预加载前 3 个分段（约 1.5MB，确保立即播放）
- 继续预加载后续分段到 L1

**验证手段**:
```objc
// 1. 预加载启动测试
XCPreloadManager *manager = [XCPreloadManager sharedInstance];
[manager preloadSong:@"song_xyz" priority:XCAudioPreloadPriorityHigh];

// 验证网络请求已发起
// 验证 L1 中开始存入分段 "song_xyz_0", "song_xyz_1"...

// 2. 取消测试
[manager cancelPreloadForSongId:@"song_xyz"];
// 验证网络请求已取消
// 验证无新的分段写入

// 3. 并发控制测试
// 同时启动 3 个预加载，验证最多只有 1 个在执行

// 4. 优先级测试
// 高优先级任务先执行，低优先级排队

// 5. 进度回调测试
// 验证进度回调正常触发，数据准确
```

**里程碑**: 预加载工作正常

---

## Phase 8: 系统集成
**时间**: 第 16-18 天  
**状态**: ⬜ 未开始

- [ ] 8.1 修改 `XCMusicPlayerModel.m`，引入 `XCAudioCacheManager`
- [ ] 8.2 播放前检查 `cachedURLForSongId:`：
  - 有 L3 缓存 → 直接用本地文件播放
  - 有 L2 缓存 → 用 L2 临时文件播放
  - 无缓存 → 网络播放，边下边存到 L1
- [ ] 8.3 在 `playNextSong` 中：
  - 调用 `finalizeCurrentSong:` 保存上一首到 L2
  - 调用 `confirmCompleteSong:` 验证并移动到 L3
- [ ] 8.4 播放进度 50% 时触发下一首预加载
- [ ] 8.5 修改 `XCMusicMemoryCache.h/m`，保留接口，内部转发到新系统
- [ ] 8.6 验证现有调用点兼容

**验证手段**:
```objc
// 1. L3播放测试
// 预置 L3 完整缓存
// 调用 playMusicWithId: 
// 验证：使用本地文件播放，无网络请求

// 2. L2播放测试
// 只保留 L2 临时文件
// 验证：使用临时文件播放

// 3. 网络播放测试
// 无缓存时
// 验证：发起网络请求，同时分段存入 L1

// 4. 切歌流转测试（关键）
// 播放歌曲 A，切换到歌曲 B
// 验证：
// - A 的分段已合并到 L2 (A.mp3.tmp)
// - 如果 A 完整，已移动到 L3
// - 开始预加载 C（下下首）

// 5. 50%触发测试
// 模拟播放进度到 50%
// 验证：触发下一首预加载

// 6. 接口兼容测试
// 确保现有调用 XCMusicMemoryCache 的代码正常工作
```

**里程碑**: 播放器集成完成

---

## Phase 9: 资源加载器增强（可选）
**时间**: 第 19-21 天  
**状态**: ⬜ 未开始

- [ ] 9.1 增强 `XCResourceLoaderManager`
- [ ] 9.2 实现 Range 请求解析
- [ ] 9.3 查询 L1 分段缓存响应请求
- [ ] 9.4 未命中时网络请求，同时写入 L1
- [ ] 9.5 组装分段数据响应播放器

**验证手段**:
```objc
// 1. Range解析测试
// 输入 "bytes=0-524287"，验证解析出 offset=0, length=524288
// 输入 "bytes=524288-1048575"，验证解析正确

// 2. 缓存命中测试
// 预置 L1 分段
// 验证：直接返回缓存数据，无网络请求

// 3. 缓存未命中测试
// 无缓存时
// 验证：发起网络请求，数据写入 L1，同时返回给播放器

// 4. 分段组装测试
// 请求跨越多个分段的范围
// 验证：正确组装多个分段数据响应
```

**里程碑**: 边下边播功能完整（可选）

---

## Phase 10: 测试与优化
**时间**: 第 22-24 天  
**状态**: ⬜ 未开始

- [ ] 10.1 单元测试：分段存储、合并、流转
- [ ] 10.2 集成测试：三级缓存查询、切歌流转
- [ ] 10.3 性能测试：各层读取耗时
- [ ] 10.4 边界测试：快速切歌、大文件、磁盘满
- [ ] 10.5 稳定性测试：连续播放、内存警告
- [ ] 10.6 性能优化

**性能目标**:
- L1 读取 < 1ms
- L2/L3 读取 < 20ms
- 切歌响应 < 100ms

**验证手段**:
```objc
// 1. 单元测试执行
// 运行所有单元测试，确保 100% 通过

// 2. 性能测试
// L1读取 1000 次，平均耗时 < 1ms
// L2/L3读取 100 次，平均耗时 < 20ms
// 切歌操作 50 次，平均耗时 < 100ms

// 3. 弱网测试
// 使用 Network Link Conditioner 模拟 3G 网络
// 验证播放流畅，缓存正常工作

// 4. 快速切歌测试
// 1 秒内连续切换 10 次
// 验证无崩溃，状态正确

// 5. 大文件测试
// 测试 20MB+ 歌曲
// 验证分段存储正常，无内存问题

// 6. 内存警告测试
// 模拟内存警告
// 验证 L1 被清理，播放继续正常

// 7. 磁盘满测试
// 模拟磁盘满场景
// 验证优雅降级，不崩溃

// 8. 长时间播放测试
// 连续播放 50 首歌曲
// 验证无内存泄漏，缓存管理正常
```

**里程碑**: 测试通过

---

## Phase 11: 文档与收尾
**时间**: 第 25 天  
**状态**: ⬜ 未开始

- [ ] 11.1 头文件注释
- [ ] 11.2 API 使用文档
- [ ] 11.3 代码审查
- [ ] 11.4 清理旧代码
- [ ] 11.5 更新 AGENTS.md

**里程碑**: 项目收尾

---

## 核心工作流程

### 1. 播放时查找缓存
```
播放请求 songId
    │
    ▼
检查 L3 (Cache/{songId}.mp3)
    │
    ├── 存在 → 直接播放
    │
    └── 不存在
         ▼
    检查 L2 (Tmp/{songId}.mp3.tmp)
         │
         ├── 存在 → 播放临时文件
         │
         └── 不存在 → 网络播放，边下边存到 L1
```

### 2. 边下边存流程
```
AVPlayer 请求数据 Range: bytes=0-524287
    │
    ▼
检查 L1 NSCache "{songId}_0"
    │
    ├── 存在 → 直接返回
    │
    └── 不存在
         ▼
    网络请求该分段
         │
         ▼
    写入 L1 NSCache "{songId}_0"
         │
         ▼
    返回数据给播放器
```

### 3. 切歌时数据流转
```
切歌：当前 A → 下一首 B
    │
    ▼
1. 保存歌曲 A：
   L1 中 A 的所有分段 → 合并写入 L2 (A.mp3.tmp)
   使用 XCMemoryCacheManager 的 writeMergedSegmentsToFile:forSongId: 方法
   流式合并，顺序：seg_0 + seg_1 + seg_2 + ...
   清空 L1 中 A 的分段
    │
    ▼
2. 验证歌曲 A：
   检查 A.mp3.tmp 文件大小 == 歌曲总大小？
   是 → 移动到 L3 (A.mp3)，更新索引
   否 → 保留在 L2，下次继续下载
    │
    ▼
3. 加载歌曲 B：
   检查 L3 → L2 → 网络
   开始播放 B，同时预加载下下首 C
```

---

## 关键规则

### 存储规则
1. **L3 (Cache) 只存完整歌曲**，文件名为 `{songId}.mp3`
2. **L2 (Tmp) 存临时完整歌曲**，文件名为 `{songId}.mp3.tmp`，可能不完整
3. **L1 (NSCache) 只存分段**，Key 为 `{songId}_{segmentIndex}`

### 数据流转规则
4. **切歌时必须触发 L1→L2 流转**
5. **分段合并算法**：`seg_0 + seg_1 + seg_2 + ...` 顺序拼接
   - 使用 `writeMergedSegmentsToFile:forSongId:` 流式写入
   - 内存占用保持 512KB（一段大小），不随文件大小增长
6. **确认完整后才能 L2→L3 流转**
   - 文件大小 == 歌曲总大小（HTTP Content-Length）
   - 或音频文件头尾标记完整

### 安全规则
7. **合并过程中不能清空 L1**
   - 先写入文件，验证成功后，再 clearSegmentsForSongId:
8. **大文件优先使用流式合并**
   - 避免 `mergeAllSegmentsForSongId:` 内存方式（可能导致内存峰值）

---

## 每日检查清单

- [ ] 今日任务完成
- [ ] 代码可编译
- [ ] L3 只存完整歌曲
- [ ] 内存占用正常

---

## 文件清单

### 新建文件（14 个，Phase 1-3 已完成）
```
11. 音频缓存/
├── XCAudioCacheConst.h                 # 常量 [Phase 1] ✅
├── XCAudioCachePathUtils.h/m           # 路径管理工具 [Phase 1] ✅
├── L1/
│   ├── XCAudioSegmentInfo.h/m          # 分段信息 [Phase 1] ✅
│   ├── XCMemoryCacheManager.h/m        # L1 层 [Phase 3] ✅
│   └── XCMemoryCacheManager+Merge.h/m  # 分段合并扩展 [Phase 4] ✅
├── L3/
│   ├── XCAudioSongCacheInfo.h/m        # 歌曲缓存信息 [Phase 1] ✅
│   ├── XCCacheIndexManager.h/m         # 索引管理器 [Phase 2] ✅
│   └── XCPersistentCacheManager.h/m    # L3 层 [Phase 4] ✅
├── Tests/
│   ├── XCAudioCachePhase1Test.h/m      # Phase 1 测试 [Phase 1] ✅
│   ├── XCAudioCachePhase2Test.h/m      # Phase 2 测试 [Phase 2] ✅
│   ├── XCAudioCachePhase3Test.h/m      # Phase 3 测试 [Phase 3] ✅
│   └── XCAudioCachePhase4Test.h/m      # Phase 4 测试 [Phase 4] ✅
├── L2/
│   └── XCTempCacheManager.h/m          # L2 层 [Phase 5] ⬜
├── XCAudioCacheManager.h/m             # 主管理器 [Phase 6] ⬜
└── XCPreloadManager.h/m                # 预加载管理器 [Phase 7] ⬜
```

### 修改文件（2 个）
```
5. TabBar附加视图，搜索部分/1. 音乐播放器/音乐播放详细页面/
└── XCMusicPlayerModel.m                # 集成新缓存

10. 内存缓存/
└── XCMusicMemoryCache.m                # 转发调用
```

---

**计划版本**: 3.0  
**更新日期**: 2026-02-12  
**预计工期**: 25 天
