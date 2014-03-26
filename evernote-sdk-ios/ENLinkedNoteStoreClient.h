//
//  ENLinkedNoteStoreClient.h
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 3/26/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import "ENNoteStoreClient.h"

@protocol ENLinkedNoteStoreClientDelegate <NSObject>
- (NSString *)authenticationTokenForLinkedNotebookRef:(ENLinkedNotebookRef *)linkedNotebookRef;
@end

@interface ENLinkedNoteStoreClient : ENNoteStoreClient
@property (nonatomic, weak) id<ENLinkedNoteStoreClientDelegate> delegate;
+ (instancetype)noteStoreClientForLinkedNotebookRef:(ENLinkedNotebookRef *)linkedNotebookRef;
@end
