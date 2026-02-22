//
//  XCResourceLoaderManager.m
//  Spotify - clone
//
//  Phase B: 实现边下边播，支持 L1 分段缓存
//

#import "XCResourceLoaderManager.h"
#import "../11. 音频缓存/L1/XCMemoryCacheManager.h"
#import "../11. 音频缓存/L3/XCPersistentCacheManager.h"
#import "../11. 音频缓存/XCAudioCacheConst.h"
#import "../6. 网络请求部分/XCNetworkManager.h"

// 内部使用的加载任务类
@interface XCResourceLoadingTask : NSObject
@property (nonatomic, strong) AVAssetResourceLoadingRequest *loadingRequest;
@property (nonatomic, strong) NSURLSessionDataTask *dataTask;
@property (nonatomic, copy) NSString *songId;
@property (nonatomic, copy) NSString *originalURLString;
@property (nonatomic, assign) NSRange requestedRange;
@property (nonatomic, strong) NSMutableData *receivedData;
@property (nonatomic, assign) NSInteger startSegmentIndex;
@property (nonatomic, assign) long long totalContentLength;  // 文件总长度
@property (nonatomic, copy) NSString *contentType;  // 从 HTTP 响应获取的真实 Content-Type
@property (nonatomic, assign) BOOL isContentInfoRequest;  // 是否为 AVPlayer 的 Content Info 探测请求（bytes=0-1）
@end

@implementation XCResourceLoadingTask
@end

#pragma mark - XCResourceLoaderManager

@interface XCResourceLoaderManager ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, XCResourceLoadingTask *> *loadingTasks;
@property (nonatomic, strong) NSURLSession *urlSession;
@property (nonatomic, strong) dispatch_queue_t taskQueue;
@property (nonatomic, strong) dispatch_queue_t delegateQueue;  // 与 setDelegate:queue: 一致，用于 respondWithData/finishLoading
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *songTotalLengthCache;  // songId -> totalLength，避免 L1 返回部分数据时 contentLength 错误导致音频截断
@end

@implementation XCResourceLoaderManager
static XCResourceLoaderManager *instance = nil;

// 使用 +load 方法实现饿汉式单例
+ (void)load {
    instance = [[super allocWithZone:NULL] init];
}

+ (instancetype)sharedInstance {
    return instance;
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    return [self sharedInstance];
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

- (id)mutableCopyWithZone:(NSZone *)zone {
    return self;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _loadingTasks = [NSMutableDictionary dictionary];
        _songTotalLengthCache = [NSMutableDictionary dictionary];
        _taskQueue = dispatch_queue_create("com.spotifyclone.resourceloader", DISPATCH_QUEUE_SERIAL);
        // 与 XCMusicPlayerModel 中 setDelegate:queue: 使用的队列一致
        _delegateQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        
        // 配置 URLSession
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        _urlSession = [NSURLSession sessionWithConfiguration:config];
        
        NSLog(@"[ResourceLoader] 初始化完成");
    }
    return self;
}

#pragma mark - URL 转换

