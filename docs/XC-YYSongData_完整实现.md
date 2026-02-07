# XC-YYSongData 完整实现

> 更新日期: 2026-02-07  
> 说明: 添加 artist、duration、albumName 等属性，完整 YYModel 配置

---

## XC-YYSongData.h

```objc
//
//  XC-YYSongData.h
//  Spotify - clone
//

#import <Foundation/Foundation.h>
#import <YYModel/YYModel.h>

NS_ASSUME_NONNULL_BEGIN

@interface XC_YYSongData : NSObject <YYModel>

#pragma mark - 基础信息
/// 歌曲名称
@property (nonatomic, copy) NSString *name;
/// 歌曲ID
@property (nonatomic, copy) NSString *songId;
/// 专辑封面URL（映射 al.picUrl）
@property (nonatomic, copy) NSString *mainIma;

#pragma mark - 艺术家信息（新增）
/// 主艺术家名称（取 ar[0].name）
@property (nonatomic, copy) NSString *artist;
/// 主艺术家ID（取 ar[0].id）
@property (nonatomic, copy) NSString *artistId;
/// 所有艺术家数组（原始 ar 数组）
@property (nonatomic, strong, nullable) NSArray *artists;

#pragma mark - 专辑信息（新增）
/// 专辑名称（映射 al.name）
@property (nonatomic, copy) NSString *albumName;
/// 专辑ID（映射 al.id）
@property (nonatomic, copy) NSString *albumId;

#pragma mark - 播放信息（新增）
/// 歌曲时长，单位毫秒（映射 dt）
@property (nonatomic, assign) NSInteger duration;
/// MV ID，0表示无MV（映射 mv）
@property (nonatomic, assign) NSInteger mvId;
/// 专辑内序号（映射 no）
@property (nonatomic, assign) NSInteger trackNumber;

#pragma mark - 其他信息（可选）
/// 歌曲别名数组（如 Live版, 插曲等）（映射 alia）
@property (nonatomic, strong, nullable) NSArray *alias;
/// 热度值 0-100（映射 pop）
@property (nonatomic, assign) NSInteger popularity;
/// 付费类型：0=免费, 1=VIP, 4=付费（映射 fee）
@property (nonatomic, assign) NSInteger fee;

#pragma mark - 运行时赋值
/// 播放URL（非API返回，需通过 /song/url/v1 获取）
@property (nonatomic, copy, nullable) NSString *songUrl;

#pragma mark - 计算属性（只读）
/// 格式化时长，如 "03:46"
@property (nonatomic, copy, readonly) NSString *durationText;
/// 是否可播放MV
@property (nonatomic, assign, readonly) BOOL hasMV;
/// 付费类型描述
@property (nonatomic, copy, readonly) NSString *feeDescription;

@end

NS_ASSUME_NONNULL_END
```

---

## XC-YYSongData.m

