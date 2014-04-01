//
//  ENError.m
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 3/13/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import "ENError.h"

#if !__has_feature(objc_arc)
#error Evernote iOS SDK must be built with ARC.
// You can turn on ARC for only Evernote SDK files by adding -fobjc-arc to the build phase for each of its files.
#endif

NSString * ENErrorDomain = @"ENErrorDomain";
