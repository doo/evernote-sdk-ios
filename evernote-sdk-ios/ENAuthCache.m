//
//  ENAuthCache.m
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 3/10/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import "ENAuthCache.h"
#import "NSDate+EDAMAdditions.h"

@interface ENAuthCacheEntry : NSObject
@property (nonatomic, strong) EDAMAuthenticationResult * authResult;
@property (nonatomic, strong) NSDate * cachedDate;
@end

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
    ENAuthCacheEntry * entry = [[ENAuthCacheEntry alloc] init];
    entry.authResult = result;
    entry.cachedDate = [NSDate date];
    
    @synchronized (self) {
        self.cache[guid] = entry;
    }
}

- (EDAMAuthenticationResult *)authenticationResultForLinkedNotebookGuid:(NSString *)guid
{
    EDAMAuthenticationResult * result = nil;
    @synchronized (self) {
        ENAuthCacheEntry * entry = self.cache[guid];
        if (entry) {
            // Check for expiration.
            NSTimeInterval age = fabs([entry.cachedDate timeIntervalSinceNow]);
            EDAMTimestamp expirationAge = (entry.authResult.expiration - entry.authResult.currentTime) / 1000;
            // we're okay if the token is within 90% of the expiration time
            if (age > (.9 * expirationAge)) {
                // This auth result has already expired, so evict it.
                [self.cache removeObjectForKey:guid];
                entry = nil;
            }
        }
        result = entry.authResult;
    }
    return result;
}
@end

@implementation ENAuthCacheEntry
@end
