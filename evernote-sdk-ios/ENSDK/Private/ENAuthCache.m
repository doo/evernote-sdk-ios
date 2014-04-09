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
+ (ENAuthCacheEntry *)entryWithResult:(EDAMAuthenticationResult *)result;
- (BOOL)isValid;
@end

@interface ENAuthCache ()
@property (nonatomic, strong) NSMutableDictionary * linkedCache;
@property (nonatomic, strong) ENAuthCacheEntry * businessCache;
@end

@implementation ENAuthCache
- (id)init
{
    self = [super init];
    if (self) {
        self.linkedCache = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)setAuthenticationResult:(EDAMAuthenticationResult *)result forLinkedNotebookGuid:(NSString *)guid
{
    if (!result) {
        return;
    }
    
    ENAuthCacheEntry * entry = [ENAuthCacheEntry entryWithResult:result];
    @synchronized(self) {
        self.linkedCache[guid] = entry;
    }
}

- (EDAMAuthenticationResult *)authenticationResultForLinkedNotebookGuid:(NSString *)guid
{
    EDAMAuthenticationResult * result = nil;
    @synchronized(self) {
        ENAuthCacheEntry * entry = self.linkedCache[guid];
        if (entry && ![entry isValid]) {
            // This auth result has already expired, so evict it.
            [self.linkedCache removeObjectForKey:guid];
            entry = nil;
        }
        result = entry.authResult;
    }
    return result;
}

- (void)setAuthenticationResultForBusiness:(EDAMAuthenticationResult *)result
{
    if (!result) {
        return;
    }
    ENAuthCacheEntry * entry = [ENAuthCacheEntry entryWithResult:result];
    @synchronized(self) {
        self.businessCache = entry;
    }
}

- (EDAMAuthenticationResult *)authenticationResultForBusiness
{
    EDAMAuthenticationResult * result = nil;
    @synchronized(self) {
        ENAuthCacheEntry * entry = self.businessCache;
        if (entry && ![entry isValid]) {
            // This auth result has already expired, so evict it.
            self.businessCache = nil;
        }
        result = entry.authResult;
    }
    return result;
}
@end

@implementation ENAuthCacheEntry
+ (ENAuthCacheEntry *)entryWithResult:(EDAMAuthenticationResult *)result
{
    if (!result) {
        return nil;
    }
    ENAuthCacheEntry * entry = [[ENAuthCacheEntry alloc] init];
    entry.authResult = result;
    entry.cachedDate = [NSDate date];
    return entry;
}

- (BOOL)isValid
{
    NSTimeInterval age = fabs([self.cachedDate timeIntervalSinceNow]);
    EDAMTimestamp expirationAge = (self.authResult.expiration - self.authResult.currentTime) / 1000;
    // we're okay if the token is within 90% of the expiration time
    if (age > (.9 * expirationAge)) {
        return NO;
    }
    return YES;
}
@end
