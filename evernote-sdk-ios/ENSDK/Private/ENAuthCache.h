//
//  ENAuthCache.h
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 3/10/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ENSDKAdvanced.h"

@interface ENAuthCache : NSObject
- (void)setAuthenticationResult:(EDAMAuthenticationResult *)result forLinkedNotebookGuid:(NSString *)guid;
- (EDAMAuthenticationResult *)authenticationResultForLinkedNotebookGuid:(NSString *)guid;
- (void)setAuthenticationResultForBusiness:(EDAMAuthenticationResult *)result;
- (EDAMAuthenticationResult *)authenticationResultForBusiness;
@end
