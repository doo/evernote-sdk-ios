//
//  ENStoreClient.h
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 3/11/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import <Foundation/Foundation.h>
@class ENStoreClient;

@interface ENStoreClient : NSObject
- (void)invokeAsyncBoolBlock:(BOOL(^)())block
                     success:(void(^)(BOOL val))success
                     failure:(void(^)(NSError * error))failure;
- (void)invokeAsyncIdBlock:(id(^)())block
                   success:(void(^)(id))success
                   failure:(void(^)(NSError * error))failure;
- (void)invokeAsyncInt32Block:(int32_t(^)())block
                      success:(void(^)(int32_t val))success
                      failure:(void(^)(NSError * error))failure;
- (void)invokeAsyncVoidBlock:(void(^)())block
                     success:(void(^)())success
                     failure:(void(^)(NSError * error))failure;
@end
