//
//  XCMusicMemoryCache.m
//  Spotify - clone
//

#import "XCMusicMemoryCache.h"
#import "XC-YYSongData.h"

static const NSUInteger kMaxCacheCount = 10;
static const NSUInteger kMaxCacheSize = 100 * 1024 * 1024;
static const NSUInteger kMaxSingleSongSize = 20 * 1024 * 1024;

@interface XCMusicMemoryCache ()
@property (nonatomic, strong) NSCache<NSString *, NSData *> *audioCache;
@property (nonatomic, copy) NSString *currentSongId;
@property (nonatomic, strong) NSMutableSet<NSString *> *downloadingSongs;
@property (nonatomic, strong) dispatch_queue_t downloadQueue;
@property (nonatomic, strong) NSFileManager *fileManager;
@property (nonatomic, strong) NSString *tempDirectory;
@end

@implementation XCMusicMemoryCache

+ (instancetype)sharedInstance {
    static XCMusicMemoryCache *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

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
- (BOOL)isCached:(NSString *)songId {
    if (!songId || songId.length == 0) {
        return NO;
    }
    return [self.audioCache objectForKey:songId] != nil;
}

- (NSData *)dataForSongId:(NSString *)songId {
    if (!songId || songId.length == 0) {
        return nil;
    }
    return [self.audioCache objectForKey:songId];
}

#pragma mark - 写入
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

- (void)downloadAndCache:(XC_YYSongData *)song {
    if (!song || !song.songId || !song.songUrl) {
        return;
    }
    NSString *songId = song.songId;
    NSString *originalUrl = song.songUrl;
    
    if ([self isCached:songId]) {
        return;
    }
    
    @synchronized (self.downloadingSongs) {
        if ([self.downloadingSongs containsObject:songId]) {
            return;
        }
        [self.downloadingSongs addObject:songId];
    }
    
    NSString *trimmedUrl = [originalUrl stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *encodedUrl = [trimmedUrl stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSURL *url = [NSURL URLWithString:encodedUrl];
    if (!url) {
        @synchronized (self.downloadingSongs) {
            [self.downloadingSongs removeObject:songId];
        }
        return;
    }
    
    if (![url.scheme isEqualToString:@"http"] && ![url.scheme isEqualToString:@"https"]) {
        @synchronized (self.downloadingSongs) {
            [self.downloadingSongs removeObject:songId];
        }
        return;
    }
    
    dispatch_async(self.downloadQueue, ^{
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        NSURLSessionDataTask *task = [[NSURLSession sharedSession]
            dataTaskWithRequest:request
            completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                @synchronized (self.downloadingSongs) {
                    [self.downloadingSongs removeObject:songId];
                }
                if (error) {
                    return;
                }
                if (data && data.length > 0) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self cacheData:data forSongId:songId];
                    });
                }
            }];
        [task resume];
    });
}

#pragma mark - 当前播放管理
- (void)setCurrentPlayingSong:(NSString *)songId {
    self.currentSongId = songId;
    NSData *data = [self.audioCache objectForKey:songId];
    if (data) {
        [self.audioCache setObject:data forKey:songId cost:data.length];
    }
}

- (NSURL *)localURLForSongId:(NSString *)songId {
    NSData *data = [self dataForSongId:songId];
    if (!data) {
        return nil;
    }
    NSString *fileName = [NSString stringWithFormat:@"%@.mp3", songId];
    NSString *filePath = [self.tempDirectory stringByAppendingPathComponent:fileName];
    
    if ([self.fileManager fileExistsAtPath:filePath]) {
        return [NSURL fileURLWithPath:filePath];
    }
    
    if ([data writeToFile:filePath atomically:YES]) {
        return [NSURL fileURLWithPath:filePath];
    }
    return nil;
}

#pragma mark - 清理
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

- (void)clearAllCache {
    [self.audioCache removeAllObjects];
    self.currentSongId = nil;
    NSArray *files = [self.fileManager contentsOfDirectoryAtPath:self.tempDirectory error:nil];
    for (NSString *file in files) {
        NSString *path = [self.tempDirectory stringByAppendingPathComponent:file];
        [self.fileManager removeItemAtPath:path error:nil];
    }
}

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