// 自定义 scheme: streaming://songId?url=encodedOriginalURL
- (NSURL *)streamingURLFromOriginalURL:(NSURL *)originalURL songId:(NSString *)songId {
    if (!originalURL || !songId) return nil;
    
    NSString *encodedURL = [originalURL.absoluteString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *streamingURLString = [NSString stringWithFormat:@"streaming://%@?url=%@", songId, encodedURL];
    return [NSURL URLWithString:streamingURLString];
}

- (NSURL *)originalURLFromStreamingURL:(NSURL *)streamingURL {
    if (!streamingURL) return nil;
    
    NSURLComponents *components = [NSURLComponents componentsWithURL:streamingURL resolvingAgainstBaseURL:NO];
    NSString *urlParam = nil;
    for (NSURLQueryItem *item in components.queryItems) {
        if ([item.name isEqualToString:@"url"]) {
            urlParam = item.value;
            break;
        }
    }
    
    if (urlParam) {
        NSString *decodedURL = [urlParam stringByRemovingPercentEncoding];
        return [NSURL URLWithString:decodedURL];
    }
    return nil;
}

- (NSString *)songIdFromStreamingURL:(NSURL *)streamingURL {
    if (!streamingURL) return nil;
    // streaming://songId?url=xxx
    return streamingURL.host;
}

#pragma mark - AVAssetResourceLoaderDelegate

// 拦截 AVPlayer 的资源加载请求
- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader 
shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest {
    
    NSURL *url = loadingRequest.request.URL;
    NSLog(@"[ResourceLoader] 拦截请求: %@", url);
    
    // 只处理自定义 scheme
    if (![url.scheme isEqualToString:@"streaming"]) {
        NSLog(@"[ResourceLoader] 非 streaming scheme，不处理");
        return NO;
    }
    
    NSString *songId = [self songIdFromStreamingURL:url];
    NSURL *originalURL = [self originalURLFromStreamingURL:url];
    
    if (!songId || !originalURL) {
        NSLog(@"[ResourceLoader] 解析 URL 失败");
        [loadingRequest finishLoadingWithError:[NSError errorWithDomain:@"XCResourceLoader" 
                                                                   code:-1 
                                                               userInfo:@{NSLocalizedDescriptionKey: @"URL 解析失败"}]];
        return NO;
    }
    
    NSLog(@"[ResourceLoader] songId: %@, 原始URL: %@", songId, originalURL);
    
    // 解析 Range 请求（优先使用 dataRequest，兼容 Content Info 探测请求）
    NSRange range = [self parseRangeFromRequest:loadingRequest];
    NSLog(@"[ResourceLoader] 请求范围: %@, 长度: %lu", NSStringFromRange(range), (unsigned long)range.length);
    
    // 检测 Content Info 探测请求：AVPlayer 首次请求 bytes=0-1 以获取 Content-Range 和 Content-Type
    // 对此类请求：只填充 content info 并 finishLoading，切勿调用 respondWithData（会导致播放失败）
    BOOL isContentInfoRequest = (loadingRequest.contentInformationRequest != nil);
    if (isContentInfoRequest) {
        NSLog(@"[ResourceLoader] 检测到 Content Info 探测请求，将只返回元数据不返回数据");
    }
    
    // 创建任务
    XCResourceLoadingTask *task = [[XCResourceLoadingTask alloc] init];
    task.loadingRequest = loadingRequest;
    task.songId = songId;
    task.originalURLString = originalURL.absoluteString;
    task.requestedRange = range;
    task.receivedData = [NSMutableData data];
    task.startSegmentIndex = range.location / kAudioSegmentSize;
    task.totalContentLength = 0;
    task.isContentInfoRequest = isContentInfoRequest;
    
    NSString *taskKey = [NSString stringWithFormat:@"%p", loadingRequest];
    dispatch_sync(self.taskQueue, ^{
        self.loadingTasks[taskKey] = task;
    });
    
    // ⚠️ 关键点：对于网络请求，先立即返回一个预估的 contentInformation
    // 这样 AVPlayer 不会超时等待，给我们时间完成网络请求
    // 使用一个预估的大文件长度（100MB），实际长度从 HTTP 响应获取后会更新
    [self fillContentInformation:task totalLength:100 * 1024 * 1024];
    
    // 先尝试从 L3 完整缓存读取
    NSURL *l3URL = [[XCPersistentCacheManager sharedInstance] cachedURLForSongId:songId];
    if (l3URL) {
        if (isContentInfoRequest) {
            // Content Info 请求 + L3 命中：直接返回元数据，不读取文件内容
            NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:l3URL.path error:nil];
            long long fileSize = [attrs fileSize];
            if (fileSize > 0) {
                dispatch_sync(self.taskQueue, ^{
                    self.songTotalLengthCache[songId] = @(fileSize);
                });
            }
            task.originalURLString = l3URL.absoluteString;
            task.contentType = [self contentTypeForURLString:l3URL.absoluteString];
            [self fillContentInformation:task totalLength:fileSize];
            [task.loadingRequest finishLoading];
            NSLog(@"[ResourceLoader] ✅ Content Info 请求 L3 命中，直接返回元数据 size=%lld", fileSize);
            dispatch_async(self.taskQueue, ^{ [self.loadingTasks removeObjectForKey:taskKey]; });
            return YES;
        }
        NSLog(@"[ResourceLoader] ✅ L3 完整缓存命中");
        [self respondWithLocalFile:l3URL forTask:task];
        return YES;
    }
    
    // Content Info 请求且无 L3：直接走网络获取 bytes=0-1，不查 L1（探测请求无需缓存数据）
    if (isContentInfoRequest) {
        NSLog(@"[ResourceLoader] ⬇️ Content Info 请求，开始网络请求 bytes=0-1");
        [self startNetworkRequestForTask:task];
        return YES;
    }
    
    // 尝试从 L1 分段缓存组装数据
    // 注意：如果是首次请求（range.location == 0），必须有完整的前几段数据才使用缓存
    // 否则直接走网络，避免返回不完整的音频头导致播放器失败
    NSData *cachedData = [self dataFromL1CacheForSongId:songId range:range];
    BOOL shouldUseCache = NO;
    
    if (cachedData && cachedData.length > 0) {
        if (range.location == 0) {
            // 首次请求（range.location == 0）
            // 情况1: 请求整个文件（range.length == NSUIntegerMax），只要有足够数据就返回
            // 情况2: 请求特定范围，缓存必须覆盖该范围
            BOOL isRequestingFullFile = (range.length == NSUIntegerMax);
            if (isRequestingFullFile) {
                // 请求整个文件：只要有至少一个完整分段（512KB）就使用缓存
                // 播放器会基于返回的数据继续请求剩余部分
                if (cachedData.length >= kAudioSegmentSize) {
                    shouldUseCache = YES;
                }
            } else {
                // 请求特定范围：缓存必须覆盖该范围
                if (cachedData.length >= range.length) {
                    shouldUseCache = YES;
                }
            }
            
            if (!shouldUseCache) {
                NSLog(@"[ResourceLoader] L1 缓存数据不足（%lu < %@），不使用缓存", 
                      (unsigned long)cachedData.length, 
                      isRequestingFullFile ? @"512KB(min)" : [NSString stringWithFormat:@"%lu", (unsigned long)range.length]);
            }
        } else {
            // 非首次请求（拖动进度条）：有缓存就用
            shouldUseCache = YES;
        }
    }
    
    if (shouldUseCache) {
        NSLog(@"[ResourceLoader] ✅ L1 缓存命中，大小: %lu", (unsigned long)cachedData.length);
        [self respondWithCacheData:cachedData songId:songId forTask:task];
        return YES;
    }
    
    // 缓存未命中或不完整，清理旧的 L1 缓存，发起网络请求
    NSLog(@"[ResourceLoader] 🧹 清理旧的 L1 缓存");
    [[XCMemoryCacheManager sharedInstance] clearSegmentsForSongId:songId];
    
    // ⚠️ 清理后重新检查，确保没有残留的损坏数据
    NSData *verifyClean = [self dataFromL1CacheForSongId:songId range:range];
    if (verifyClean) {
        NSLog(@"[ResourceLoader] ⚠️ 缓存清理后仍有数据，强制清理所有相关缓存");
        [[XCMemoryCacheManager sharedInstance] clearAllCache];
    }
    
    NSLog(@"[ResourceLoader] ⬇️ 缓存未命中或不完整，开始网络请求");
    [self startNetworkRequestForTask:task];
    
    return YES;
}

