//
//  ENNote.h
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 2/25/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ENNotebook.h"
#import "ENResource.h"

@interface ENNote : NSObject // <NSCoding>
@property (nonatomic, copy) NSString * title;
@property (nonatomic, strong) ENNotebook * notebook;
- (id)initWithString:(NSString *)string;
- (id)initWithENML:(NSString *)enml;
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 70000
- (id)initWithAttributedString:(NSAttributedString *)string;
#endif
- (NSArray *)resources;
- (void)addResource:(ENResource *)resource;
@end
