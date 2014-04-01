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
- (ENNoteStoreClient *)primaryNoteStore;
- (ENNoteStoreClient *)businessNoteStore;
- (ENNoteStoreClient *)noteStoreForLinkedNotebook:(EDAMLinkedNotebook *)linkedNotebook;
@end
