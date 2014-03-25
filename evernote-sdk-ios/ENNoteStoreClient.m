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
@property (nonatomic, strong) NSString * authenticationToken;

// This is a "temporary" property stashed for non-personal note stores
// which are used to later ask the delegate for corresponding auth token. In a more ideal
// abstraction, this object wouldn't know anything about linked notebooks, it would
// house solely the client and auth token. But we want this object to be lightweight and created on the
// main thread easily, and requiring full auth in these cases would complicate things significantly.
@property (nonatomic, strong) ENLinkedNotebookRef * linkedNotebookRef;
@end

@implementation ENNoteStoreClient
+ (ENNoteStoreClient *)noteStoreClientWithUrl:(NSString *)url authenticationToken:(NSString *)authenticationToken
{
    return [[self alloc] initWithNoteStoreUrl:url authenticationToken:authenticationToken];
}

+ (ENNoteStoreClient *)noteStoreClientForLinkedNotebookRef:(ENLinkedNotebookRef *)linkedNotebookRef;
{
    return [[self alloc] initWithLinkedNotebookRef:linkedNotebookRef];
}

- (id)initWithNoteStoreUrl:(NSString *)noteStoreUrl authenticationToken:(NSString *)authenticationToken
{
    self = [super init];
    if (self) {
        [self createClientForUrl:noteStoreUrl];
        self.authenticationToken = authenticationToken;
    }
    return self;
}

- (id)initWithLinkedNotebookRef:(ENLinkedNotebookRef *)linkedNotebookRef
{
    self = [super init];
    if (self) {
        [self createClientForUrl:linkedNotebookRef.noteStoreUrl];
        self.linkedNotebookRef = linkedNotebookRef;
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

- (EDAMAuthenticationResult *)authenticateToSharedNotebookWithShareKey:(NSString *)shareKey
{
    return [self.client authenticateToSharedNotebook:shareKey authenticationToken:self.authenticationToken];
}

- (NSString *)authenticationToken
{
    if (_authenticationToken) {
        return _authenticationToken;
    }
    
    if (self.linkedNotebookRef) {
        NSAssert(self.noteStoreDelegate, @"ENNoteStoreClient delegate not set");
        _authenticationToken = [self.noteStoreDelegate authenticationTokenForLinkedNotebookRef:self.linkedNotebookRef];
        self.linkedNotebookRef = nil;
    }
    
    return _authenticationToken;
}

#pragma mark - EDAM API

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
