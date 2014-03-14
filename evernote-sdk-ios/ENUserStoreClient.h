//
//  ENUserStoreClient.h
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 3/13/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import "ENStoreClient.h"
#import "EvernoteSDK.h"

@interface ENUserStoreClient : ENStoreClient
+ (ENUserStoreClient *)userStoreClientWithUrl:(NSString *)url authenticationToken:(NSString *)authenticationToken;

- (void)getUserWithSuccess:(void(^)(EDAMUser *user))success
                   failure:(void(^)(NSError *error))failure;
- (void)authenticateToBusinessWithSuccess:(void(^)(EDAMAuthenticationResult *authenticationResult))success
                                  failure:(void(^)(NSError *error))failure;
@end
