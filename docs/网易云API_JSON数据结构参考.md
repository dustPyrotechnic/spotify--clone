# 网易云 API JSON 数据结构参考

> 整理日期: 2026-02-07  
> 基础URL: `https://1390963969-2g6ivueiij.ap-guangzhou.tencentscf.com`

---

## 一、歌曲数据 (Song)

**来源接口**: `/album`  
**示例**: `/album?id=190605791`

### 完整 JSON 结构

```json
{
  "name": "蜃楼",
  "id": 2140776001,
  "ar": [
    {"id": 1030001, "name": "周深"}
  ],
  "al": {
    "id": 190605791,
    "name": "反深代词",
    "picUrl": "https://p2.music.126.net/KuzA_CG76o55rr8sHrQ0ag==/109951170008506786.jpg",
    "pic_str": "109951170008506786",
    "pic": 109951170008506780
  },
  "dt": 226920,
  "mv": 14711872,
  "alia": [],
  "pop": 100,
  "no": 2,
  "st": 1,
  "fee": 4,
  "djId": 0,
  "cd": "01",
  "t": 0,
  "v": 28,
  "pst": 0,
  "rt": "",
  "mst": 9,
  "cp": 7002,
  "cf": "",
  "a": null,
  "rtype": 0,
  "rurl": null,
  "h": {"br": 320000, "fid": 0, "size": 9079725, "vd": -64286, "sr": 48000},
  "m": {"br": 192000, "fid": 0, "size": 5447853, "vd": -61736, "sr": 48000},
  "l": {"br": 128000, "fid": 0, "size": 3631917, "vd": -60284, "sr": 48000},
  "sq": {"br": 988720, "fid": 0, "size": 28045115, "vd": -64039, "sr": 48000},
  "hr": {"br": 1758432, "fid": 0, "size": 49878028, "vd": -64260, "sr": 48000}
}
```

### 字段说明

| 字段 | 类型 | 说明 | 示例值 |
|------|------|------|--------|
| **基础信息** ||||
| `name` | string | 歌曲名称 | `"蜃楼"` |
| `id` | integer | 歌曲唯一ID | `2140776001` |
| `no` | integer | 专辑内序号 | `2` |
| **艺术家** ||||
| `ar` | array | 艺术家数组 | `[{"id":1030001,"name":"周深"}]` |
| `ar[].id` | integer | 艺术家ID | `1030001` |
| `ar[].name` | string | 艺术家名称 | `"周深"` |
| **专辑信息** ||||
| `al` | object | 专辑信息对象 | - |
| `al.id` | integer | 专辑ID | `190605791` |
| `al.name` | string | 专辑名称 | `"反深代词"` |
| `al.picUrl` | string | 专辑封面URL | `https://p2.music.126.net/...` |
| `al.pic_str` | string | 封面ID字符串 | `"109951170008506786"` |
| `al.pic` | integer | 封面ID | `109951170008506780` |
| **播放信息** ||||
| `dt` | integer | 时长（毫秒） | `226920` → 3分46秒 |
| `mv` | integer | MV ID（0表示无MV） | `14711872` |
| **音质信息** ||||
| `h` | object | 高清音质 (320k) | `br: 320000` |
| `m` | object | 中等音质 (192k) | `br: 192000` |
| `l` | object | 低音质 (128k) | `br: 128000` |
| `sq` | object | 无损音质 | `br: 988720` |
| `hr` | object | Hi-Res音质 | `br: 1758432` |
| `h/m/l/sq/hr.br` | integer | 比特率 | `320000` = 320kbps |
| `h/m/l/sq/hr.size` | integer | 文件大小（字节） | `9079725` |
| **其他信息** ||||
| `alia` | array | 歌曲别名/副标题 | `[]` |
| `pop` | integer | 热度值（0-100） | `100` |
| `st` | integer | 是否可播放状态 | `1` |
| `fee` | integer | 付费类型 | `0`=免费, `1`=VIP, `4`=付费 |
| `cd` | string | 碟片编号 | `"01"` |

### fee（付费类型）枚举

