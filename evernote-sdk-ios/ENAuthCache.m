//
//  ENAuthCache.m
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 3/10/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import "ENAuthCache.h"
#import "NSDate+EDAMAdditions.h"

@interface ENAuthCache ()
@property (nonatomic, strong) NSMutableDictionary * cache;
@end

@implementation ENAuthCache
- (id)init
{
    self = [super init];
    if (self) {
        self.cache = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)setAuthenticationResult:(EDAMAuthenticationResult *)result forLinkedNotebookGuid:(NSString *)guid
{
    @synchronized (self) {
        self.cache[guid] = result;
    }
}

- (EDAMAuthenticationResult *)authenticationResultForLinkedNotebookGuid:(NSString *)guid
{
    EDAMAuthenticationResult * result = nil;
    @synchronized (self) {
        result = self.cache[guid];
        if (result && [[NSDate endateFromEDAMTimestamp:result.expiration] compare:[NSDate date]] != NSOrderedAscending) {
            // This auth result has already expired, so evict it.
            [self.cache removeObjectForKey:guid];
            result = nil;
        }
    }
    return result;
}
@end
