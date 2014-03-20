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
@property (nonatomic, assign) BOOL isApplicationDefaultNotebook;
@end

@implementation ENNotebook
- (id)initWithNotebook:(EDAMNotebook *)notebook 
{
    self = [super init];
    if (self) {
        self.notebook = notebook;
    }
    return self;
}

- (id)initWithLinkedNotebook:(EDAMLinkedNotebook *)linkedNotebook sharedNotebook:(EDAMSharedNotebook *)sharedNotebook businessNotebook:(EDAMNotebook *)businessNotebook
{
    self = [super init];
    if (self) {
        self.notebook = businessNotebook;
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
        self.isApplicationDefaultNotebook = [decoder decodeBoolForKey:@"isApplicationDefaultNotebook"];
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
    [encoder encodeBool:self.isApplicationDefaultNotebook forKey:@"isApplicationDefaultNotebook"];
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
    // This is a little fragile. Currently works because we never instantiate one of these objects
    // when linked with the "native" notebook, unless we know it's in the user's business.
    return self.linkedNotebook != nil && self.notebook != nil;
}

- (BOOL)isDefaultNotebook
{
    if (self.notebook) {
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
