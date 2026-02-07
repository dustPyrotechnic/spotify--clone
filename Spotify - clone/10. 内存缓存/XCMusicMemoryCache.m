//
//  XCMusicMemoryCache.m
//  Spotify - clone
//
//  内存缓存管理器 - 只缓存当前和即将播放的歌曲
//
//  【核心概念】
//  1. NSCache：苹果提供的缓存类，类似 NSDictionary，但会自动管理内存
//  2. 单例模式：整个 App 只有一个缓存管理器实例
//  3. 临时文件：内存中的数据需要写入文件才能被 AVPlayer 播放
//

#import "XCMusicMemoryCache.h"    // 自己的头文件
#import "XC-YYSongData.h"         // 歌曲数据模型
#import <AFNetworking/AFNetworking.h>  // 网络库（本文件其实没用到，可能是历史遗留）

#pragma mark - 常量定义（配置文件参数）

// 【kMaxCacheCount】最多缓存的歌曲数量
// 为什么限制 10 首？假设每首 5MB，10 首就是 50MB，占用内存合理
static const NSUInteger kMaxCacheCount = 10;

// 【kMaxCacheSize】缓存总大小限制（100MB = 100 * 1024 * 1024 字节）
// NSCache 会在接近这个值时自动清理旧数据
static const NSUInteger kMaxCacheSize = 100 * 1024 * 1024;

// 【kMaxSingleSongSize】单首歌曲最大大小限制（20MB）
// 如果一首歌超过 20MB，可能是无损格式，太占内存，我们不缓存
static const NSUInteger kMaxSingleSongSize = 20 * 1024 * 1024;

#pragma mark - 类扩展（私有属性和方法声明）

// @interface XCMusicMemoryCache () 表示"类扩展"
// 这里声明的属性是"私有的"，外部类无法直接访问
@interface XCMusicMemoryCache ()

// 【audioCache】核心的缓存存储器
// 类型：NSCache<NSString *, NSData *>
// - Key（键）：NSString 类型的 songId（歌曲ID）
// - Value（值）：NSData 类型的音频二进制数据
@property (nonatomic, strong) NSCache<NSString *, NSData *> *audioCache;

// 【currentSongId】当前正在播放的歌曲ID
// 用途：标记当前播放的歌曲，防止被 NSCache 自动清理
@property (nonatomic, copy) NSString *currentSongId;

// 【downloadingSongs】正在下载中的歌曲ID集合
// 类型：NSMutableSet（集合，自动去重）
// 用途：防止同一首歌被重复下载多次
@property (nonatomic, strong) NSMutableSet<NSString *> *downloadingSongs;

// 【downloadQueue】下载任务队列
// 类型：dispatch_queue_t（GCD 队列）
// DISPATCH_QUEUE_CONCURRENT = 并发队列，可同时下载多首歌
@property (nonatomic, strong) dispatch_queue_t downloadQueue;

// 【fileManager】文件管理器
// 用途：操作临时文件（创建、删除、检查存在性）
@property (nonatomic, strong) NSFileManager *fileManager;

// 【tempDirectory】临时文件存放目录
// 路径：/tmp/MusicCache/
// 注意：/tmp/ 目录系统会定期清理，App 重启后可能不存在
@property (nonatomic, strong) NSString *tempDirectory;

@end

#pragma mark - 实现

@implementation XCMusicMemoryCache

#pragma mark - 单例模式（整个 App 只有一个实例）

/**
 * 【+ sharedInstance】获取单例对象的方法
 * 
 * 使用场景：
 *   XCMusicMemoryCache *cache = [XCMusicMemoryCache sharedInstance];
 * 
 * 原理：
 * 1. static 变量：在静态区，App 生命周期内只有一份
 * 2. dispatch_once：保证初始化代码只执行一次，线程安全
 */
