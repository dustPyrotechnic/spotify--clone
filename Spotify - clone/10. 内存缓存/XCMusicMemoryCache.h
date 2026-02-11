//
//  XCMusicMemoryCache.h
//  Spotify - clone
//

#import <Foundation/Foundation.h>

@class XC_YYSongData;

NS_ASSUME_NONNULL_BEGIN

@interface XCMusicMemoryCache : NSObject

+ (instancetype)sharedInstance;

- (BOOL)isCached:(NSString *)songId;
- (nullable NSData *)dataForSongId:(NSString *)songId;
- (void)cacheData:(NSData *)data forSongId:(NSString *)songId;
- (void)downloadAndCache:(XC_YYSongData *)song;
- (void)setCurrentPlayingSong:(NSString *)songId;
- (nullable NSURL *)localURLForSongId:(NSString *)songId;
- (void)removeCache:(NSString *)songId;
- (void)clearAllCache;
- (NSUInteger)currentCacheSize;
- (NSUInteger)cachedSongCount;

@end

NS_ASSUME_NONNULL_END