// 请求被取消
- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader 
didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
    NSLog(@"[ResourceLoader] 取消请求: %@", loadingRequest.request.URL);
    
    NSString *taskKey = [NSString stringWithFormat:@"%p", loadingRequest];
    __block XCResourceLoadingTask *task = nil;
    dispatch_sync(self.taskQueue, ^{
        task = self.loadingTasks[taskKey];
        [self.loadingTasks removeObjectForKey:taskKey];
    });
    
    if (task.dataTask) {
        [task.dataTask cancel];
    }
}

#pragma mark - Range 解析

/// 解析请求范围，优先使用 dataRequest（AVPlayer 的真实需求），fallback 到 HTTP Range 头
- (NSRange)parseRangeFromRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
    AVAssetResourceLoadingDataRequest *dataReq = loadingRequest.dataRequest;
    if (dataReq) {
        long long offset = dataReq.requestedOffset;
        long long length = dataReq.requestedLength;
        if (dataReq.requestsAllDataToEndOfResource) {
            return NSMakeRange((NSUInteger)offset, NSUIntegerMax);
        }
        if (length > 0) {
            return NSMakeRange((NSUInteger)offset, (NSUInteger)length);
        }
    }
    
    // Fallback: 从 HTTP Range 头解析
    NSString *rangeHeader = loadingRequest.request.allHTTPHeaderFields[@"Range"];
    if (!rangeHeader) return NSMakeRange(0, NSUIntegerMax);
    
    if ([rangeHeader hasPrefix:@"bytes="]) {
        NSString *rangeValue = [rangeHeader substringFromIndex:6];
        NSArray *parts = [rangeValue componentsSeparatedByString:@"-"];
        if (parts.count >= 1) {
            long long start = [parts[0] longLongValue];
            long long end = LLONG_MAX;
            if (parts.count >= 2 && [parts[1] length] > 0) {
                end = [parts[1] longLongValue];
            }
            if (end == LLONG_MAX || end < start) {
                return NSMakeRange((NSUInteger)start, NSUIntegerMax);
            }
            return NSMakeRange((NSUInteger)start, (NSUInteger)(end - start + 1));
        }
    }
    return NSMakeRange(0, NSUIntegerMax);
}

