//
//  ENSDKPrivate.h
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 2/25/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import "ENSDK.h"
#import "ENSDKAdvanced.h"
#import "ENLinkedNotebookRef.h"
#import "ENNoteRefInternal.h"
#import "ENNoteStoreClient.h"
#import "ENUserStoreClient.h"

@interface ENNotebook (Private)
@property (nonatomic, readonly) NSString * guid;
@property (nonatomic, strong) EDAMLinkedNotebook * linkedNotebook;
@property (nonatomic, assign) BOOL isApplicationDefaultNotebook;
// For a personal notebook
- (id)initWithNotebook:(EDAMNotebook *)notebook;
// For a non-business shared notebook
- (id)initWithSharedNotebook:(EDAMSharedNotebook *)sharedNotebook forLinkedNotebook:(EDAMLinkedNotebook *)linkedNotebook;
// For a business shared notebook
- (id)initWithSharedNotebook:(EDAMSharedNotebook *)sharedNotebook forLinkedNotebook:(EDAMLinkedNotebook *)linkedNotebook withBusinessNotebook:(EDAMNotebook *)notebook;
@end

@interface ENResource (Private)
- (EDAMResource *)EDAMResource;
@end

@interface ENNote (Private)
- (NSString *)content;
- (void)setGuid:(NSString *)guid;
- (void)setEnmlContent:(NSString *)enmlContent;
- (void)setResources:(NSArray *)resources;
- (EDAMNote *)EDAMNote;
- (BOOL)validateForLimits;
@end

@interface ENNoteStoreClient (Private)
// This accessor is here to provide a declaration of the override point for subclasses that do
// nontrivial token management.
@property (nonatomic, readonly) NSString * authenticationToken;
@property (nonatomic, readonly) NSString * noteStoreUrl;

// This is how you get one of these note store objects.
+ (instancetype)noteStoreClientWithUrl:(NSString *)url authenticationToken:(NSString *)authenticationToken;

// N.B. This method is synchronous and can throw exceptions.
// Should be called only from within protected code blocks
- (EDAMAuthenticationResult *)authenticateToSharedNotebookWithShareKey:(NSString *)shareKey;
@end

@interface ENUserStoreClient (Private)
+ (instancetype)userStoreClientWithUrl:(NSString *)url authenticationToken:(NSString *)authenticationToken;

// N.B. This method is synchronous and can throw exceptions.
// Should be called only from within protected code blocks
- (EDAMAuthenticationResult *)authenticateToBusiness;
@end

// Logging utility macros.
#define ENSDKLogInfo(...) \
    do { \
        [[ENSession sharedSession].logger evernoteLogInfoString:[NSString stringWithFormat:__VA_ARGS__]]; \
    } while(0);
#define ENSDKLogError(...) \
    do { \
        [[ENSession sharedSession].logger evernoteLogErrorString:[NSString stringWithFormat:__VA_ARGS__]]; \
    } while(0);