+ (instancetype)sharedInstance {
    // static：静态变量，存储在全局区，不会随函数结束而销毁
    static XCMusicMemoryCache *instance;
    
    // static dispatch_once_t：标记位，记录是否已经执行过
    static dispatch_once_t onceToken;
    
    // dispatch_once：GCD 提供的"只执行一次"函数
    // 作用：即使多线程同时调用，初始化代码也只会执行一次
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];  // 创建对象
    });
    
    return instance;  // 返回唯一实例
}

/**
 * 【- init】初始化方法
 * 当调用 [[XCMusicMemoryCache alloc] init] 时执行
 * 由于使用了单例，这个方法实际上只会在第一次获取单例时执行一次
 */
- (instancetype)init {
    // 调用父类的初始化方法
    self = [super init];
    
    // self 不为 nil 表示父类初始化成功
    if (self) {
        // ========== 1. 创建 NSCache 实例 ==========
        _audioCache = [[NSCache alloc] init];
        
        // countLimit：缓存对象的最大数量
        // 当缓存超过 10 个对象时，NSCache 会自动清理最旧的对象
        _audioCache.countLimit = kMaxCacheCount;
        
        // totalCostLimit：缓存的总"成本"限制
        // 这里用数据大小（字节数）作为成本
        // 当总大小接近 100MB 时，NSCache 会自动清理
        _audioCache.totalCostLimit = kMaxCacheSize;
        
        // ========== 2. 初始化下载相关属性 ==========
        // NSMutableSet：可变集合，用于存储正在下载的歌曲ID
        // 集合的特点是自动去重，同一个 songId 只能存一次
        _downloadingSongs = [NSMutableSet set];
        
        // dispatch_queue_create：创建 GCD 队列
        // 参数1：队列标识符，用于调试
        // 参数2：DISPATCH_QUEUE_CONCURRENT 表示并发队列（可同时执行多个任务）
        //        如果是 DISPATCH_QUEUE_SERIAL 则是串行队列（一个个执行）
        _downloadQueue = dispatch_queue_create("com.spotifyclone.cache.download", DISPATCH_QUEUE_CONCURRENT);
        
        // NSFileManager defaultManager：获取文件管理器的单例
        _fileManager = [NSFileManager defaultManager];
        
        // ========== 3. 创建临时文件目录 ==========
        // NSTemporaryDirectory()：获取系统临时目录路径
        // 通常是：/var/mobile/Containers/Data/Application/xxx/tmp/
        NSString *tempDir = NSTemporaryDirectory();
        
        // stringByAppendingPathComponent：拼接路径
        // 结果：/var/.../tmp/MusicCache/
        _tempDirectory = [tempDir stringByAppendingPathComponent:@"MusicCache"];
        
        // createDirectoryAtPath：创建目录
        // withIntermediateDirectories:YES：如果父目录不存在也一并创建
        // attributes:nil：使用默认属性
        // error:nil：不关心错误（生产环境应该处理错误）
        [_fileManager createDirectoryAtPath:_tempDirectory
                withIntermediateDirectories:YES
                                 attributes:nil
                                      error:nil];
        
        // ========== 4. 监听内存警告通知 ==========
        // NSNotificationCenter：通知中心，用于组件间通信
        // addObserver: 添加观察者
        // selector: 收到通知后要执行的方法
        // name: UIApplicationDidReceiveMemoryWarningNotification
        //       系统内存不足时发送的通知
        // object: nil 表示监听所有对象发送的通知
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didReceiveMemoryWarning)
                                                     name:UIApplicationDidReceiveMemoryWarningNotification
                                                   object:nil];
        
        // ========== 5. 打印初始化日志 ==========
        NSLog(@"[MemoryCache] ✅ 初始化完成");
        NSLog(@"[MemoryCache]    最大缓存数量: %lu 首", (unsigned long)kMaxCacheCount);
        NSLog(@"[MemoryCache]    最大缓存大小: %.1f MB", kMaxCacheSize / 1024.0 / 1024.0);
        NSLog(@"[MemoryCache]    临时目录: %@", _tempDirectory);
    }
    
    return self;
}