```objc
//
//  XC-YYSongData.m
//  Spotify - clone
//

#import "XC-YYSongData.h"

@implementation XC_YYSongData

#pragma mark - YYModel 配置

/// 字段映射：将 JSON 字段名映射到属性名
+ (NSDictionary<NSString *, id> *)modelCustomPropertyMapper {
    return @{
        // 基础字段映射
        @"songId": @"id",
        @"mainIma": @"al.picUrl",
        
        // 专辑信息映射（嵌套对象）
        @"albumName": @"al.name",
        @"albumId": @"al.id",
        
        // 播放信息映射
        @"duration": @"dt",
        @"mvId": @"mv",
        @"trackNumber": @"no",
        
        // 其他信息映射
        @"popularity": @"pop",
        @"alias": @"alia",
        @"fee": @"fee"
        
        // 注意：artist 和 artistId 需要自定义处理，见下方
    };
}

/// 自定义转换：处理 artists 数组，提取主艺术家
- (BOOL)modelCustomTransformFromDictionary:(NSDictionary *)dic {
    // 处理 artists 数组（ar 字段）
    NSArray *arArray = dic[@"ar"];
    if (arArray && [arArray isKindOfClass:[NSArray class]] && arArray.count > 0) {
        // 保存完整数组
        self.artists = arArray;
        
        // 提取第一个作为主艺术家
        NSDictionary *firstArtist = arArray[0];
        if ([firstArtist isKindOfClass:[NSDictionary class]]) {
            // 歌手名
            NSString *artistName = firstArtist[@"name"];
            if (artistName) {
                self.artist = artistName;
            }
            // 歌手ID
            NSNumber *artistIdNum = firstArtist[@"id"];
            if (artistIdNum) {
                self.artistId = [artistIdNum stringValue];
            }
        }
    }
    
    // 如果没有歌手，给一个默认值
    if (!self.artist || self.artist.length == 0) {
        self.artist = @"未知艺术家";
    }
    
    // 如果没有专辑名，给一个默认值
    if (!self.albumName || self.albumName.length == 0) {
        self.albumName = @"未知专辑";
    }
    
    return YES;
}

#pragma mark - 计算属性

/// 格式化时长：毫秒 -> "03:46"
- (NSString *)durationText {
    // 小于等于0时返回 "00:00"
    if (self.duration <= 0) {
        return @"00:00";
    }
    
    // 转换为秒
    NSInteger totalSeconds = self.duration / 1000;
    NSInteger minutes = totalSeconds / 60;
    NSInteger seconds = totalSeconds % 60;
    
    // 格式化：分:秒，不足两位补零
    return [NSString stringWithFormat:@"%02ld:%02ld", (long)minutes, (long)seconds];
}

/// 是否有MV
- (BOOL)hasMV {
    return self.mvId > 0;
}

/// 付费类型描述
- (NSString *)feeDescription {
    switch (self.fee) {
        case 0:
            return @"免费";
        case 1:
            return @"VIP";
        case 4:
            return @"付费";
        case 8:
            return @"试听";
        default:
            return @"未知";
    }
}

#pragma mark - 调试

/// 打印对象信息
- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p> {name: %@, artist: %@, album: %@, duration: %@}", 
            NSStringFromClass([self class]), 
            self,
            self.name,
            self.artist,
            self.albumName,
            self.durationText];
}

@end
```

---

## YYModel 映射详解

### 简单字段映射

| 属性名 | JSON 路径 | 说明 |
|--------|----------|------|
| `songId` | `id` | 直接映射 |
| `name` | `name` | 无需配置，自动匹配 |
| `duration` | `dt` | 直接映射 |
| `mvId` | `mv` | 直接映射 |

### 嵌套字段映射（YYModel 自动处理）

| 属性名 | JSON 路径 | 说明 |
|--------|----------|------|
| `mainIma` | `al.picUrl` | YYModel 自动解析嵌套 |
| `albumName` | `al.name` | 同上 |
| `albumId` | `al.id` | 同上 |

### 数组字段映射

| 属性名 | JSON 路径 | 说明 |
|--------|----------|------|
| `alias` | `alia` | 直接映射为 NSArray |

### 需要自定义处理的字段

| 属性名 | 处理方式 | 原因 |
|--------|----------|------|
| `artist` | 代码手动提取 | 需要从 `ar[0].name` 取第一个元素 |
| `artistId` | 代码手动提取 | 需要从 `ar[0].id` 取第一个元素 |
| `artists` | 代码手动赋值 | 需要保留完整数组 |

---

## 使用示例

### 1. JSON 转 Model

