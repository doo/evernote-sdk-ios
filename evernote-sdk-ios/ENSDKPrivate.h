//
//  ENSDKPrivate.h
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 2/25/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#ifndef evernote_sdk_ios_ENSDKPrivate_h
#define evernote_sdk_ios_ENSDKPrivate_h

#import "ENSDK.h"
#import "EvernoteSDK.h"
#import "ENLinkedNotebookRef.h"
#import "ENNoteRefInternal.h"

@interface ENNotebook (Private)
@property (nonatomic, readonly) NSString * guid;
@property (nonatomic, strong) EDAMLinkedNotebook * linkedNotebook;
@property (nonatomic, assign) BOOL isApplicationDefaultNotebook;
- (id)initWithNotebook:(EDAMNotebook *)notebook;
- (id)initWithLinkedNotebook:(EDAMLinkedNotebook *)linkedNotebook sharedNotebook:(EDAMSharedNotebook *)sharedNotebook businessNotebook:(EDAMNotebook *)businessNotebook;
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
@end

// Logging utility macros.
#define ENSDKLogInfo(...) \
    do { \
        [[ENSession sharedSession].logger logInfoString:[NSString stringWithFormat:__VA_ARGS__]]; \
    } while(0);
#define ENSDKLogError(...) \
    do { \
        [[ENSession sharedSession].logger logErrorString:[NSString stringWithFormat:__VA_ARGS__]]; \
    } while(0);

#endif // evernote_sdk_ios_ENSDKPrivate_h