/**
 * 【- dealloc】析构方法
 * 对象被销毁时调用，用于清理资源
 */
- (void)dealloc {
    // 移除通知监听，防止对象销毁后还收到通知导致崩溃
    // 在 iOS 9+ 中其实不手动移除也没关系，但养成好习惯
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - 查询相关方法

/**
 * 【- isCached:】检查指定歌曲是否在内存缓存中
 * 
 * @param songId 歌曲ID
 * @return YES=已缓存，NO=未缓存
 * 
 * 使用示例：
 *   if ([cache isCached:@"12345"]) {
 *       // 有缓存，直接播放
 *   }
 */
- (BOOL)isCached:(NSString *)songId {
    // ========== 1. 参数安全检查 ==========
    // !songId：检查是否为 nil
    // songId.length == 0：检查是否为空字符串 @""
    // || 表示"或"，满足任一条件就执行
    if (!songId || songId.length == 0) {
        NSLog(@"[MemoryCache] ⚠️ isCached: songId 为空");
        return NO;  // 参数无效，直接返回 NO
    }
    
    // ========== 2. 查询 NSCache ==========
    // objectForKey: 根据 key 获取 value
    // 如果找到了返回 NSData 对象，没找到返回 nil
    // != nil 判断是否找到，结果为 YES（找到）或 NO（没找到）
    BOOL cached = [self.audioCache objectForKey:songId] != nil;
    
    // ========== 3. 打印日志 ==========
    if (cached) {
        // 找到了，获取数据计算大小
        NSData *data = [self.audioCache objectForKey:songId];
        
        // %.2f：格式化浮点数，保留 2 位小数
        // data.length / 1024.0 / 1024.0：字节 → KB → MB
        NSLog(@"[MemoryCache] ✅ 命中缓存: %@ (大小: %.2f MB)", songId, data.length / 1024.0 / 1024.0);
    } else {
        NSLog(@"[MemoryCache] ❌ 未命中缓存: %@", songId);
    }
    
    return cached;
}

/**
 * 【- dataForSongId:】获取缓存的音频数据
 * 
 * @param songId 歌曲ID
 * @return NSData 类型的音频二进制数据，如果没有缓存返回 nil
 * 
 * 使用示例：
 *   NSData *audioData = [cache dataForSongId:@"12345"];
 *   if (audioData) {
 *       // 播放 audioData
 *   }
 */
- (NSData *)dataForSongId:(NSString *)songId {
    // 参数检查（同上）
    if (!songId || songId.length == 0) {
        NSLog(@"[MemoryCache] ⚠️ dataForSongId: songId 为空");
        return nil;  // nil 表示 Objective-C 中的"空"
    }
    
    // 从 NSCache 中获取数据
    NSData *data = [self.audioCache objectForKey:songId];
    
    if (data) {
        NSLog(@"[MemoryCache] ✅ 读取缓存数据: %@ (%.2f MB)", songId, data.length / 1024.0 / 1024.0);
    } else {
        NSLog(@"[MemoryCache] ❌ 无缓存数据: %@", songId);
    }
    
    return data;  // 可能返回 nil（如果没有缓存）
}

#pragma mark - 写入相关方法

/**
 * 【- cacheData:forSongId:】将音频数据写入内存缓存
 * 
 * @param data 音频二进制数据（NSData）
 * @param songId 歌曲ID（作为缓存的 key）
 * 
 * 使用示例：
 *   NSData *mp3Data = [NSData dataWithContentsOfFile:@"song.mp3"];
 *   [cache cacheData:mp3Data forSongId:@"12345"];
 */
- (void)cacheData:(NSData *)data forSongId:(NSString *)songId {
    // ========== 1. 参数检查 ==========
    // 检查 data 和 songId 是否有效
    // data.length == 0 检查是否为空数据
    if (!data || !songId || data.length == 0) {
        NSLog(@"[MemoryCache] ⚠️ cacheData: 参数无效 (data=%@, songId=%@)",
              data ? @"有" : @"无", songId);  // 三元运算符：条件 ? 真值 : 假值
        return;
    }
    
    // ========== 2. 大小限制检查 ==========
    // 如果这首歌太大（超过 20MB），选择不缓存
    // 原因：无损音乐文件可能几十MB，太占内存
    if (data.length > kMaxSingleSongSize) {
        NSLog(@"[MemoryCache] ⚠️ 歌曲太大跳过: %@ (%.2f MB > 20MB)", 
              songId, data.length / 1024.0 / 1024.0);
        return;  // 直接返回，不执行缓存
    }
    
    // ========== 3. 写入 NSCache ==========
    // cost：成本，这里用数据大小（字节）作为成本
    // NSCache 会根据 cost 决定清理哪些数据
    NSUInteger cost = data.length;
    
    // setObject:forKey:cost: 存入缓存并指定成本
    [self.audioCache setObject:data forKey:songId cost:cost];
    
    NSLog(@"[MemoryCache] ✅ 已写入缓存: %@ (%.2f MB)", songId, cost / 1024.0 / 1024.0);
}

/**
 * 【- downloadAndCache:】从网络下载歌曲并缓存到内存
 * 
 * @param song 歌曲数据模型（包含 songId 和 songUrl）
 * 
 * 这是本类最核心的方法，流程：
 * 1. 检查参数 → 2. 检查是否已缓存 → 3. 检查是否正在下载 → 
 * 4. URL 预处理 → 5. 发起网络请求 → 6. 下载完成写入缓存
 */
- (void)downloadAndCache:(XC_YYSongData *)song {
    // ========== 1. 参数检查 ==========
    // 检查 song 对象及其必要属性是否有效
    if (!song || !song.songId || !song.songUrl) {
        NSLog(@"[MemoryCache] ⚠️ downloadAndCache: 歌曲信息不完整 (song=%@, songId=%@, songUrl=%@)",
              song ? @"有" : @"无", song.songId, song.songUrl);
        return;
    }
    
    // 为了方便使用，提取到局部变量
    NSString *songId = song.songId;
    NSString *originalUrl = song.songUrl;
    
    // ========== 2. 检查是否已在缓存中 ==========
    // 如果已经缓存过了，直接返回，避免重复下载
    if ([self isCached:songId]) {
        NSLog(@"[MemoryCache] ℹ️ 已在缓存中，跳过下载: %@", songId);
        return;
    }
    
    // ========== 3. 检查是否正在下载中（防重复） ==========
    // @synchronized：互斥锁，保证多线程安全
    // 同一时间只有一个线程能执行大括号内的代码
    @synchronized (self.downloadingSongs) {
        // containsObject：检查集合中是否包含某个元素
        if ([self.downloadingSongs containsObject:songId]) {
            NSLog(@"[MemoryCache] ℹ️ 正在下载中，跳过重复任务: %@", songId);
            return;
        }
        // addObject：将 songId 加入"正在下载"集合
        [self.downloadingSongs addObject:songId];
    }
    
    // ========== 4. URL 预处理 ==========
    
    // 4.1 去除首尾空格和换行符
    // stringByTrimmingCharactersInSet：去除字符串两端的指定字符
    // whitespaceAndNewlineCharacterSet：空白字符和换行符的集合
    NSString *trimmedUrl = [originalUrl stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    // 4.2 URL 编码（转义特殊字符）
    // URL 中不能包含中文、空格等特殊字符，需要编码
    // 例如："http://example.com/歌曲名.mp3" → "http://example.com/%E6%AD%8C%E6%9B%B2%E5%90%8D.mp3"
    NSString *encodedUrl = [trimmedUrl stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    
    // 4.3 创建 NSURL 对象
    // URLWithString：将字符串转换为 NSURL 对象
    // 如果字符串格式不对，返回 nil
    NSURL *url = [NSURL URLWithString:encodedUrl];
    if (!url) {
        NSLog(@"[MemoryCache] ❌ URL 无效: %@", originalUrl);
        NSLog(@"[MemoryCache]    处理后: %@", encodedUrl);
        
        // URL 无效，从"正在下载"集合中移除
        @synchronized (self.downloadingSongs) {
            [self.downloadingSongs removeObject:songId];
        }
        return;
    }
    
    // 4.4 检查 URL 协议
    // scheme：URL 的协议部分，如 http、https、file 等
    // 我们只需要 http 或 https
    if (![url.scheme isEqualToString:@"http"] && ![url.scheme isEqualToString:@"https"]) {
        NSLog(@"[MemoryCache] ❌ URL 协议不支持: %@", url.scheme);
        @synchronized (self.downloadingSongs) {
            [self.downloadingSongs removeObject:songId];
        }
        return;
    }
    
    // ========== 5. 打印开始下载日志 ==========
    NSLog(@"[MemoryCache] 🚀 开始下载: %@", songId);
    NSLog(@"[MemoryCache]    URL: %@", song.songUrl);
    
    // ========== 6. 在后台队列发起下载 ==========
    // dispatch_async：异步执行，不会阻塞当前线程
    // self.downloadQueue：我们之前创建的并发队列
    dispatch_async(self.downloadQueue, ^{
        
        // 6.1 创建网络请求
        // requestWithURL：创建 GET 请求
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        
        // 6.2 创建下载任务
        // NSURLSession sharedSession：获取系统共享的 Session
        // dataTaskWithRequest:completionHandler：创建数据任务
        NSURLSessionDataTask *task = [[NSURLSession sharedSession] 
            dataTaskWithRequest:request 
            completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                // 【注意】这个 completionHandler 在子线程执行
                
                // 6.3 无论成功失败，都从"正在下载"集合中移除
                @synchronized (self.downloadingSongs) {
                    [self.downloadingSongs removeObject:songId];
                }
                
                // 6.4 错误处理
                // error 不为 nil 表示下载出错
                if (error) {
                    NSLog(@"[MemoryCache] ❌ 下载失败 %@: %@", songId, error.localizedDescription);
                    return;  // 直接返回，不写缓存
                }
                
                // 6.5 获取 HTTP 响应信息
                // 将 NSURLResponse 强制转换为 NSHTTPURLResponse，获取状态码
                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                NSLog(@"[MemoryCache] 📥 下载完成: %@ (HTTP %ld, 大小: %.2f MB)", 
                      songId, (long)httpResponse.statusCode, data.length / 1024.0 / 1024.0);
                
                // 6.6 写入缓存
                // 检查数据是否有效（不为 nil 且长度大于 0）
                if (data && data.length > 0) {
                    // dispatch_async(dispatch_get_main_queue()：切换到主线程
                    // 因为 cacheData 方法内部有 UI 相关的日志（可选，但好习惯）
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self cacheData:data forSongId:songId];
                    });
                } else {
                    NSLog(@"[MemoryCache] ⚠️ 下载数据为空: %@", songId);
                }
            }];
        
        // 6.7 启动任务
        // resume：开始执行下载任务（默认是挂起状态）
        [task resume];
    });
}

