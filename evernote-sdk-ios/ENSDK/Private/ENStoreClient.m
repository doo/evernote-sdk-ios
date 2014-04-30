//
//  ENStoreClient.m
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 3/11/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import "ENStoreClient.h"
#import "ENError.h"
#import "EDAMErrors.h"
#import "ENSDKPrivate.h"

@interface ENStoreClient ()
@property (nonatomic, strong) dispatch_queue_t queue;
@end

@implementation ENStoreClient

- (id)init
{
    self = [super init];
    if (self) {
        NSString * queueName = [NSString stringWithFormat:@"com.evernote.sdk.%@", NSStringFromClass([self class])];
        self.queue = dispatch_queue_create([queueName cStringUsingEncoding:NSASCIIStringEncoding], NULL);
    }
    return self;
}

- (void)invokeAsyncBoolBlock:(BOOL(^)())block
                     success:(void(^)(BOOL val))success
                     failure:(void(^)(NSError *error))failure
{
    dispatch_async(self.queue, ^(void) {
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
            [self handleException:exception withFailureBlock:failure];
        }
    });
}

- (void)invokeAsyncInt32Block:(int32_t(^)())block
                      success:(void(^)(int32_t val))success
                      failure:(void(^)(NSError *error))failure
{
    dispatch_async(self.queue, ^(void) {
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
            [self handleException:exception withFailureBlock:failure];
        }
    });
}

// use id instead of NSObject* so block type-checking is happy
- (void)invokeAsyncIdBlock:(id(^)())block
                   success:(void(^)(id))success
                   failure:(void(^)(NSError *error))failure
{
    dispatch_async(self.queue, ^(void) {
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
            [self handleException:exception withFailureBlock:failure];
        }
    });
}

- (void)invokeAsyncVoidBlock:(void(^)())block
                     success:(void(^)())success
                     failure:(void(^)(NSError *error))failure
{
    dispatch_async(self.queue, ^(void) {
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
            [self handleException:exception withFailureBlock:failure];
        }
    });
}

#pragma mark - Private routines

+ (ENErrorCode)sanitizedErrorCodeFromEDAMErrorCode:(int)code
{
    switch (code) {
        case EDAMErrorCode_BAD_DATA_FORMAT:
        case EDAMErrorCode_DATA_REQUIRED:
        case EDAMErrorCode_LEN_TOO_LONG:
        case EDAMErrorCode_LEN_TOO_SHORT:
        case EDAMErrorCode_TOO_FEW:
        case EDAMErrorCode_TOO_MANY:
            return ENErrorCodeInvalidData;
            
        case EDAMErrorCode_AUTH_EXPIRED:
            return ENErrorCodeAuthExpired;
            
        case EDAMErrorCode_DATA_CONFLICT:
            return ENErrorCodeDataConflict;
            
        case EDAMErrorCode_ENML_VALIDATION:
            return ENErrorCodeENMLInvalid;
            
        case EDAMErrorCode_INVALID_AUTH:
        case EDAMErrorCode_PERMISSION_DENIED:
            return ENErrorCodePermissionDenied;
            
        case EDAMErrorCode_LIMIT_REACHED:
            return ENErrorCodeLimitReached;
            
        case EDAMErrorCode_QUOTA_REACHED:
            return ENErrorCodeQuotaReached;
            
        case EDAMErrorCode_RATE_LIMIT_REACHED:
            return ENErrorCodeRateLimitReached;
            
        default:
            return ENErrorCodeUnknown;
    }
}

- (NSError *)errorFromException:(NSException *)exception
{
    if (exception) {
        NSInteger sanitizedErrorCode = ENErrorCodeUnknown;
        NSMutableDictionary * userInfo = [NSMutableDictionary dictionaryWithDictionary:exception.userInfo];
        
        if ([exception respondsToSelector:@selector(errorCode)]) {
            // Evernote Thrift exception classes have an errorCode property
            int edamErrorCode = [(id)exception errorCode];
            sanitizedErrorCode = [[self class] sanitizedErrorCodeFromEDAMErrorCode:edamErrorCode];
            userInfo[@"EDAMErrorCode"] = @(edamErrorCode); // Put this in the user info in case the caller cares.
        } else if ([exception isKindOfClass:[TException class]]) {
            // treat any Thrift errors as a transport error
            // we could create separate error codes for the various TException subclasses
            sanitizedErrorCode = ENErrorCodeConnectionFailed;
            if ([exception.description length] > 0) {
                userInfo[NSLocalizedDescriptionKey] = exception.description;
            }
        }
        
        if ([exception isKindOfClass:[EDAMSystemException class]] == YES) {
            EDAMSystemException* systemException = (EDAMSystemException*)exception;
            if ([systemException rateLimitDurationIsSet]) {
                userInfo[@"rateLimitDuration"] = @([systemException rateLimitDuration]);
            }
            if ([systemException messageIsSet]) {
                userInfo[@"message"] = [systemException message];
            }
        } else if ([exception isKindOfClass:[EDAMNotFoundException class]]) {
            EDAMNotFoundException * notFound = (EDAMNotFoundException *)exception;
            userInfo[@"parameter"] = notFound.identifier;
            sanitizedErrorCode = ENErrorCodeNotFound;
        }
        
        if ([exception respondsToSelector:@selector(parameter)]) {
            NSString * parameter = [(id)exception parameter];
            if (parameter) {
                userInfo[@"parameter"] = parameter;
            }
        }
        
        return [NSError errorWithDomain:ENErrorDomain code:sanitizedErrorCode userInfo:userInfo];
    }
    return nil;
}

- (void)handleException:(NSException *)exception withFailureBlock:(void(^)(NSError *error))failure
{
    if (failure) {
        NSError * error = [self errorFromException:exception];
        dispatch_async(dispatch_get_main_queue(), ^{
            failure(error);
        });
    }
}
@end
