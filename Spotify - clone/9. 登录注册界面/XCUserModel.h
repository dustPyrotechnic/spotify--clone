//
//  XCUserModel.h
//  Spotify - clone
//
//  登录接口响应数据模型，使用 YYModel 解析
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface XCUserModel : NSObject

@property (nonatomic, copy) NSString *userId;
@property (nonatomic, copy) NSString *username;
@property (nonatomic, copy) NSArray<NSString *> *roles;
@property (nonatomic, copy) NSString *loginAt;
@property (nonatomic, copy) NSString *accessToken;
@property (nonatomic, copy) NSString *refreshToken;

/// 从登录响应 data 字典创建模型
+ (instancetype)modelWithDictionary:(NSDictionary *)dict;

/// 角色列表格式化为可读字符串（如 "admin, user"）
- (NSString *)rolesString;

@end

NS_ASSUME_NONNULL_END
