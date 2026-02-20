//
//  XCAudioCachePathUtils.m
//  Spotify - clone
//

#import "XCAudioCachePathUtils.h"

@interface XCAudioCachePathUtils ()
@property (nonatomic, copy, readwrite) NSString *tempDirectory;
@property (nonatomic, copy, readwrite) NSString *cacheDirectory;
@property (nonatomic, copy, readwrite) NSString *manifestPath;
@end

@implementation XCAudioCachePathUtils

+ (instancetype)sharedInstance {
  static XCAudioCachePathUtils *instance;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
      instance = [[self alloc] init];
  });
  return instance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
      [self setupPaths];
      [self createDirectories];
  }
  return self;
}

- (void)setupPaths {
  NSString *tmpDir = NSTemporaryDirectory();
  _tempDirectory = [tmpDir stringByAppendingPathComponent:@"MusicTemp"];

  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
  NSString *cacheDir = paths.firstObject;
  _cacheDirectory = [cacheDir stringByAppendingPathComponent:@"MusicCache"];

  _manifestPath = [_cacheDirectory stringByAppendingPathComponent:@"index.plist"];
}

- (void)createDirectories {
  NSFileManager *fm = [NSFileManager defaultManager];
  NSError *error;

  if (![fm fileExistsAtPath:_tempDirectory]) {
      [fm createDirectoryAtPath:_tempDirectory
    withIntermediateDirectories:YES
                     attributes:nil
                          error:&error];
      if (error) {
          NSLog(@"[CachePath] Create temp dir failed: %@", error.localizedDescription);
      } else {
          NSLog(@"[CachePath] Temp dir: %@", _tempDirectory);
      }
  }

  if (![fm fileExistsAtPath:_cacheDirectory]) {
      [fm createDirectoryAtPath:_cacheDirectory
    withIntermediateDirectories:YES
                     attributes:nil
                          error:&error];
      if (error) {
          NSLog(@"[CachePath] Create cache dir failed: %@", error.localizedDescription);
      } else {
          NSLog(@"[CachePath] Cache dir: %@", _cacheDirectory);
      }
  }
}

#pragma mark - 文件扩展名推断

- (NSString *)fileExtensionFromURL:(NSURL *)originalURL {
    if (!originalURL) {
        return @"mp3"; // 默认返回 mp3
    }
    
    NSString *urlString = originalURL.absoluteString.lowercaseString;
    
    // 根据 URL 后缀判断音频格式
    if ([urlString hasSuffix:@".m4a"] || [urlString hasSuffix:@".mp4"] || 
        [urlString hasSuffix:@".m4p"] || [urlString containsString:@".m4a?"]) {
        return @"m4a";
    } else if ([urlString hasSuffix:@".aac"] || [urlString containsString:@".aac?"]) {
        return @"aac";
    } else if ([urlString hasSuffix:@".wav"] || [urlString hasSuffix:@".wave"] || 
               [urlString containsString:@".wav?"]) {
        return @"wav";
    } else if ([urlString hasSuffix:@".flac"] || [urlString containsString:@".flac?"]) {
        return @"flac";
    } else if ([urlString hasSuffix:@".ogg"] || [urlString containsString:@".ogg?"]) {
        return @"ogg";
    } else if ([urlString hasSuffix:@".wma"] || [urlString containsString:@".wma?"]) {
        return @"wma";
    } else if ([urlString hasSuffix:@".mp3"] || [urlString containsString:@".mp3?"]) {
        return @"mp3";
    }
    
    // 默认返回 mp3（最常见格式）
    return @"mp3";
}

#pragma mark - L2 临时文件路径

- (NSString *)tempFilePathForSongId:(NSString *)songId {
  NSString *fileName = [NSString stringWithFormat:@"%@_tmp.mp3", songId];
  return [_tempDirectory stringByAppendingPathComponent:fileName];
}

- (NSString *)tempFilePathForSongId:(NSString *)songId originalURL:(NSURL *)originalURL {
    NSString *ext = [self fileExtensionFromURL:originalURL];
    // 使用 _tmp 前缀而非 .tmp 后缀，确保 AVPlayer 能正确识别音频格式
    // 例如: 2140776005_tmp.m4a (正确) vs 2140776005.m4a.tmp (错误)
    NSString *fileName = [NSString stringWithFormat:@"%@_tmp.%@", songId, ext];
    return [_tempDirectory stringByAppendingPathComponent:fileName];
}

#pragma mark - L3 缓存文件路径

- (NSString *)cacheFilePathForSongId:(NSString *)songId {
  NSString *fileName = [NSString stringWithFormat:@"%@.mp3", songId];
  return [_cacheDirectory stringByAppendingPathComponent:fileName];
}

- (NSString *)cacheFilePathForSongId:(NSString *)songId originalURL:(NSURL *)originalURL {
    NSString *ext = [self fileExtensionFromURL:originalURL];
    NSString *fileName = [NSString stringWithFormat:@"%@.%@", songId, ext];
    return [_cacheDirectory stringByAppendingPathComponent:fileName];
}

@end