#pragma mark - L1 缓存查询

- (NSData *)dataFromL1CacheForSongId:(NSString *)songId range:(NSRange)range {
    if (!songId || range.length == 0) return nil;
    
    XCMemoryCacheManager *l1 = [XCMemoryCacheManager sharedInstance];
    NSInteger segmentSize = kAudioSegmentSize;  // 512KB
    
    // 计算涉及的分段范围
    NSInteger startSegment = range.location / segmentSize;
    NSInteger endSegment = (range.location + range.length - 1) / segmentSize;
    
    NSMutableData *result = [NSMutableData data];
    
    for (NSInteger i = startSegment; i <= endSegment; i++) {
        NSData *segmentData = [l1 segmentDataForSongId:songId segmentIndex:i];
        if (!segmentData) {
            // 有分段缺失，无法组装完整数据
            NSLog(@"[ResourceLoader] L1 分段 %@_%ld 缺失", songId, (long)i);
            return nil;
        }
        
        // ⚠️ 数据有效性检查：分段大小小于 1KB 视为损坏数据
        if (segmentData.length < 1024) {
            NSLog(@"[ResourceLoader] L1 分段 %@_%ld 数据损坏 (size=%lu < 1KB)，视为缺失", 
                  songId, (long)i, (unsigned long)segmentData.length);
            return nil;
        }
        
        [result appendData:segmentData];
    }
    
    // 截取精确的范围
    NSInteger offsetInFirstSegment = range.location % segmentSize;
    NSInteger actualLength = range.length;
    
    if (actualLength == NSUIntegerMax) {
        // 请求到文件末尾
        actualLength = result.length - offsetInFirstSegment;
    }
    
    // 确保不超出数据范围
    actualLength = MIN(actualLength, result.length - offsetInFirstSegment);
    
    if (offsetInFirstSegment > 0 || result.length > actualLength) {
        if (offsetInFirstSegment + actualLength <= result.length) {
            return [result subdataWithRange:NSMakeRange(offsetInFirstSegment, actualLength)];
        }
    }
    
    return result;
}

#pragma mark - 响应播放器

