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

- (NSString *)tempFilePathForSongId:(NSString *)songId {
  NSString *fileName = [NSString stringWithFormat:@"%@.mp3.tmp", songId];
  return [_tempDirectory stringByAppendingPathComponent:fileName];
}

- (NSString *)cacheFilePathForSongId:(NSString *)songId {
  NSString *fileName = [NSString stringWithFormat:@"%@.mp3", songId];
  return [_cacheDirectory stringByAppendingPathComponent:fileName];
}

@end
