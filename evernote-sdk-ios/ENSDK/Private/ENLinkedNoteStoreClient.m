//
//  ENLinkedNoteStoreClient.m
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 3/26/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import "ENLinkedNoteStoreClient.h"
#import "ENSDKPrivate.h"

@interface ENLinkedNoteStoreClient ()
@property (nonatomic, strong) ENLinkedNotebookRef * linkedNotebookRef;
@end

@implementation ENLinkedNoteStoreClient
+ (instancetype)noteStoreClientForLinkedNotebookRef:(ENLinkedNotebookRef *)linkedNotebookRef
{
    ENLinkedNoteStoreClient * client = [[ENLinkedNoteStoreClient alloc] init];;
    client.linkedNotebookRef = linkedNotebookRef;
    return client;
}

- (NSString *)authenticationToken
{
    NSAssert(self.delegate, @"ENLinkedNoteStoreClient delegate not set");
    return [self.delegate authenticationTokenForLinkedNotebookRef:self.linkedNotebookRef];
}

- (NSString *)noteStoreUrl
{
    return self.linkedNotebookRef.noteStoreUrl;
}
@end
