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

// Once authenticated, this flag will indicate whether the app notebook chosen by the user is, in fact, linked.
// (This will never be YES if you have set the flag above to NO). If so, you must take this into account:
// the primary note store will not allow you to access the notebook; instead, you must authenticate to the
// relevant linked notebook. You can find the linked notebook record by calling -listLinkedNotebooks on the
// primary note store.
@property (nonatomic, readonly) BOOL appNotebookIsLinked;

// Retrive an appropriate note store client to perform API operations with:
// - The primary note store client is valid for all personal notebooks, and can also be used to authenticate with
//   shared notebooks.
// - The business note store client will only be non-nil if the authenticated user is a member of a business. With
//   it, you can access the business's notebooks.
// - Every linked notebook requires its own note store client instance to access.
- (ENNoteStoreClient *)primaryNoteStore;
- (ENNoteStoreClient *)businessNoteStore;
- (ENNoteStoreClient *)noteStoreForLinkedNotebook:(EDAMLinkedNotebook *)linkedNotebook;
@end

@interface ENNoteContent (Advanced)
+ (instancetype)noteContentWithENML:(NSString *)enml;
- (id)initWithENML:(NSString *)enml;
@end
