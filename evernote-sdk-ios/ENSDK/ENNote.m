//
//  ENNote.m
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 2/25/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import "ENSDKPrivate.h"
#import "NSString+ENScrubbing.h"

#pragma mark - ENNote

@interface ENNote ()
{
    NSMutableArray * _resources;
}
@property (nonatomic, copy) NSString * cachedENMLContent;
@end

@implementation ENNote
- (id)init
{
    self = [super init];
    if (self) {
        _resources = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)setTitle:(NSString *)title
{
    _title = [title en_scrubUsingRegex:[EDAMLimitsConstants EDAM_NOTE_TITLE_REGEX]
                         withMinLength:[EDAMLimitsConstants EDAM_NOTE_TITLE_LEN_MIN]
                             maxLength:[EDAMLimitsConstants EDAM_NOTE_TITLE_LEN_MAX]];
}

- (void)setContent:(ENNoteContent *)content
{
    [self invalidateCachedENML];
    _content = content;
}

- (void)setTagNames:(NSArray *)tagNames
{
    NSMutableArray * tags = [NSMutableArray array];
    for (NSString * tagName in tagNames) {
        NSString * scrubbedTag = [tagName en_scrubUsingRegex:[EDAMLimitsConstants EDAM_TAG_NAME_REGEX]
                                               withMinLength:[EDAMLimitsConstants EDAM_TAG_NAME_LEN_MIN]
                                                   maxLength:[EDAMLimitsConstants EDAM_TAG_NAME_LEN_MAX]];
        if (scrubbedTag) {
            [tags addObject:scrubbedTag];
        }
    }
    _tagNames = (tags.count > 0) ? tags : nil;
}

- (NSArray *)resources
{
    return _resources;
}

- (void)addResource:(ENResource *)resource
{
    if (resource) {
        if (_resources.count >= (NSUInteger)[EDAMLimitsConstants EDAM_NOTE_RESOURCES_MAX]) {
            ENSDKLogInfo(@"Too many resources already on note. Ignoring %@. Note %@.", resource, self);
        } else {
            [self invalidateCachedENML];
            [_resources addObject:resource];
        }
    }
}

#pragma mark - Protected methods

- (void)invalidateCachedENML
{
    self.cachedENMLContent = nil;
}

- (NSString *)enmlContent
{
    if (!self.cachedENMLContent) {
        self.cachedENMLContent = [self.content enmlWithResources:self.resources];
    }
    return self.cachedENMLContent;
}

- (void)setResources:(NSArray *)resources
{
    _resources = [NSMutableArray arrayWithArray:resources];
}

- (EDAMNote *)EDAMNote
{
    // Turn the ENNote into an EDAMNote.
    EDAMNote * note = [[EDAMNote alloc] init];
    
    note.content = [self enmlContent];
    if (!note.content) {
        ENNoteContent * emptyContent = [ENNoteContent noteContentWithString:@""];
        note.content = [emptyContent enmlWithResources:nil];
    }
    
    note.title = self.title;
    if (!note.title) {
        // Only use a dummy title if we couldn't get a real one inside limits.
        note.title = @"Untitled Note";
    }
    
    note.notebookGuid = self.notebook.guid;
    
    // Setup note attributes. Use app bundle name for source application unless the app wants to override.
    NSString * sourceApplication = [[ENSession sharedSession] sourceApplication];
    if (!sourceApplication) {
        sourceApplication = [[NSBundle mainBundle] bundleIdentifier];
    }
    EDAMNoteAttributes * attributes = [[EDAMNoteAttributes alloc] init];
    attributes.sourceApplication = sourceApplication;

    // By convention for all iOS based apps.
    attributes.source = @"mobile.ios";

    note.attributes = attributes;
    
    // Move tags over if present.
    if (self.tagNames) {
        note.tagNames = [self.tagNames mutableCopy];
    }
    
    // Turn any ENResources on the note into EDAMResources.
    NSMutableArray * resources = [NSMutableArray array];
    for (ENResource * localResource in self.resources) {
        EDAMResource * resource = [localResource EDAMResource];
        if (resource) {
            [resources addObject:resource];
        }
    }
    if (resources.count > 0) {
        [note setResources:resources];
    }
    return note;
}

- (BOOL)validateForLimits
{
    if (self.enmlContent.length < (NSUInteger)[EDAMLimitsConstants EDAM_NOTE_CONTENT_LEN_MIN] ||
        self.enmlContent.length > (NSUInteger)[EDAMLimitsConstants EDAM_NOTE_CONTENT_LEN_MAX]) {
        ENSDKLogInfo(@"Note fails validation for content length: %@", self);
        return NO;
    }
    
    NSUInteger maxResourceSize = [EDAMLimitsConstants EDAM_RESOURCE_SIZE_MAX_FREE];
    if ([[ENSession sharedSession] isPremiumUser]) {
        maxResourceSize = [EDAMLimitsConstants EDAM_RESOURCE_SIZE_MAX_PREMIUM];
    }
    
    for (ENResource * resource in self.resources) {
        if (resource.data.length > maxResourceSize) {
            ENSDKLogInfo(@"Note fails validation for resource length: %@", self);
            return NO;
        }
    }
    
    return YES;
}

#pragma mark - For private subclasses to override

- (NSString *)generateENMLContent
{
    // This is a no-op in the base class. Subclasses use this entry point to generate ENML from
    // whatever they natively understand.
    return self.enmlContent;
}
@end