#pragma mark - 当前播放管理

/**
 * 【- setCurrentPlayingSong:】设置当前播放的歌曲
 * 
 * 重要功能：刷新缓存，防止当前播放歌曲被 NSCache 清理
 * 
 * @param songId 当前播放的歌曲ID
 * 
 * 原理：
 * NSCache 使用 LRU（最近最少使用）算法
 * 当我们"重新设置"一个对象时，它会被标记为"最近使用"
 * 从而降低被清理的概率
 */
- (void)setCurrentPlayingSong:(NSString *)songId {
    // 记录旧值，用于日志
    NSString *oldSongId = self.currentSongId;
    
    // 更新当前播放的歌曲ID
    self.currentSongId = songId;
    
    NSLog(@"[MemoryCache] 🎵 当前播放歌曲变更: %@ -> %@", oldSongId ?: @"无", songId);
    
    // 从缓存中获取这首歌的数据
    NSData *data = [self.audioCache objectForKey:songId];
    if (data) {
        // 重新设置到 NSCache 中，刷新其"新鲜度"
        // 这样 NSCache 会认为这首歌是"最近使用"的，优先保留
        [self.audioCache setObject:data forKey:songId cost:data.length];
        NSLog(@"[MemoryCache]    已刷新缓存保护");
    }
}