| 值 | 含义 |
|----|------|
| `0` | 免费 |
| `1` | VIP歌曲 |
| `4` | 付费专辑/单曲 |
| `8` | 低保真可免费播放 |

---

## 二、歌单/播放列表 (Playlist)

**来源接口**: `/top/playlist`  
**示例**: `/top/playlist?limit=10&offset=0`

### 完整 JSON 结构

```json
{
  "playlists": [
    {
      "name": "【欧美旋律控】前奏封神 耳熟能详欧美神曲",
      "id": 17426483259,
      "trackCount": 67,
      "coverImgUrl": "http://p1.music.126.net/4EiMzo9LAGbNjwF79ecuZg==/109951172271263928.jpg",
      "description": "这份歌单，是资深乐迷私藏的欧美旋律宝库...",
      "tags": ["欧美", "流行", "放松"],
      "playCount": 49928,
      "subscribedCount": 259,
      "createTime": 1762895530229,
      "updateTime": 1763103716289,
      "trackNumberUpdateTime": 1762895636929,
      "userId": 312608589,
      "creator": {
        "nickname": "心语馆",
        "userId": 312608589,
        "avatarUrl": "http://p1.music.126.net/...",
        "signature": "祝我们好在春天"
      },
      "tracks": null,
      "status": 0,
      "privacy": 0,
      "ordered": true,
      "highQuality": false,
      "commentCount": 0,
      "shareCount": 2
    }
  ],
  "total": 697,
  "code": 200,
  "more": true,
  "cat": "全部"
}
```

### 字段说明

| 字段 | 类型 | 说明 | 示例值 |
|------|------|------|--------|
| **基础信息** ||||
| `name` | string | 歌单名称 | `"【欧美旋律控】前奏封神..."` |
| `id` | integer | 歌单ID | `17426483259` |
| `description` | string | 歌单描述 | `"这份歌单，是资深乐迷..."` |
| **统计信息** ||||
| `trackCount` | integer | 歌曲数量 | `67` |
| `playCount` | integer | 播放次数 | `49928` |
| `subscribedCount` | integer | 收藏数 | `259` |
| `commentCount` | integer | 评论数 | `0` |
| `shareCount` | integer | 分享数 | `2` |
| **封面** ||||
| `coverImgUrl` | string | 封面图URL | `http://p1.music.126.net/...` |
| `coverImgId` | integer | 封面图ID | `109951172271263940` |
| **分类** ||||
| `tags` | array | 标签数组 | `["欧美", "流行", "放松"]` |
| `cat` | string | 分类（根对象） | `"全部"` |
| **作者信息** ||||
| `userId` | integer | 创建者ID | `312608589` |
| `creator` | object | 创建者详情 | - |
| `creator.nickname` | string | 创建者昵称 | `"心语馆"` |
| `creator.avatarUrl` | string | 创建者头像 | `http://p1.music.126.net/...` |
| `creator.signature` | string | 创建者签名 | `"祝我们好在春天"` |
| **时间** ||||
| `createTime` | integer | 创建时间戳 | `1762895530229` |
| `updateTime` | integer | 更新时间戳 | `1763103716289` |
| **状态** ||||
| `status` | integer | 歌单状态 | `0`=正常 |
| `privacy` | integer | 隐私设置 | `0`=公开, `10`=隐私 |
| `ordered` | boolean | 是否有序 | `true` |
| `highQuality` | boolean | 是否精品歌单 | `false` |
| `tracks` | array/null | 歌曲列表（详略） | `null` |

### 根对象字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `playlists` | array | 歌单数组 |
| `total` | integer | 总数 |
| `more` | boolean | 是否有更多数据 |
| `code` | integer | 状态码（200=成功） |

---

## 三、数字专辑 (Album Product)

**来源接口**: `/album/list`  
**示例**: `/album/list?limit=10&offset=0`

### 完整 JSON 结构

```json
{
  "products": [
    {
      "albumId": 357748741,
      "albumName": "Odisea del Talud",
      "artistName": "DINGG MUSIC 鼎极音乐/Tres Latin Jazz",
      "coverUrl": "http://p4.music.126.net/Ee6IpoNs8ZrLZQETv-v8DQ==/109951172576736267.jpg",
      "pubTime": 1770285602425,
      "price": 15,
      "saleNum": 2,
      "newAlbum": true,
      "albumType": 0,
      "saleType": 0,
      "area": 7,
      "artistType": 0,
      "status": 0
    }
  ],
  "code": 200
}
```

