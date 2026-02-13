//
//  XCAudioSongCacheInfo.m
//  Spotify - clone
//

#import "XCAudioSongCacheInfo.h"

@implementation XCAudioSongCacheInfo

- (instancetype)initWithSongId:(NSString *)songId totalSize:(NSInteger)totalSize {
    self = [super init];
    if (self) {
        _songId = songId;
        _totalSize = totalSize;
        _cacheTime = [[NSDate date] timeIntervalSince1970];
        _lastPlayTime = _cacheTime;
        _playCount = 0;
    }
    return self;
}

- (void)updatePlayTime {
    _lastPlayTime = [[NSDate date] timeIntervalSince1970];
    _playCount++;
}

@end
