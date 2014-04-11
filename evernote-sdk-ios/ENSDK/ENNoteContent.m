//
//  ENNoteContent.m
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 4/10/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import "ENNoteContent.h"
#import "ENPlaintextNoteContent.h"
#import "ENHTMLNoteContent.h"
#import "ENSDKPrivate.h"

@interface ENNoteContent ()
@property (nonatomic, copy) NSString * emml;
@end

@implementation ENNoteContent
+ (instancetype)noteContentWithString:(NSString *)string;
{
    return [[ENPlaintextNoteContent alloc] initWithString:string];
}

+ (instancetype)noteContentWithSanitizedHTML:(NSString *)html
{
    return [[ENHTMLNoteContent alloc] initWithHTML:html];
}

+ (instancetype)noteContentWithENML:(NSString *)enml
{
    return [[ENNoteContent alloc] initWithENML:enml];
}

- (id)initWithENML:(NSString *)enml
{
    self = [super init];
    if (self) {
        self.emml = enml;
    }
    return self;
}

- (NSString *)enmlWithResources:(NSArray *)resources
{
    if (resources.count > 0) {
        ENSDKLogInfo(@"Cannot append resources to an immutable %@. Ignoring.", [self class]);
    }
    return self.emml;
}
@end
