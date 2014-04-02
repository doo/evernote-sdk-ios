//
//  NSString+ENScrubbing.h
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 3/24/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (ENScrubbing)

- (NSString *)en_scrubUsingRegex:(NSString *)regexPattern
                   withMinLength:(uint16_t)minLength
                       maxLength:(uint16_t)maxLength
     invalidCharacterReplacement:(NSString *)replacement;

- (NSString *)en_scrubUsingRegex:(NSString *)regexPattern
                   withMinLength:(uint16_t)minLength
                       maxLength:(uint16_t)maxLength;

@end