// 使用本地文件响应（L3 缓存）
- (void)respondWithLocalFile:(NSURL *)fileURL forTask:(XCResourceLoadingTask *)task {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *data = [NSData dataWithContentsOfURL:fileURL];
        dispatch_queue_t queue = self.delegateQueue ?: dispatch_get_main_queue();
        dispatch_async(queue, ^{
            if (data) {
                if (data.length > 0 && task.songId) {
                    dispatch_async(self.taskQueue, ^{
                        self.songTotalLengthCache[task.songId] = @(data.length);
                    });
                }
                task.originalURLString = fileURL.absoluteString;
                [self fillContentInformation:task totalLength:data.length];
                [task.loadingRequest.dataRequest respondWithData:data];
                [task.loadingRequest finishLoading];
                NSLog(@"[ResourceLoader] ✅ 本地文件响应完成，大小: %lu", (unsigned long)data.length);
            } else {
                [task.loadingRequest finishLoadingWithError:[NSError errorWithDomain:@"XCResourceLoader"
                                                                               code:-2
                                                                           userInfo:@{NSLocalizedDescriptionKey: @"读取本地文件失败"}]];
            }
            NSString *taskKey = [NSString stringWithFormat:@"%p", task.loadingRequest];
            dispatch_async(self.taskQueue, ^{ [self.loadingTasks removeObjectForKey:taskKey]; });
        });
    });
}

// 使用缓存数据响应（L1 缓存）
- (void)respondWithCacheData:(NSData *)data songId:(NSString *)songId forTask:(XCResourceLoadingTask *)task {
    // ⚠️ 关键点：必须立即响应，不能用异步请求！AVPlayer 会超时等待
    // L1 缓存的情况下，使用 URL 推断 Content-Type
    if (!task.contentType) {
        task.contentType = [self contentTypeForURLString:task.originalURLString];
    }
    
    // 使用缓存的 totalLength，避免部分数据时 contentLength=data.length 导致 AVPlayer 认为文件已结束、不再请求剩余部分（音频截断）
    __block long long totalLength = 0;
    dispatch_sync(self.taskQueue, ^{
        totalLength = [self.songTotalLengthCache[songId] longLongValue];
    });
    if (totalLength <= 0) {
        totalLength = MAX((long long)data.length, task.totalContentLength);
    }
    if (totalLength <= 0) {
        totalLength = data.length;
    }
    
    [self fillContentInformation:task totalLength:totalLength];
    
    // 返回数据
    [task.loadingRequest.dataRequest respondWithData:data];
    [task.loadingRequest finishLoading];
    
    NSLog(@"[ResourceLoader] ✅ L1 缓存响应完成，数据大小: %lu, 总长度: %lld, type: %@", 
          (unsigned long)data.length, totalLength, task.contentType);
    
    NSString *taskKey = [NSString stringWithFormat:@"%p", task.loadingRequest];
    dispatch_async(self.taskQueue, ^{
        [self.loadingTasks removeObjectForKey:taskKey];
    });
}

// 填充 contentInformationRequest
- (void)fillContentInformation:(XCResourceLoadingTask *)task totalLength:(long long)totalLength {
    AVAssetResourceLoadingRequest *request = task.loadingRequest;
    
    if (request.contentInformationRequest) {
        // 优先使用从 HTTP 响应获取的真实 Content-Type，如果没有则根据 URL 判断
        NSString *mimeType = task.contentType;
        if (!mimeType || mimeType.length == 0) {
            mimeType = [self contentTypeForURLString:task.originalURLString];
        }
        if (!mimeType || mimeType.length == 0) {
            mimeType = @"audio/mpeg";
        }
        if (totalLength <= 0) {
            totalLength = 1; // 不能为0，否则播放器会认为无效
        }
        
        // AVPlayer 建议使用 UTI 而非 MIME，如 public.mp3 而非 audio/mpeg
        NSString *contentType = [self utiFromMIMEType:mimeType];
        request.contentInformationRequest.contentType = contentType;
        request.contentInformationRequest.contentLength = totalLength;
        request.contentInformationRequest.byteRangeAccessSupported = YES;
        
        NSLog(@"[ResourceLoader] 设置内容信息: type=%@, totalLength=%lld", contentType, totalLength);
    }
}