/**
 * 【- localURLForSongId:】获取缓存歌曲的本地文件 URL
 * 
 * 为什么需要这个方法？
 * AVPlayer 播放音频有两种方式：
 * 1. [AVPlayer playerWithURL:网络URL] - 直接播网络流
 * 2. [AVPlayer playerWithURL:本地文件URL] - 播放本地文件
 * 
 * 我们的缓存数据在内存中（NSData），AVPlayer 无法直接播放 NSData
 * 所以需要先把 NSData 写入临时文件，然后返回文件 URL
 * 
 * @param songId 歌曲ID
 * @return 本地文件的 URL（file://...），如果没有缓存返回 nil
 */
- (NSURL *)localURLForSongId:(NSString *)songId {
    // 1. 先从内存缓存中获取数据
    NSData *data = [self dataForSongId:songId];
    if (!data) {
        NSLog(@"[MemoryCache] ❌ localURLForSongId: 无缓存数据 %@", songId);
        return nil;  // 没有缓存，无法提供本地 URL
    }
    
    // 2. 构造临时文件路径
    // stringWithFormat：格式化字符串，%@ 表示字符串占位符
    NSString *fileName = [NSString stringWithFormat:@"%@.mp3", songId];
    
    // stringByAppendingPathComponent：拼接路径组件
    // 自动处理路径分隔符 /，不需要手动加斜杠
    NSString *filePath = [self.tempDirectory stringByAppendingPathComponent:fileName];
    
    // 3. 检查文件是否已存在
    // fileExistsAtPath：检查文件是否存在
    if ([self.fileManager fileExistsAtPath:filePath]) {
        NSLog(@"[MemoryCache] ✅ 临时文件已存在: %@", fileName);
        // fileURLWithPath：将路径字符串转换为 file:// URL
        return [NSURL fileURLWithPath:filePath];
    }
    
    // 4. 文件不存在，需要写入
    NSLog(@"[MemoryCache] 📝 写入临时文件: %@ (%.2f MB)", fileName, data.length / 1024.0 / 1024.0);
    
    // writeToFile:atomically: 写入文件
    // atomically:YES：原子写入，先写入临时文件，成功后再重命名
    // 这样能保证不会因为写入中断导致文件损坏
    if ([data writeToFile:filePath atomically:YES]) {
        NSLog(@"[MemoryCache] ✅ 临时文件写入成功");
        return [NSURL fileURLWithPath:filePath];
    }
    
    // 5. 写入失败
    NSLog(@"[MemoryCache] ❌ 临时文件写入失败");
    return nil;
}

