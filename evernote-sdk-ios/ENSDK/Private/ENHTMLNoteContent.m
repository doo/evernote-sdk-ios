//
//  ENHTMLNoteContent.m
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 4/10/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import "ENHTMLNoteContent.h"
#import "ENHTMLtoENMLConverter.h"

@interface ENHTMLNoteContent ()
@property (nonatomic, copy) NSString * html;
@end

@implementation ENHTMLNoteContent
- (id)initWithHTML:(NSString *)html
{
    self = [super init];
    if (self) {
        self.html = html;
    }
    return self;
}

- (NSString *)enmlWithResources:(NSArray *)resources
{
    //XXX: Doesn't handle resources (yet?)
    ENHTMLtoENMLConverter * converter = [[ENHTMLtoENMLConverter alloc] init];
    NSString * enml = [converter enmlFromHTMLContent:self.html];
    return enml;
}
@end