### 字段说明

| 字段 | 类型 | 说明 | 示例值 |
|------|------|------|--------|
| **基础信息** ||||
| `albumId` | integer | 专辑ID | `357748741` |
| `albumName` | string | 专辑名称 | `"Odisea del Talud"` |
| `artistName` | string | 艺术家名称 | `"DINGG MUSIC..."` |
| `coverUrl` | string | 封面URL | `http://p4.music.126.net/...` |
| **销售信息** ||||
| `price` | integer | 价格（元） | `15` |
| `saleNum` | integer | 销量 | `2` |
| `pubTime` | integer | 发布时间戳 | `1770285602425` |
| **类型标识** ||||
| `newAlbum` | boolean | 是否新专辑 | `true` |
| `albumType` | integer | 专辑类型 | `0` |
| `saleType` | integer | 销售类型 | `0` |
| `area` | integer | 地区 | `7` |
| `artistType` | integer | 艺术家类型 | `0` |
| `status` | integer | 状态 | `0`=正常 |

---

## 四、歌曲播放 URL 接口

**来源接口**: `/song/url/v1`  
**示例**: `/song/url/v1?id=2140776001&level=standard`

### 响应结构

```json
{
  "data": [
    {
      "id": 2140776001,
      "url": "https://m801.music.126.net/.../2140776001.mp3",
      "br": 128000,
      "size": 3631917,
      "md5": "...",
      "code": 200,
      "expi": 1200,
      "type": "mp3",
      "gain": 0,
      "fee": 4,
      "uf": null,
      "payed": 0,
      "flag": 256,
      "canExtend": false,
      "freeTrialInfo": null,
      "level": "standard",
      "encodeType": "mp3"
    }
  ],
  "code": 200
}
```

### 字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | integer | 歌曲ID |
| `url` | string/null | 播放URL（null表示无权限） |
| `br` | integer | 比特率 |
| `size` | integer | 文件大小 |
| `md5` | string | 文件MD5 |
| `type` | string | 文件格式：`mp3`, `flac` |
| `level` | string | 音质等级：`standard`, `higher`, `exhigh`, `lossless`, `hires` |
| `expi` | integer | URL有效期（秒） |
| `fee` | integer | 付费类型 |
| `payed` | integer | 是否已购买 `0`=否, `1`=是 |
| `freeTrialInfo` | object/null | 试听信息（非null表示可试听） |

### 音质等级 (level) 枚举

| 值 | 说明 | 对应字段 |
|----|------|----------|
| `standard` | 标准（128k） | `l` |
| `higher` | 较高（192k） | `m` |
| `exhigh` | 极高（320k） | `h` |
| `lossless` | 无损 | `sq` |
| `hires` | Hi-Res | `hr` |

---

## 五、快速参考

### 常用字段映射速查

| 业务含义 | 歌曲字段 | 歌单字段 | 专辑字段 |
|----------|----------|----------|----------|
| 名称 | `name` | `name` | `albumName` |
| ID | `id` | `id` | `albumId` |
| 封面 | `al.picUrl` | `coverImgUrl` | `coverUrl` |
| 艺术家 | `ar[0].name` | `creator.nickname` | `artistName` |
| 数量 | - | `trackCount` | - |
| 播放量 | `pop` | `playCount` | - |

### 时间戳转换

```objc
// 毫秒时间戳转日期
NSTimeInterval seconds = timestamp / 1000.0;
NSDate *date = [NSDate dateWithTimeIntervalSince1970:seconds];
```

### 时长格式化

```objc
// 毫秒转 "03:46"
+ (NSString *)formatDuration:(NSInteger)ms {
    NSInteger seconds = ms / 1000;
    NSInteger min = seconds / 60;
    NSInteger sec = seconds % 60;
    return [NSString stringWithFormat:@"%02ld:%02ld", (long)min, (long)sec];
}
```