```objc
// 从 album 接口获取的单个歌曲 JSON
NSDictionary *songJSON = @{
    @"name": @"蜃楼",
    @"id": @2140776001,
    @"ar": @[
        @{@"id": @1030001, @"name": @"周深"}
    ],
    @"al": @{
        @"id": @190605791,
        @"name": @"反深代词",
        @"picUrl": @"https://p2.music.126.net/xxx.jpg"
    },
    @"dt": @226920,
    @"mv": @14711872,
    @"no": @2,
    @"alia": @[],
    @"pop": @100,
    @"fee": @4
};

// 转换
XC_YYSongData *song = [XC_YYSongData yy_modelWithJSON:songJSON];

// 验证
NSLog(@"歌曲: %@ - %@", song.name, song.artist);        // 蜃楼 - 周深
NSLog(@"专辑: %@", song.albumName);                      // 反深代词
NSLog(@"时长: %@", song.durationText);                   // 03:46
NSLog(@"有MV: %@", song.hasMV ? @"是" : @"否");          // 是
NSLog(@"付费类型: %@", song.feeDescription);             // 付费
```

### 2. 数组批量转换

```objc
// 从 album 接口获取的 songs 数组
NSArray *songsJSON = responseObject[@"songs"];
NSArray<XC_YYSongData *> *songs = [NSArray yy_modelArrayWithClass:[XC_YYSongData class] json:songsJSON];
```

### 3. 在 Cell 中使用

```objc
- (void)giveData:(XC_YYSongData *)song ToCell:(XCAlbumDetailCell *)cell {
    // 歌曲名
    cell.songLabel.text = song.name;
    
    // 歌手名（替换原来的硬编码"赵本山"）
    cell.authorLabel.text = song.artist;
    
    // 时长
    cell.durationLabel.text = song.durationText;
    
    // 封面
    [cell.mainImageView sd_setImageWithURL:[NSURL URLWithString:song.mainIma]];
}
```

### 4. 在播放器中使用

```objc
- (void)updateUIWithSong:(XC_YYSongData *)song {
    // 歌名和歌手
    self.mainView.songNameLabel.text = song.name;
    self.mainView.authorNameLabel.text = song.artist;
    
    // 专辑名（可选，如果有显示专辑的地方）
    // self.mainView.albumLabel.text = song.albumName;
    
    // 时长 - 用于设置进度条最大值
    self.mainView.mainSlider.maximumValue = song.duration / 1000.0; // 转换为秒
    
    // 封面
    [self.mainView.albumImage sd_setImageWithURL:[NSURL URLWithString:song.mainIma]];
}
```

---

## 注意事项

1. **ar 数组可能为空**：在 `modelCustomTransformFromDictionary` 中做了保护，默认为"未知艺术家"
2. **al 对象可能为空**：同样做了保护，默认为"未知专辑"
3. **duration 可能为 0**：`durationText` 计算属性做了保护，返回 "00:00"
4. **songUrl 非 API 返回**：需要单独调用 `/song/url/v1` 接口获取后赋值
5. **内存管理**：`artists` 和 `alias` 标记为 `nullable`，API 返回空时不会崩溃

---

## 测试验证

```objc
// 测试代码
- (void)testSongData {
    NSString *jsonString = @"{\"name\":\"测试歌曲\",\"id\":12345,\"ar\":[{\"id\":100,\"name\":\"测试歌手\"}],\"al\":{\"name\":\"测试专辑\",\"picUrl\":\"http://test.jpg\",\"id\":67890},\"dt\":185000,\"mv\":0,\"no\":1,\"alia\":[\"插曲\"],\"pop\":95,\"fee\":0}";
    
    XC_YYSongData *song = [XC_YYSongData yy_modelWithJSON:jsonString];
    
    NSAssert([song.name isEqualToString:@"测试歌曲"], @"name 错误");
    NSAssert([song.songId isEqualToString:@"12345"], @"songId 错误");
    NSAssert([song.artist isEqualToString:@"测试歌手"], @"artist 错误");
    NSAssert([song.albumName isEqualToString:@"测试专辑"], @"albumName 错误");
    NSAssert([song.durationText isEqualToString:@"03:05"], @"durationText 错误");
    NSAssert(song.hasMV == NO, @"hasMV 错误");
    
    NSLog(@"✅ 所有测试通过！");
}
```
