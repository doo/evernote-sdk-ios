//
//  ENNoteContent.h
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 4/10/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ENNoteContent : NSObject
+ (instancetype)noteContentWithString:(NSString *)string;
+ (instancetype)noteContentWithSanitizedHTML:(NSString *)html;
@end
