//
//  ENNote.m
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 2/25/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import "ENSDKPrivate.h"
#import "ENHTMLtoENMLConverter.h"
#import "NSString+ENScrubbing.h"

#pragma mark - Subclass declarations

// ENNote is a class cluster. Because ENML generation is late-binding, private subclasses defined in this file
// are used to handle the various kinds of input content. They are asked for their ENML content when necessary.

@interface ENPlaintextNote : ENNote
@property (nonatomic, copy) NSString * stringContent;
@end

// This is currently hidden because it's not really implementated properly yet.
// Correct path is attrstring -> full html -> enml
@interface ENAttributedStringNote : ENNote
@property (nonatomic, copy) NSAttributedString * stringContent;
@end

@interface ENHTMLNote : ENNote
@property (nonatomic, copy) NSString * htmlContent;
@end

#pragma mark - ENNote

@interface ENNote ()
{
    NSMutableArray * _resources;
}
@property (nonatomic, copy) NSString * enmlContent;
@end

@implementation ENNote
// This is a dummy implementation in case anyone foolishly initializes this object directly.
- (id)init
{
    return [self initWithString:@""];
}

// This is the designated initializer. It's also what subclasses call through to.
- (id)initWithENML:(NSString *)enml
{
    self = [super init];
    if (self) {
        self.enmlContent = enml;
        _resources = [[NSMutableArray alloc] init];
    }
    return self;
}

// These are the standard initializers, which create and return subclass instances.
- (id)initWithString:(NSString *)string
{
    ENPlaintextNote * note = [[ENPlaintextNote alloc] init];
    note.stringContent = string;
    return note;
}

- (id)initWithSanitizedHTML:(NSString *)html
{
    ENHTMLNote * note = [[ENHTMLNote alloc] init];
    note.htmlContent = html;
    return note;
}

- (id)initWithAttributedString:(NSAttributedString *)string
{
    ENAttributedStringNote * note = [[ENAttributedStringNote alloc] init];
    note.stringContent = string;
    return note;
}

- (void)setTitle:(NSString *)title
{
    _title = [title en_scrubUsingRegex:[EDAMLimitsConstants EDAM_NOTE_TITLE_REGEX]
                         withMinLength:[EDAMLimitsConstants EDAM_NOTE_TITLE_LEN_MIN]
                             maxLength:[EDAMLimitsConstants EDAM_NOTE_TITLE_LEN_MAX]];
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
            [_resources addObject:resource];
        }
    }
}

#pragma mark - Protected methods

- (NSString *)content
{
    if (!self.enmlContent) {
        self.enmlContent = [self generateENMLContent];
    }
    return self.enmlContent;
}

- (void)setResources:(NSArray *)resources
{
    _resources = [NSMutableArray arrayWithArray:resources];
}

- (EDAMNote *)EDAMNote
{
    // Turn the ENNote into an EDAMNote.
    EDAMNote * note = [[EDAMNote alloc] init];
    
    note.content = [self content];
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
    if (self.content.length < (NSUInteger)[EDAMLimitsConstants EDAM_NOTE_CONTENT_LEN_MIN] ||
        self.content.length > (NSUInteger)[EDAMLimitsConstants EDAM_NOTE_CONTENT_LEN_MAX]) {
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

#pragma mark - ENPlaintextNote

@implementation ENPlaintextNote
- (id)init
{
    return [super initWithENML:nil];
}

- (NSString *)generateENMLContent
{
    // Wrap each line in a div. Empty lines get <br/>
    // From: http://dev.evernote.com/doc/articles/enml.php "representing plaintext notes"
    ENMLWriter * writer = [[ENMLWriter alloc] init];
    [writer startDocument];
    for (NSString * line in [self.stringContent componentsSeparatedByString:@"\n"]) {
        [writer startElement:@"div"];
        if (line.length == 0) {
            [writer writeElement:@"br" withAttributes:nil content:nil];
        } else {
            [writer writeString:line];
        }
        [writer endElement];
    }
    for (ENResource * resource in self.resources) {
        [writer writeResourceWithDataHash:resource.dataHash mime:resource.mimeType attributes:nil];
    }
    [writer endDocument];
    return writer.contents;
}
@end

#pragma mark - ENAttributedStringNote

@implementation ENAttributedStringNote
- (id)init
{
    // Attributed string to HTML
    return [super initWithENML:nil];
}

- (NSString *)generateENMLContent
{
    // XXX: pull out text attachments that can be resources and process those.
    
    // First convert to HTML
    NSDictionary * documentAttributes = [NSDictionary dictionaryWithObjectsAndKeys:NSHTMLTextDocumentType, NSDocumentTypeDocumentAttribute, nil];
    NSError * error = nil;
    NSData * htmlData = [self.stringContent dataFromRange:NSMakeRange(0, self.stringContent.length) documentAttributes:documentAttributes error:&error];
    if (!htmlData) {
        NSLog(@"Error converting attributed string to HTML: %@", error);
        return self.stringContent.string;
    }
    
    NSString * htmlString = [[NSString alloc] initWithData:htmlData encoding:NSUTF8StringEncoding];
    
    // Now turn that into ENML.
    ENHTMLtoENMLConverter * converter = [[ENHTMLtoENMLConverter alloc] init];
    NSString * enml = [converter enmlFromHTMLContent:htmlString];

    return enml;
}
@end

#pragma mark - ENHTMLNote

@implementation ENHTMLNote
- (id)init
{
    return [super initWithENML:nil];
}

- (NSString *)generateENMLContent
{
    ENHTMLtoENMLConverter * converter = [[ENHTMLtoENMLConverter alloc] init];
    NSString * enml = [converter enmlFromHTMLContent:self.htmlContent];
    return enml;
}
@end
