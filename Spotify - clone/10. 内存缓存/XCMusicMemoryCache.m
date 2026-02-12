//
//  XCMusicMemoryCache.m
//  Spotify - clone
//

#import "XCMusicMemoryCache.h"
#import "XC-YYSongData.h"

// 缓存配置常量
static const NSUInteger kMaxCacheCount = 10;           // NSCache countLimit
static const NSUInteger kMaxCacheSize = 100 * 1024 * 1024;   // NSCache totalCostLimit (100MB)
static const NSUInteger kMaxSingleSongSize = 20 * 1024 * 1024; // 单首歌曲大小限制 (20MB)

@interface XCMusicMemoryCache ()
@property (nonatomic, strong) NSCache<NSString *, NSData *> *audioCache;  // 基于成本的 LRU 缓存
@property (nonatomic, copy) NSString *currentSongId;                      // 当前播放歌曲标记
@property (nonatomic, strong) NSMutableSet<NSString *> *downloadingSongs; // 下载去重集合
@property (nonatomic, strong) dispatch_queue_t downloadQueue;             // 并发下载队列
@property (nonatomic, strong) NSFileManager *fileManager;
@property (nonatomic, strong) NSString *tempDirectory;                    // 临时文件目录 (/tmp/MusicCache)
@end

@implementation XCMusicMemoryCache