/// 将 MIME 类型转换为 UTI（Apple 推荐格式，避免使用 MIME 导致播放失败）
- (NSString *)utiFromMIMEType:(NSString *)mimeType {
    if (!mimeType || mimeType.length == 0) return @"public.mp3";
    NSDictionary *map = @{
        @"audio/mpeg": @"public.mp3",
        @"audio/mp4": @"public.m4a",
        @"audio/x-m4a": @"public.m4a",
        @"audio/aac": @"public.aac",
        @"audio/wav": @"public.wav",
        @"audio/wave": @"public.wav",
        @"audio/flac": @"public.flac",
        @"audio/ogg": @"public.ogg",
    };
    NSString *uti = map[[mimeType lowercaseString]];
    return uti ?: @"public.mp3";
}

/// 在 delegate 队列上执行 respondWithData/finishLoading，避免 URLSession 回调线程与 AVPlayer 期望的线程不一致
- (void)respondOnDelegateQueue:(void (^)(void))block forTask:(XCResourceLoadingTask *)task {
    dispatch_queue_t queue = self.delegateQueue ?: dispatch_get_main_queue();
    dispatch_async(queue, ^{
        block();
        NSString *taskKey = [NSString stringWithFormat:@"%p", task.loadingRequest];
        dispatch_async(self.taskQueue, ^{
            [self.loadingTasks removeObjectForKey:taskKey];
        });
    });
}

// 根据 URL 判断音频格式
- (NSString *)contentTypeForURLString:(NSString *)urlString {
    if (!urlString) return @"audio/mpeg";
    
    NSString *lowerURL = [urlString lowercaseString];
    
    if ([lowerURL hasSuffix:@".m4a"] || [lowerURL hasSuffix:@".mp4"] || [lowerURL hasSuffix:@".m4p"]) {
        return @"audio/mp4";
    } else if ([lowerURL hasSuffix:@".aac"]) {
        return @"audio/aac";
    } else if ([lowerURL hasSuffix:@".wav"] || [lowerURL hasSuffix:@".wave"]) {
        return @"audio/wav";
    } else if ([lowerURL hasSuffix:@".flac"]) {
        return @"audio/flac";
    } else if ([lowerURL hasSuffix:@".ogg"]) {
        return @"audio/ogg";
    }
    
    // 默认 MP3
    return @"audio/mpeg";
}

// 获取文件信息（通过 HEAD 请求）
- (void)fetchFileInfo:(NSString *)songId completion:(void (^)(long long totalLength, NSString *contentType))completion {
    // 获取原始 URL
    __block XCResourceLoadingTask *targetTask = nil;
    dispatch_sync(self.taskQueue, ^{
        for (XCResourceLoadingTask *t in self.loadingTasks.allValues) {
            if ([t.songId isEqualToString:songId]) {
                targetTask = t;
                break;
            }
        }
    });
    
    if (!targetTask) {
        completion(0, nil);
        return;
    }
    
    NSURL *originalURL = [NSURL URLWithString:targetTask.originalURLString];
    if (!originalURL) {
        completion(0, nil);
        return;
    }
    
    // 发送 HEAD 请求获取文件信息
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:originalURL];
    request.HTTPMethod = @"HEAD";
    
    NSURLSessionDataTask *headTask = [self.urlSession dataTaskWithRequest:request 
                                                        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        long long length = 0;
        NSString *mimeType = nil;
        
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            
            // 获取 Content-Length
            NSString *contentLength = httpResponse.allHeaderFields[@"Content-Length"];
            if (contentLength) {
                length = [contentLength longLongValue];
            }
            
            // 获取 Content-Type (MIME Type)
            mimeType = httpResponse.MIMEType;
            if (!mimeType || mimeType.length == 0) {
                // 尝试从 header 中获取
                mimeType = httpResponse.allHeaderFields[@"Content-Type"];
                // 移除可能的 charset 部分，如 "audio/mpeg; charset=utf-8"
                if (mimeType) {
                    NSRange semicolonRange = [mimeType rangeOfString:@";"];
                    if (semicolonRange.location != NSNotFound) {
                        mimeType = [mimeType substringToIndex:semicolonRange.location];
                    }
                    mimeType = [mimeType stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                }
            }
        }
        
        NSLog(@"[ResourceLoader] HEAD 请求结果: length=%lld, mimeType=%@", length, mimeType);
        completion(length, mimeType);
    }];
    
    [headTask resume];
}

