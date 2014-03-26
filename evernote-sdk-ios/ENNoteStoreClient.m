//
//  ENNoteStoreClient.m
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 3/11/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import "ENNoteStoreClient.h"
#import "EvernoteSDK.h"
#import "Thrift.h"
#import "ENAuthCache.h"

@interface ENNoteStoreClient ()
@property (nonatomic, strong) EDAMNoteStoreClient * client;
@property (nonatomic, copy) NSString * cachedAuthenticationToken;
@end

@implementation ENNoteStoreClient
+ (instancetype)noteStoreClientWithUrl:(NSString *)url authenticationToken:(NSString *)authenticationToken
{
    ENNoteStoreClient * client = [[self alloc] initWithNoteStoreUrl:url];
    client.cachedAuthenticationToken = authenticationToken;
    return client;
}

- (id)initWithNoteStoreUrl:(NSString *)noteStoreUrl
{
    self = [super init];
    if (self) {
        [self createClientForUrl:noteStoreUrl];
    }
    return self;
}

- (void)createClientForUrl:(NSString *)noteStoreUrl
{
    NSURL * url = [NSURL URLWithString:noteStoreUrl];
    THTTPClient * transport = [[THTTPClient alloc] initWithURL:url];
    TBinaryProtocol * protocol = [[TBinaryProtocol alloc] initWithTransport:transport];
    self.client = [[EDAMNoteStoreClient alloc] initWithProtocol:protocol];
}

// Override point for subclasses that handle auth differently. This simple version just
// returns the cached token.
- (NSString *)authenticationToken
{
    return self.cachedAuthenticationToken;
}

#pragma mark - EDAM API

- (EDAMAuthenticationResult *)authenticateToSharedNotebookWithShareKey:(NSString *)shareKey
{
    return [self.client authenticateToSharedNotebook:shareKey authenticationToken:self.authenticationToken];
}


- (void)listNotebooksWithSuccess:(void(^)(NSArray *notebooks))success
                         failure:(void(^)(NSError *error))failure
{
    [self invokeAsyncIdBlock:^id {
        return [self.client listNotebooks:[self authenticationToken]];
    } success:success failure:failure];
}

- (void)getNotebookWithGuid:(EDAMGuid)guid
                    success:(void(^)(EDAMNotebook *notebook))success
                    failure:(void(^)(NSError *error))failure
{
    [self invokeAsyncIdBlock:^id {
        return [self.client getNotebook:[self authenticationToken] guid:guid];
    } success:success failure:failure];
}

- (void)createNotebook:(EDAMNotebook *)notebook
               success:(void(^)(EDAMNotebook *notebook))success
               failure:(void(^)(NSError *error))failure
{
    [self invokeAsyncIdBlock:^id {
        return [self.client createNotebook:[self authenticationToken] notebook:notebook];
    } success:success failure:failure];
}

- (void)listLinkedNotebooksWithSuccess:(void(^)(NSArray *linkedNotebooks))success
                               failure:(void(^)(NSError *error))failure
{
    [self invokeAsyncIdBlock:^id {
        return [self.client listLinkedNotebooks:[self authenticationToken]];
    } success:success failure:failure];
}

- (void)getSharedNotebookByAuthWithSuccess:(void(^)(EDAMSharedNotebook *sharedNotebook))success
                                   failure:(void(^)(NSError *error))failure

{
    [self invokeAsyncIdBlock:^id {
        return [self.client getSharedNotebookByAuth:[self authenticationToken]];
    } success:success failure:failure];
}

- (void)shareNoteWithGuid:(EDAMGuid)guid
                  success:(void(^)(NSString *noteKey))success
                  failure:(void(^)(NSError *error))failure
{
    [self invokeAsyncIdBlock:^id {
        return [self.client shareNote:[self authenticationToken] guid:guid];
    } success:success failure:failure];
}

- (void)createNote:(EDAMNote *)note
           success:(void(^)(EDAMNote *note))success
           failure:(void(^)(NSError *error))failure
{
    [self invokeAsyncIdBlock:^id {
        return [self.client createNote:[self authenticationToken] note:note];
    } success:success failure:failure];
}

- (void)updateNote:(EDAMNote *)note
           success:(void(^)(EDAMNote *note))success
           failure:(void(^)(NSError *error))failure
{
    [self invokeAsyncIdBlock:^id {
        return [self.client updateNote:[self authenticationToken] note:note];
    } success:success failure:failure];
}

- (void)deleteNoteWithGuid:(EDAMGuid)guid
                   success:(void(^)(int32_t usn))success
                   failure:(void(^)(NSError *error))failure
{
    [self invokeAsyncInt32Block:^int32_t {
        return [self.client deleteNote:[self authenticationToken] guid:guid];
    } success:success failure:failure];
}

- (void)listSharedNotebooksWithSuccess:(void(^)(NSArray *sharedNotebooks))success
                               failure:(void(^)(NSError *error))failure
{
    [self invokeAsyncIdBlock:^id {
        return [self.client listSharedNotebooks:[self authenticationToken]];
    } success:success failure:failure];
}
@end
