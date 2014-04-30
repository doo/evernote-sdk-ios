//
//  ENError.h
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 3/13/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * ENErrorDomain;

typedef NS_ENUM(NSInteger, ENErrorCode) {
    ENErrorCodeUnknown,
    ENErrorCodeConnectionFailed,
    ENErrorCodeAuthExpired,
    ENErrorCodeInvalidData,
    ENErrorCodeNotFound,
    ENErrorCodePermissionDenied,
    ENErrorCodeLimitReached,
    ENErrorCodeQuotaReached,
    ENErrorCodeDataConflict,
    ENErrorCodeENMLInvalid,
    ENErrorCodeRateLimitReached,
    ENErrorCodeCancelled
};