#pragma mark - 网络请求

- (void)startNetworkRequestForTask:(XCResourceLoadingTask *)task {
    NSURL *originalURL = [NSURL URLWithString:task.originalURLString];
    if (!originalURL) {
        [task.loadingRequest finishLoadingWithError:[NSError errorWithDomain:@"XCResourceLoader" 
                                                                        code:-3 
                                                                    userInfo:@{NSLocalizedDescriptionKey: @"原始 URL 无效"}]];
        return;
    }
    
    // 创建 Range 请求
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:originalURL];
    request.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    
    // 添加 Range Header
    NSString *rangeHeader;
    if (task.requestedRange.length == NSUIntegerMax) {
        rangeHeader = [NSString stringWithFormat:@"bytes=%lu-", (unsigned long)task.requestedRange.location];
    } else {
        rangeHeader = [NSString stringWithFormat:@"bytes=%lu-%lu", 
                      (unsigned long)task.requestedRange.location,
                      (unsigned long)(task.requestedRange.location + task.requestedRange.length - 1)];
    }
    [request setValue:rangeHeader forHTTPHeaderField:@"Range"];
    
    NSLog(@"[ResourceLoader] ⬇️ 网络请求 Range: %@", rangeHeader);
    
    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *dataTask = [self.urlSession dataTaskWithRequest:request 
                                                        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [weakSelf handleNetworkResponse:data response:response error:error forTask:task];
    }];
    
    task.dataTask = dataTask;
    [dataTask resume];
}

