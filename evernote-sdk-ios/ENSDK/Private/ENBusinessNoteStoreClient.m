//
//  ENBusinessNoteStoreClient.m
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 4/7/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import "ENBusinessNoteStoreClient.h"
#import "ENSDKPrivate.h"

@implementation ENBusinessNoteStoreClient
+ (instancetype)noteStoreClientForBusiness
{
    return [[ENBusinessNoteStoreClient alloc] init];
}

- (NSString *)noteStoreUrl
{
    NSAssert(self.delegate, @"ENBusinessNoteStoreClient delegate not set");
    return [self.delegate noteStoreUrlForBusinessStoreClient:self];
}

- (NSString *)authenticationToken
{
    NSAssert(self.delegate, @"ENBusinessNoteStoreClient delegate not set");
    return [self.delegate authenticationTokenForBusinessStoreClient:self];
}
@end