#pragma mark - 清理相关方法

/**
 * 【- removeCache:】移除指定歌曲的缓存
 * 
 * @param songId 要移除的歌曲ID
 * 作用：同时清理内存缓存和临时文件
 */
- (void)removeCache:(NSString *)songId {
    if (!songId) {
        NSLog(@"[MemoryCache] ⚠️ removeCache: songId 为空");
        return;
    }
    
    // 1. 从 NSCache 中移除
    // removeObjectForKey：根据 key 删除缓存
    [self.audioCache removeObjectForKey:songId];
    
    // 2. 删除对应的临时文件
    NSString *fileName = [NSString stringWithFormat:@"%@.mp3", songId];
    NSString *filePath = [self.tempDirectory stringByAppendingPathComponent:fileName];
    
    if ([self.fileManager fileExistsAtPath:filePath]) {
        NSError *error;  // 用于接收错误信息
        
        // removeItemAtPath:error: 删除文件
        // error:&error：如果出错，将错误信息存入 error 变量
        [self.fileManager removeItemAtPath:filePath error:&error];
        
        if (error) {
            NSLog(@"[MemoryCache] ⚠️ 删除临时文件失败: %@ - %@", songId, error.localizedDescription);
        } else {
            NSLog(@"[MemoryCache] ✅ 已删除缓存: %@", songId);
        }
    } else {
        NSLog(@"[MemoryCache] ℹ️ 无临时文件需要删除: %@", songId);
    }
}

