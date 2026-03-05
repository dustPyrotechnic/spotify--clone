//
//  XCUserModel.m
//  Spotify - clone
//

#import "XCUserModel.h"

@implementation XCUserModel

+ (instancetype)modelWithDictionary:(NSDictionary *)dict {
    if (![dict isKindOfClass:[NSDictionary class]]) return nil;
    XCUserModel *model    = [[XCUserModel alloc] init];
    model.userId          = dict[@"userId"]       ?: @"";
    model.username        = dict[@"username"]     ?: @"";
    model.loginAt         = dict[@"loginAt"]      ?: @"";
    model.accessToken     = dict[@"accessToken"]  ?: @"";
    model.refreshToken    = dict[@"refreshToken"] ?: @"";

    id roles = dict[@"roles"];
    if ([roles isKindOfClass:[NSArray class]]) {
        NSMutableArray *strs = [NSMutableArray array];
        for (id r in roles) {
            if ([r isKindOfClass:[NSString class]]) [strs addObject:r];
        }
        model.roles = [strs copy];
    } else {
        model.roles = @[];
    }
    return model;
}

- (NSString *)rolesString {
    return self.roles.count > 0 ? [self.roles componentsJoinedByString:@", "] : @"user";
}

@end
