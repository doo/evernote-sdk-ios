//
//  ENNote.h
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 2/25/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Availability.h"
@class ENResource;
@class ENNotebook;

@interface ENNote : NSObject
@property (nonatomic, copy) NSString * title;
@property (nonatomic, strong) ENNoteContent * content;
@property (nonatomic, strong) ENNotebook * notebook;
@property (nonatomic, copy) NSArray * tagNames;
- (NSArray *)resources;
- (void)addResource:(ENResource *)resource;
@end
