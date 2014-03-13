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
    linkedNotebookRef.shardId = linkedNotebook.shardId;
    linkedNotebookRef.shareKey = linkedNotebook.shareKey;
    return linkedNotebookRef;
}

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super init];
    if (self) {
        self.guid = [decoder decodeObjectForKey:@"guid"];
        self.noteStoreUrl = [decoder decodeObjectForKey:@"noteStoreUrl"];
        self.shardId = [decoder decodeObjectForKey:@"shardId"];
        self.shareKey = [decoder decodeObjectForKey:@"shareKey"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:self.guid forKey:@"guid"];
    [encoder encodeObject:self.noteStoreUrl forKey:@"noteStoreUrl"];
    [encoder encodeObject:self.shardId forKey:@"shardId"];
    [encoder encodeObject:self.shareKey forKey:@"shareKey"];
}
@end
