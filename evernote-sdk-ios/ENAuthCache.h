//
//  ENAuthCache.h
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 3/10/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EvernoteSDK.h"

@interface ENAuthCache : NSObject
+ (ENAuthCache *)sharedCache;
- (void)setAuthenticationResult:(EDAMAuthenticationResult *)result forLinkedNotebookGuid:(NSString *)guid;
- (EDAMAuthenticationResult *)authenticationResultForLinkedNotebookGuid:(NSString *)guid;
@end