/**
 * 【- clearAllCache:】清空所有缓存
 * 
 * 使用场景：用户手动清理缓存、App 退出登录等
 */
- (void)clearAllCache {
    NSLog(@"[MemoryCache] 🧹 开始清空所有缓存...");
    
    // 1. 清空 NSCache 中的所有对象
    [self.audioCache removeAllObjects];
    
    // 2. 重置当前播放的歌曲ID
    self.currentSongId = nil;
    
    // 3. 遍历临时目录，删除所有文件
    // contentsOfDirectoryAtPath:error: 获取目录下所有文件列表
    NSArray *files = [self.fileManager contentsOfDirectoryAtPath:self.tempDirectory error:nil];
    NSUInteger deletedCount = 0;  // 计数器，记录删除了多少文件
    
    // for-in 循环遍历数组
    for (NSString *file in files) {
        // 拼接完整路径
        NSString *path = [self.tempDirectory stringByAppendingPathComponent:file];
        NSError *error;
        [self.fileManager removeItemAtPath:path error:&error];
        
        if (!error) {
            deletedCount++;  // 删除成功，计数+1
        }
    }
    
    NSLog(@"[MemoryCache] ✅ 已清空所有缓存，删除文件数: %lu", (unsigned long)deletedCount);
}

/**
 * 【- didReceiveMemoryWarning:】收到系统内存警告时的回调
 * 
 * 系统内存不足时会调用这个方法
 * 注意：我们不需要手动清理 NSCache，它会自动处理
 * 这个方法主要用于打日志，方便调试
 */
- (void)didReceiveMemoryWarning {
    NSLog(@"[MemoryCache] ⚠️ 收到系统内存警告！当前播放: %@", self.currentSongId);
    NSLog(@"[MemoryCache]    NSCache 会自动处理，非当前播放歌曲可能被释放");
    
    // 如果需要手动清理，可以在这里调用：
    // [self.audioCache removeAllObjects];  // 但通常不建议，让 NSCache 自己管理更好
}

#pragma mark - 统计方法（NSCache 限制）

/**
 * 【- currentCacheSize】获取当前缓存占用大小
 * 
 * ⚠️ 重要说明：NSCache 不暴露当前缓存大小的 API
 * 所以这个方法始终返回 0，只是打印日志说明
 * 
 * 如果需要精确统计，需要自己维护一个计数器变量
 */
- (NSUInteger)currentCacheSize {
    NSLog(@"[MemoryCache] ℹ️ currentCacheSize: NSCache 不提供精确统计");
    return 0;
}

/**
 * 【- cachedSongCount】获取缓存歌曲数量
 * 
 * ⚠️ 同上，NSCache 不暴露当前缓存数量
 * 如果需要，需要自己维护计数
 */
- (NSUInteger)cachedSongCount {
    NSLog(@"[MemoryCache] ℹ️ cachedSongCount: NSCache 不提供精确统计");
    return 0;
}

@end