#pragma mark - 单例模式
// 使用 dispatch_once 保证线程安全的懒汉式单例
+ (instancetype)sharedInstance {
    static XCMusicMemoryCache *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

// 初始化 NSCache 配置、并发队列、临时目录，并注册内存警告通知
- (instancetype)init {
    self = [super init];
    if (self) {
        _audioCache = [[NSCache alloc] init];
        _audioCache.countLimit = kMaxCacheCount;
        _audioCache.totalCostLimit = kMaxCacheSize;
        
        _downloadingSongs = [NSMutableSet set];
        _downloadQueue = dispatch_queue_create("com.spotifyclone.cache.download", DISPATCH_QUEUE_CONCURRENT);
        _fileManager = [NSFileManager defaultManager];
        
        NSString *tempDir = NSTemporaryDirectory();
        _tempDirectory = [tempDir stringByAppendingPathComponent:@"MusicCache"];
        [_fileManager createDirectoryAtPath:_tempDirectory
                withIntermediateDirectories:YES
                                 attributes:nil
                                      error:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didReceiveMemoryWarning)
                                                     name:UIApplicationDidReceiveMemoryWarningNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - 查询
// 基于 NSCache 的 key 查询，NSCache 内部使用哈希表实现 O(1) 查找
- (BOOL)isCached:(NSString *)songId {
    if (!songId || songId.length == 0) {
        return NO;
    }
    return [self.audioCache objectForKey:songId] != nil;
}

// 直接从 NSCache 获取对象引用，不会拷贝数据
- (NSData *)dataForSongId:(NSString *)songId {
    if (!songId || songId.length == 0) {
        return nil;
    }
    return [self.audioCache objectForKey:songId];
}

#pragma mark - 写入
// 使用 NSCache 的 setObject:forKey:cost: 方法，cost 参与 LRU 淘汰决策
// 当 totalCostLimit 超过时，NSCache 自动淘汰低优先级对象
- (void)cacheData:(NSData *)data forSongId:(NSString *)songId {
    if (!data || !songId || data.length == 0) {
        return;
    }
    if (data.length > kMaxSingleSongSize) {
        return;
    }
    NSUInteger cost = data.length;
    [self.audioCache setObject:data forKey:songId cost:cost];
}

// 使用 NSURLSession 在后台并发队列下载，通过 NSMutableSet 防止重复下载
- (void)downloadAndCache:(XC_YYSongData *)song {
    if (!song || !song.songId || !song.songUrl) {
        return;
    }
    NSString *songId = song.songId;
    NSString *originalUrl = song.songUrl;
    
    // 检查内存缓存中是否已存在
    if ([self isCached:songId]) {
        return;
    }
    
    // 使用 @synchronized 保证多线程安全的集合操作
    @synchronized (self.downloadingSongs) {
        if ([self.downloadingSongs containsObject:songId]) {
            return;
        }
        [self.downloadingSongs addObject:songId];
    }
    
    // URL 预处理：去除空白字符 + URL 编码
    NSString *trimmedUrl = [originalUrl stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *encodedUrl = [trimmedUrl stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSURL *url = [NSURL URLWithString:encodedUrl];
    if (!url) {
        @synchronized (self.downloadingSongs) {
            [self.downloadingSongs removeObject:songId];
        }
        return;
    }
    
    // 验证 URL 协议
    if (![url.scheme isEqualToString:@"http"] && ![url.scheme isEqualToString:@"https"]) {
        @synchronized (self.downloadingSongs) {
            [self.downloadingSongs removeObject:songId];
        }
        return;
    }
    
    // 在并发队列发起异步下载
    dispatch_async(self.downloadQueue, ^{
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        NSURLSessionDataTask *task = [[NSURLSession sharedSession]
            dataTaskWithRequest:request
            completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                // 无论成功失败，从下载集合移除
                @synchronized (self.downloadingSongs) {
                    [self.downloadingSongs removeObject:songId];
                }
                if (error) {
                    return;
                }
                if (data && data.length > 0) {
                    // 切回主线程写入缓存（NSCache 线程安全，但遵循 UI 相关规范）
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self cacheData:data forSongId:songId];
                    });
                }
            }];
        [task resume];
    });
}

#pragma mark - 当前播放管理
// 通过重新 setObject 刷新对象在 NSCache 中的访问时间，提升 LRU 优先级
- (void)setCurrentPlayingSong:(NSString *)songId {
    self.currentSongId = songId;
    NSData *data = [self.audioCache objectForKey:songId];
    if (data) {
        [self.audioCache setObject:data forKey:songId cost:data.length];
    }
}

// 将 NSData 原子写入临时文件，返回 file:// URL 供 AVPlayer 播放
- (NSURL *)localURLForSongId:(NSString *)songId {
    NSData *data = [self dataForSongId:songId];
    if (!data) {
        return nil;
    }
    NSString *fileName = [NSString stringWithFormat:@"%@.mp3", songId];
    NSString *filePath = [self.tempDirectory stringByAppendingPathComponent:fileName];
    
    // 文件已存在则直接返回，避免重复写入
    if ([self.fileManager fileExistsAtPath:filePath]) {
        return [NSURL fileURLWithPath:filePath];
    }
    
    // atomically:YES 保证写入的原子性（先写临时文件，成功后重命名）
    if ([data writeToFile:filePath atomically:YES]) {
        return [NSURL fileURLWithPath:filePath];
    }
    return nil;
}

#pragma mark - 清理
// 同时清理 NSCache 内存缓存和临时文件
- (void)removeCache:(NSString *)songId {
    if (!songId) {
        return;
    }
    [self.audioCache removeObjectForKey:songId];
    NSString *fileName = [NSString stringWithFormat:@"%@.mp3", songId];
    NSString *filePath = [self.tempDirectory stringByAppendingPathComponent:fileName];
    if ([self.fileManager fileExistsAtPath:filePath]) {
        [self.fileManager removeItemAtPath:filePath error:nil];
    }
}

// 遍历临时目录删除所有文件，同时清空 NSCache
- (void)clearAllCache {
    [self.audioCache removeAllObjects];
    self.currentSongId = nil;
    NSArray *files = [self.fileManager contentsOfDirectoryAtPath:self.tempDirectory error:nil];
    for (NSString *file in files) {
        NSString *path = [self.tempDirectory stringByAppendingPathComponent:file];
        [self.fileManager removeItemAtPath:path error:nil];
    }
}

// 系统内存警告回调，NSCache 会自动处理清理，无需手动干预
- (void)didReceiveMemoryWarning {
}

#pragma mark - 统计
- (NSUInteger)currentCacheSize {
    return 0;
}

- (NSUInteger)cachedSongCount {
    return 0;
}

@end