- (void)handleNetworkResponse:(NSData *)data 
                     response:(NSURLResponse *)response 
                        error:(NSError *)error 
                      forTask:(XCResourceLoadingTask *)task {
    
    if (error) {
        NSLog(@"[ResourceLoader] ❌ 网络请求失败: %@", error.localizedDescription);
        [self respondOnDelegateQueue:^{
            [task.loadingRequest finishLoadingWithError:error];
        } forTask:task];
        return;
    }
    
    NSLog(@"[ResourceLoader] ✅ 网络请求成功，数据大小: %lu", (unsigned long)data.length);
    
    // 从响应中获取文件信息
    long long totalLength = 0;
    NSString *mimeType = nil;
    NSInteger statusCode = 0;
    
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        statusCode = httpResponse.statusCode;
        
        // 获取 MIME Type
        mimeType = httpResponse.MIMEType;
        if (!mimeType || mimeType.length == 0) {
            mimeType = httpResponse.allHeaderFields[@"Content-Type"];
            // 移除可能的 charset 部分
            if (mimeType) {
                NSRange semicolonRange = [mimeType rangeOfString:@";"];
                if (semicolonRange.location != NSNotFound) {
                    mimeType = [mimeType substringToIndex:semicolonRange.location];
                }
                mimeType = [mimeType stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            }
        }
        
        // 获取文件总长度
        if (statusCode == 206) {
            // 206 Partial Content: 从 Content-Range 获取总长度
            NSString *contentRange = httpResponse.allHeaderFields[@"Content-Range"];
            if (contentRange) {
                NSArray *parts = [contentRange componentsSeparatedByString:@"/"];
                if (parts.count == 2) {
                    totalLength = [parts[1] longLongValue];
                    NSLog(@"[ResourceLoader] 从 Content-Range 获取文件总长度: %lld", totalLength);
                }
            }
        } else if (statusCode == 200) {
            // 200 OK: 服务器不支持 Range，返回的是完整文件
            // 使用 Content-Length 或实际数据长度
            totalLength = data.length;
            NSLog(@"[ResourceLoader] 服务器返回 200 OK（不支持 Range），使用数据长度: %lld", totalLength);
        }
        
        // 备用：从 Content-Length 获取
        if (totalLength == 0) {
            NSString *contentLength = httpResponse.allHeaderFields[@"Content-Length"];
            if (contentLength) {
                totalLength = [contentLength longLongValue];
            }
        }
    }
    
    // 保存到 task
    task.totalContentLength = totalLength;
    if (mimeType && mimeType.length > 0) {
        task.contentType = mimeType;
        NSLog(@"[ResourceLoader] 从响应获取 MIME Type: %@", mimeType);
    }
    
    // 填充内容信息（使用从 HTTP 响应获取的真实 MIME Type）
    [self fillContentInformation:task totalLength:totalLength];
    
    if (task.isContentInfoRequest) {
        // Content Info 探测请求：只填充元数据，不返回数据，不写入 L1
        // 切勿调用 respondWithData，否则会导致 AVPlayer 解析失败（Cannot Open）
        if (totalLength > 0) {
            dispatch_sync(self.taskQueue, ^{
                self.songTotalLengthCache[task.songId] = @(totalLength);
            });
        }
        [self respondOnDelegateQueue:^{
            [task.loadingRequest finishLoading];
            NSLog(@"[ResourceLoader] ✅ Content Info 请求完成，仅返回元数据 totalLength=%lld", totalLength);
        } forTask:task];
        return;
    }
    
    // 存储 totalLength 供 L1 部分命中时使用（避免 contentLength 过小导致音频截断）
    if (totalLength > 0) {
        dispatch_sync(self.taskQueue, ^{
            self.songTotalLengthCache[task.songId] = @(totalLength);
        });
    }
    
    // 将数据写入 L1 缓存（按分段存储）
    [self storeDataToL1:data forTask:task];
    
    // 严格按请求范围返回数据：若服务器返回超出请求范围（如不支持 Range 返回全文件），只传请求部分
    NSData *dataToRespond = data;
    AVAssetResourceLoadingDataRequest *dataReq = task.loadingRequest.dataRequest;
    if (dataReq && data.length > 0) {
        long long reqLength = dataReq.requestedLength;
        if (!dataReq.requestsAllDataToEndOfResource && reqLength > 0 && (long long)data.length > reqLength) {
            NSUInteger length = (NSUInteger)reqLength;
            if (length <= data.length) {
                dataToRespond = [data subdataWithRange:NSMakeRange(0, length)];
                NSLog(@"[ResourceLoader] 截取请求范围 length=%lu（服务器返回 %lu 字节）",
                      (unsigned long)length, (unsigned long)data.length);
            }
        }
    }
    
    // 响应播放器（必须在 delegate 队列上调用）
    NSData *finalData = dataToRespond;
    [self respondOnDelegateQueue:^{
        [task.loadingRequest.dataRequest respondWithData:finalData];
        [task.loadingRequest finishLoading];
        NSLog(@"[ResourceLoader] ✅ 网络响应完成，数据大小: %lu, 文件总长度: %lld",
              (unsigned long)finalData.length, totalLength);
    } forTask:task];
}

#pragma mark - L1 缓存写入

- (void)storeDataToL1:(NSData *)data forTask:(XCResourceLoadingTask *)task {
    NSInteger segmentSize = kAudioSegmentSize;  // 512KB
    NSInteger offset = 0;
    NSInteger segmentIndex = task.startSegmentIndex;
    
    XCMemoryCacheManager *l1 = [XCMemoryCacheManager sharedInstance];
    
    while (offset < data.length) {
        NSInteger remaining = data.length - offset;
        NSInteger chunkSize = MIN(segmentSize, remaining);
        
        NSData *segmentData = [data subdataWithRange:NSMakeRange(offset, chunkSize)];
        [l1 storeSegmentData:segmentData 
                   forSongId:task.songId 
                segmentIndex:segmentIndex];
        
        offset += chunkSize;
        segmentIndex++;
    }
    
    NSLog(@"[ResourceLoader] 💾 数据已写入 L1 缓存，分段数: %ld", (long)(segmentIndex - task.startSegmentIndex));
}

@end
