//
//  XCPlaylistSongRelation.mm
//  Spotify - clone
//
//  Created by 红尘一笑 on 2026/2/22.
//

#import "XCPlaylistSongRelation.h"

@implementation XCPlaylistSongRelation

WCDB_IMPLEMENTATION(XCPlaylistSongRelation)
WCDB_SYNTHESIZE(playlistId)
WCDB_SYNTHESIZE(songId)
WCDB_SYNTHESIZE(addedTime)
WCDB_SYNTHESIZE(sortOrder)

- (instancetype)init {
    self = [super init];
    if (self) {
        _playlistId = @"";
        _songId = @"";
        _addedTime = 0;
        _sortOrder = 0;
    }
    return self;
}

@end
