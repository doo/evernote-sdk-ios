//
//  ENPlaintextNoteContent.m
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 4/10/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import "ENPlaintextNoteContent.h"
#import "ENSDKPrivate.h"
#import "ENMLWriter.h"

@interface ENPlaintextNoteContent ()
@property (nonatomic, copy) NSString * string;
@end

@implementation ENPlaintextNoteContent
- (id)initWithString:(NSString *)string
{
    self = [super init];
    if (self) {
        self.string = string;
    }
    return self;
}

- (NSString *)enmlWithResources:(NSArray *)resources
{
    // Wrap each line in a div. Empty lines get <br/>
    // From: http://dev.evernote.com/doc/articles/enml.php "representing plaintext notes"
    ENMLWriter * writer = [[ENMLWriter alloc] init];
    [writer startDocument];
    for (NSString * line in [self.string componentsSeparatedByString:@"\n"]) {
        [writer startElement:@"div"];
        if (line.length == 0) {
            [writer writeElement:@"br" withAttributes:nil content:nil];
        } else {
            [writer writeString:line];
        }
        [writer endElement];
    }
    for (ENResource * resource in resources) {
        [writer writeResourceWithDataHash:resource.dataHash mime:resource.mimeType attributes:nil];
    }
    [writer endDocument];
    return writer.contents;
}
@end
