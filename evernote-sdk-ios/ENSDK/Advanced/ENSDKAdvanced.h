//
//  ENSDKAdvanced.h
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 3/31/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import "ENSDK.h"
#import "EDAM/EDAM.h"
#import "ENNoteStoreClient.h"
#import "ENUserStoreClient.h"
@class ENNoteStoreClient;

@interface ENSession (Advanced)
// Indicates if your app is capable of supporting linked/business notebooks as app notebook destinations.
// Defaults to YES, as the non-advanced interface on ENSession will handle these transparently. If you're
// using the note store clients directly, either set this to NO, or be sure you test using a shared notebook as
// an app notebook.
@property (nonatomic, assign) BOOL supportsLinkedAppNotebook;

// Retrive an appropriate note store client to perform API operations with.
- (ENNoteStoreClient *)primaryNoteStore;
- (ENNoteStoreClient *)businessNoteStore;
- (ENNoteStoreClient *)noteStoreForLinkedNotebook:(EDAMLinkedNotebook *)linkedNotebook;
@end

@interface ENNoteContent (Advanced)
+ (instancetype)noteContentWithENML:(NSString *)enml;
- (id)initWithENML:(NSString *)enml;
@end
