//
//  ENNotebook.m
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 2/25/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import "ENSDKPrivate.h"

@interface ENNotebook ()
@property (nonatomic, strong) EDAMNotebook * notebook;
@property (nonatomic, strong) EDAMLinkedNotebook * linkedNotebook;
@property (nonatomic, strong) EDAMSharedNotebook * sharedNotebook;
@property (nonatomic, assign) BOOL isDefaultNotebookOverride;
@end

@implementation ENNotebook
- (id)initWithNotebook:(EDAMNotebook *)notebook 
{
    return [self initWithNotebook:notebook linkedNotebook:nil sharedNotebook:nil];
}

- (id)initWithSharedNotebook:(EDAMSharedNotebook *)sharedNotebook forLinkedNotebook:(EDAMLinkedNotebook *)linkedNotebook
{
    return [self initWithNotebook:nil linkedNotebook:linkedNotebook sharedNotebook:sharedNotebook];
}

- (id)initWithSharedNotebook:(EDAMSharedNotebook *)sharedNotebook forLinkedNotebook:(EDAMLinkedNotebook *)linkedNotebook withBusinessNotebook:(EDAMNotebook *)notebook
{
    return [self initWithNotebook:notebook linkedNotebook:linkedNotebook sharedNotebook:sharedNotebook];
}

// Designated initializer used by all protected initializers
- (id)initWithNotebook:(EDAMNotebook *)notebook linkedNotebook:(EDAMLinkedNotebook *)linkedNotebook sharedNotebook:(EDAMSharedNotebook *)sharedNotebook
{
    self = [super init];
    if (self) {
        self.notebook = notebook;
        self.linkedNotebook = linkedNotebook;
        self.sharedNotebook = sharedNotebook;
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super init];
    if (self) {
        self.notebook = [decoder decodeObjectForKey:@"notebook"];
        self.linkedNotebook = [decoder decodeObjectForKey:@"linkedNotebook"];
        self.sharedNotebook = [decoder decodeObjectForKey:@"sharedNotebook"];
        self.isDefaultNotebookOverride = [decoder decodeBoolForKey:@"isDefaultNotebookOverride"];
        if (!self.notebook && !self.linkedNotebook && !self.sharedNotebook) {
            return nil;
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:self.notebook forKey:@"notebook"];
    [encoder encodeObject:self.linkedNotebook forKey:@"linkedNotebook"];
    [encoder encodeObject:self.sharedNotebook forKey:@"sharedNotebook"];
    [encoder encodeBool:self.isDefaultNotebookOverride forKey:@"isDefaultNotebookOverride"];
}

- (NSString *)name
{
    if (self.notebook) {
        return self.notebook.name;
    } else {
        return self.linkedNotebook.shareName;
    }
}

- (NSString *)guid
{
    // Personal notebooks have a native guid, and if we've stashed a business-native notebook here, then we can look at that
    // as well.
    if (self.notebook) {
        return self.notebook.guid;
    }
    // Shared notebook objects will also have a notebook GUID on them pointing to their native notebook.
    if (self.sharedNotebook) {
        return self.sharedNotebook.notebookGuid;
    }
    
    return nil;
}

- (BOOL)isLinked
{
    return self.linkedNotebook != nil;
}

- (BOOL)isBusinessNotebook
{
    // Business notebooks are the only ones that have a combination of a linked notebook and normal
    // notebook being set. In this case, the normal notebook represents the notebook inside the business.
    return self.linkedNotebook != nil && self.notebook != nil;
}

- (BOOL)isDefaultNotebook
{
    if (self.isDefaultNotebookOverride) {
        return YES;
    } else if (self.notebook) {
        return self.notebook.defaultNotebook;
    }
    return NO;
}

- (BOOL)allowsWriting
{
    if (![self isLinked]) {
        // All personal notebooks are readwrite.
        return YES;
    }
    
    int privilege = self.sharedNotebook.privilege;
    if (privilege == SharedNotebookPrivilegeLevel_GROUP) {
        // Need to consult the business notebook object privilege.
        privilege = self.notebook.businessNotebook.privilege;
    }
    
    if (privilege == SharedNotebookPrivilegeLevel_MODIFY_NOTEBOOK_PLUS_ACTIVITY ||
        privilege == SharedNotebookPrivilegeLevel_FULL_ACCESS ||
        privilege == SharedNotebookPrivilegeLevel_BUSINESS_FULL_ACCESS) {
        return YES;
    }
    
    return NO;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; name = \"%@\"; linked = %@; business = %@; access = %@>",
            [self class], self, self.name, self.isLinked ? @"YES" : @"NO", self.isBusinessNotebook ? @"YES" : @"NO", self.allowsWriting ? @"R/W" : @"R/O"];
}

- (BOOL)isEqual:(id)object
{
    if (!object || ![object isKindOfClass:[self class]]) {
        return NO;
    }
    return [self.guid isEqualToString:((ENNotebook *)object).guid];
}

- (NSUInteger)hash
{
    return [self.guid hash];
}
@end
