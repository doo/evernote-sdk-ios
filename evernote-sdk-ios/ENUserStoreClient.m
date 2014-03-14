//
//  ENUserStoreClient.m
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 3/13/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import "ENUserStoreClient.h"
#import "EvernoteSDK.h"
#import "Thrift.h"

@interface ENUserStoreClient ()
@property (nonatomic, strong) EDAMUserStoreClient * client;
@property (nonatomic, strong) NSString * authenticationToken;
@end

@implementation ENUserStoreClient
+ (ENUserStoreClient *)userStoreClientWithUrl:(NSString *)url authenticationToken:(NSString *)authenticationToken
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

- (void)getUserWithSuccess:(void(^)(EDAMUser *user))success
                   failure:(void(^)(NSError *error))failure
{
    [self invokeAsyncIdBlock:^id {
        return [self.client getUser:[self authenticationToken]];
    } success:success failure:failure];
}

- (void)authenticateToBusinessWithSuccess:(void(^)(EDAMAuthenticationResult *authenticationResult))success
                                  failure:(void(^)(NSError *error))failure
{
    [self invokeAsyncIdBlock:^id {
        return [self.client authenticateToBusiness:[self authenticationToken]];
    } success:success failure:failure];
}
@end
