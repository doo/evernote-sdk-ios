//
//  ENUserStoreClient.m
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 3/13/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import "ENUserStoreClient.h"
#import "ENSDK.h"
#import "Thrift.h"

@interface ENUserStoreClient ()
@property (nonatomic, strong) EDAMUserStoreClient * client;
@property (nonatomic, strong) NSString * authenticationToken;
@end

@implementation ENUserStoreClient
+ (instancetype)userStoreClientWithUrl:(NSString *)url authenticationToken:(NSString *)authenticationToken
{
    return [[self alloc] initWithUserStoreUrl:url authenticationToken:authenticationToken];
}

- (id)initWithUserStoreUrl:(NSString *)userStoreUrl authenticationToken:(NSString *)authenticationToken
{
    self = [super init];
    if (self) {
        NSURL * url = [NSURL URLWithString:userStoreUrl];
        THTTPClient * transport = [[THTTPClient alloc] initWithURL:url];
        TBinaryProtocol * protocol = [[TBinaryProtocol alloc] initWithTransport:transport];
        self.client = [[EDAMUserStoreClient alloc] initWithProtocol:protocol];
        self.authenticationToken = authenticationToken;
    }
    return self;
}

#pragma mark - UserStore methods

- (void)checkVersionWithClientName:(NSString *)clientName
                  edamVersionMajor:(int16_t)edamVersionMajor
                  edamVersionMinor:(int16_t)edamVersionMinor
                           success:(void(^)(BOOL versionOK))success
                           failure:(void(^)(NSError *error))failure

{
    [self invokeAsyncBoolBlock:^BOOL{
        return [self.client checkVersion:clientName edamVersionMajor:edamVersionMajor edamVersionMinor:edamVersionMinor];
    } success:success failure:failure];
}

- (void)getBootstrapInfoWithLocale:(NSString *)locale
                           success:(void(^)(EDAMBootstrapInfo *info))success
                           failure:(void(^)(NSError *error))failure
{
    [self invokeAsyncIdBlock:^id {
        return [self.client getBootstrapInfo:locale];
    } success:success failure:failure];
}

- (void)getUserWithSuccess:(void(^)(EDAMUser *user))success
                   failure:(void(^)(NSError *error))failure
{
    [self invokeAsyncIdBlock:^id {
        return [self.client getUser:self.authenticationToken];
    } success:success failure:failure];
}

- (void)getPublicUserInfoWithUsername:(NSString *)username
                              success:(void(^)(EDAMPublicUserInfo *info))success
                              failure:(void(^)(NSError *error))failure
{
    [self invokeAsyncIdBlock:^id {
        return [self.client getPublicUserInfo:username];
    } success:success failure:failure];
}

- (void)getPremiumInfoWithSuccess:(void(^)(EDAMPremiumInfo *info))success
                          failure:(void(^)(NSError *error))failure
{
    [self invokeAsyncIdBlock:^id {
        return [self.client getPremiumInfo:self.authenticationToken];
    } success:success failure:failure];
}

- (void)getNoteStoreUrlWithSuccess:(void(^)(NSString *noteStoreUrl))success
                           failure:(void(^)(NSError *error))failure
{
    [self invokeAsyncIdBlock:^id {
        return [self.client getNoteStoreUrl:self.authenticationToken];
    } success:success failure:failure];
}

- (void)authenticateToBusinessWithSuccess:(void(^)(EDAMAuthenticationResult *authenticationResult))success
                                  failure:(void(^)(NSError *error))failure
{
    [self invokeAsyncIdBlock:^id {
        return [self.client authenticateToBusiness:self.authenticationToken];
    } success:success failure:failure];
}

- (void)revokeLongSessionWithAuthenticationToken:(NSString*)authenticationToken
                                         success:(void(^)())success
                                         failure:(void(^)(NSError *error))failure {
    [self invokeAsyncVoidBlock:^void {
        [self.client revokeLongSession:authenticationToken];
    } success:success failure:failure];
}
@end
