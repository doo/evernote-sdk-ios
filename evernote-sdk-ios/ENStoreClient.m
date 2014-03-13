//
//  ENStoreClient.m
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 3/11/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import "ENStoreClient.h"

@implementation ENStoreClient
- (void)invokeAsyncBoolBlock:(BOOL(^)())block
                     success:(void(^)(BOOL val))success
                     failure:(void(^)(NSError *error))failure
{
    NSAssert(self.storeClientDelegate, @"ENNoteStoreClient delegate not set");
    dispatch_async([self.storeClientDelegate dispatchQueueForStoreClient:self], ^(void) {
        __block BOOL retVal = NO;
        @try {
            if (block) {
                retVal = block();
                dispatch_async(dispatch_get_main_queue(),
                               ^{
                                   if (success) {
                                       success(retVal);
                                   }
                               });
            }
        }
        @catch (NSException *exception) {
            NSLog(@"exception %@", exception);
//            NSError *error = [self errorFromNSException:exception];
//            [self processError:failure withError:error];
        }
    });
}

- (void)invokeAsyncInt32Block:(int32_t(^)())block
                      success:(void(^)(int32_t val))success
                      failure:(void(^)(NSError *error))failure
{
    NSAssert(self.storeClientDelegate, @"ENNoteStoreClient delegate not set");
    dispatch_async([self.storeClientDelegate dispatchQueueForStoreClient:self], ^(void) {
        __block int32_t retVal = -1;
        @try {
            if (block) {
                retVal = block();
                dispatch_async(dispatch_get_main_queue(),
                               ^{
                                   if (success) {
                                       success(retVal);
                                   }
                               });
            }
        }
        @catch (NSException *exception) {
            NSLog(@"exception %@", exception);
            //            NSError *error = [self errorFromNSException:exception];
            //            [self processError:failure withError:error];
        }
    });
}

// use id instead of NSObject* so block type-checking is happy
- (void)invokeAsyncIdBlock:(id(^)())block
                   success:(void(^)(id))success
                   failure:(void(^)(NSError *error))failure
{
    NSAssert(self.storeClientDelegate, @"ENNoteStoreClient delegate not set");
    dispatch_async([self.storeClientDelegate dispatchQueueForStoreClient:self], ^(void) {
        id retVal = nil;
        @try {
            if (block) {
                retVal = block();
                dispatch_async(dispatch_get_main_queue(),
                               ^{
                                   if (success) {
                                       success(retVal);
                                   }
                               });
            }
        }
        @catch (NSException *exception) {
            NSLog(@"exception %@", exception);
            //            NSError *error = [self errorFromNSException:exception];
            //            [self processError:failure withError:error];
        }
    });
}

- (void)invokeAsyncVoidBlock:(void(^)())block
                     success:(void(^)())success
                     failure:(void(^)(NSError *error))failure
{
    NSAssert(self.storeClientDelegate, @"ENNoteStoreClient delegate not set");
    dispatch_async([self.storeClientDelegate dispatchQueueForStoreClient:self], ^(void) {
        @try {
            if (block) {
                block();
                dispatch_async(dispatch_get_main_queue(),
                               ^{
                                   if (success) {
                                       success();
                                   }
                               });
            }
        }
        @catch (NSException *exception) {
            NSLog(@"exception %@", exception);
            //            NSError *error = [self errorFromNSException:exception];
            //            [self processError:failure withError:error];
        }
    });
}
@end
