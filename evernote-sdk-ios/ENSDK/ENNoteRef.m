//
//  ENNoteRef.m
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 3/7/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import "ENNoteRef.h"
#import "ENLinkedNotebookRef.h"
#import "ENNoteRefInternal.h"

@implementation ENNoteRef
+ (instancetype)noteRefFromData:(NSData *)data
{
    if (!data) {
        return nil;
    }
    id root = nil;
    @try {
        root = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    }
    @catch(id e) {
    }
    if (root && [root isKindOfClass:[self class]]) {
        return root;
    }
    return nil;
}

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super init];
    if (self) {
        self.type = (NSInteger)[decoder decodeInt32ForKey:@"type"];
        self.guid = [decoder decodeObjectForKey:@"guid"];
        self.linkedNotebook = [decoder decodeObjectForKey:@"linkedNotebook"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeInt32:self.type forKey:@"type"];
    [encoder encodeObject:self.guid forKey:@"guid"];
    [encoder encodeObject:self.linkedNotebook forKey:@"linkedNotebook"];
}

- (NSData *)asData
{
    return [NSKeyedArchiver archivedDataWithRootObject:self];
}
@end
