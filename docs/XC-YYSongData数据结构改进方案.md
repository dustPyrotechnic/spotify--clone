# XC-YYSongData 数据结构改进方案

> 分析日期: 2026-02-07  
> 分析接口: 网易云音乐 `/album` API  
> 示例URL: https://1390963969-2g6ivueiij.ap-guangzhou.tencentscf.com/album?id=190605791

---

## 当前数据结构

```objc
@interface XC_YYSongData : NSObject <YYModel>
@property (nonatomic, strong) NSString* name;      // 歌曲名
@property (nonatomic, strong) NSString* mainIma;   // 封面图
@property (nonatomic, strong) NSString* songId;    // 歌曲ID
@property (nonatomic, strong) NSString* songUrl;   // 播放URL（后续获取）
@end
```

---

## API 实际返回字段分析

网易云 `/album` 接口返回的歌曲对象关键字段：

```json
{
  "name": "蜃楼",                    // 歌曲名
  "id": 2140776001,                  // 歌曲ID
  "ar": [                            // 艺术家数组
    {"id": 1030001, "name": "周深"}
  ],
  "al": {                            // 专辑信息
    "id": 190605791,
    "name": "反深代词",
    "picUrl": "https://p2.music.126.net/xxx.jpg"
  },
  "dt": 226920,                      // 时长（毫秒）
  "mv": 14711872,                    // MV ID（0表示无MV）
  "alia": [],                        // 别名数组
  "pop": 100,                        // 热度（0-100）
  "no": 2                            // 专辑内序号
}
```

---

## 建议添加的属性

| 属性名 | 类型 | 映射字段 | 说明 |
|--------|------|----------|------|
| **artist** | NSString | `ar[0].name` | 主艺术家名（首个歌手） |
| **artistId** | NSString | `ar[0].id` | 主艺术家ID |
| **artists** | NSArray | `ar` | 所有艺术家数组（保留完整信息） |
| **albumName** | NSString | `al.name` | 专辑名 |
| **albumId** | NSString | `al.id` | 专辑ID |
| **duration** | NSInteger | `dt` | 时长（毫秒） |
| **durationText** | NSString | - | 格式化时长（如 "03:46"，计算属性） |
| **mvId** | NSInteger | `mv` | MV ID（0表示无MV） |
| **alias** | NSArray | `alia` | 歌曲别名列表 |
| **popularity** | NSInteger | `pop` | 热度值（0-100） |
| **trackNumber** | NSInteger | `no` | 专辑内序号 |

---

## 改进后的数据结构

```objc
@interface XC_YYSongData : NSObject <YYModel>

#pragma mark - 基础信息（已有）
@property (nonatomic, copy) NSString *name;        // 歌曲名
@property (nonatomic, copy) NSString *mainIma;     // 封面图（映射 al.picUrl）
@property (nonatomic, copy) NSString *songId;      // 歌曲ID（映射 id）
@property (nonatomic, copy) NSString *songUrl;     // 播放URL（非API返回）

#pragma mark - 艺术家信息（新增）
@property (nonatomic, copy) NSString *artist;      // 主艺术家名
@property (nonatomic, copy) NSString *artistId;    // 主艺术家ID
@property (nonatomic, strong) NSArray *artists;    // 所有艺术家（原始ar数组）

#pragma mark - 专辑信息（新增）
@property (nonatomic, copy) NSString *albumName;   // 专辑名（映射 al.name）
@property (nonatomic, copy) NSString *albumId;     // 专辑ID（映射 al.id）

#pragma mark - 播放信息（新增）
@property (nonatomic, assign) NSInteger duration;       // 时长（毫秒）
@property (nonatomic, assign) NSInteger mvId;           // MV ID
@property (nonatomic, assign) NSInteger trackNumber;    // 专辑内序号
@property (nonatomic, assign) NSInteger popularity;     // 热度（0-100）

#pragma mark - 其他（新增）
@property (nonatomic, strong) NSArray *alias;      // 别名数组

#pragma mark - 计算属性
@property (nonatomic, copy, readonly) NSString *durationText;  // 格式化时长

@end
```

---

## YYModel 映射配置

需要在 `.m` 文件中实现字段映射：

```objc
+ (NSDictionary *)modelCustomPropertyMapper {
    return @{
        @"songId": @"id",
        @"mainIma": @"al.picUrl",
        @"albumName": @"al.name",
        @"albumId": @"al.id",
        @"duration": @"dt",
        @"mvId": @"mv",
        @"trackNumber": @"no",
        @"popularity": @"pop",
        @"alias": @"alia"
        // artist/artistId/artists 需要自定义转换处理
    };
}
```

---

## 使用场景

| 场景 | 需要的字段 |
|------|-----------|
| 播放器显示歌名+歌手 | `name` + `artist` |
| 播放器显示专辑封面 | `mainIma` |
| 播放器显示总时长 | `duration` → 格式化为 `durationText` |
| 歌曲列表展示 | `name` + `artist` + `durationText` |
| 专辑内歌曲排序 | `trackNumber` |
| 判断是否可播放MV | `mvId > 0` |
| 显示歌曲热度 | `popularity` |
| 显示歌曲别名 | `alias` 数组拼接 |

---

## 优先级建议

| 优先级 | 字段 | 理由 |
|--------|------|------|
| P0 | `artist` | 播放器必须显示歌手名 |
| P0 | `duration` + `durationText` | 播放器进度条需要总时长 |
| P1 | `albumName` | 播放器可显示专辑名 |
| P1 | `mvId` | 可扩展MV播放功能 |
| P2 | `artists` / `artistId` | 多歌手场景/跳转歌手页 |
| P2 | `alias` | 显示歌曲副标题 |
| P2 | `popularity` | 歌曲排序/标识热门 |
| P2 | `trackNumber` | 专辑内排序 |

---

## 当前代码中的硬编码问题

找到以下位置需要替换为实际数据：

1. **XCALbumDetailViewController.m** `giveData:ToCell:`
   ```objc
   cell.authorLabel.text = @"赵本山";  // ← 写死，应改为 song.artist
   ```

2. **XCMusicPlayerView.m** `init`
   ```objc
   self.songNameLabel.text = @"歌曲名称";    // ← 写死，应改为 song.name
   self.authorNameLabel.text = @"艺术家";    // ← 写死，应改为 song.artist
   ```

3. **XCMusicPlayerModel.m** `updateLockScreenInfo`
   ```objc
   [dict setObject:@"测试歌手 - Ed Sheeran" forKey:MPMediaItemPropertyArtist]; 
   // ← 应改为 self.nowPlayingSong.artist
   ```

4. **MainTabBarController.m** `viewDidLoad`
   ```objc
   initWithFrame:... andTitle:@"测试歌曲" withSonger:@"测试歌手" 
   // ← 应使用实际歌曲数据
   ```

---

## 实施建议

1. **先添加 P0 字段**（artist、duration）解决播放器显示问题
2. **实现 modelCustomPropertyMapper** 处理字段映射
3. **添加 durationText 计算属性** 格式化时间显示
4. **逐步替换代码中的硬编码字符串**
5. **后续按需添加其他字段**
