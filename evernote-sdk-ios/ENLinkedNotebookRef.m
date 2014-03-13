//
//  ENLinkedNotebookRef.m
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 3/13/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import "ENLinkedNotebookRef.h"

@implementation ENLinkedNotebookRef
+ (ENLinkedNotebookRef *)linkedNotebookRefFromLinkedNotebook:(EDAMLinkedNotebook *)linkedNotebook
{
    ENLinkedNotebookRef * linkedNotebookRef = [[ENLinkedNotebookRef alloc] init];
    linkedNotebookRef.guid = linkedNotebook.guid;
    linkedNotebookRef.noteStoreUrl = linkedNotebook.noteStoreUrl;
    linkedNotebookRef.shareKey = linkedNotebook.shareKey;
    return linkedNotebookRef;
}
@end
