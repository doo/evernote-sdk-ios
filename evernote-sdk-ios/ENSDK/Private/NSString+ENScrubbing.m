//
//  NSString+ENScrubbing.m
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 3/24/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import "NSString+ENScrubbing.h"

@implementation NSString (ENScrubbing)

- (NSString *)en_scrubUsingRegex:(NSString *)regexPattern
                   withMinLength:(uint16_t)minLength
                       maxLength:(uint16_t)maxLength
     invalidCharacterReplacement:(NSString *)replacement
{
    NSString * string = self;
    if ([string length] < minLength) {
        return nil;
    }
    else if ([string length] > maxLength) {
        string = [string substringToIndex:maxLength];
    }
    
    NSRegularExpression * regex = [NSRegularExpression regularExpressionWithPattern:regexPattern options:0 error:NULL];
    NSArray * matches = [regex matchesInString:string options:0 range:NSMakeRange(0, string.length)];
    if (matches.count == 0) {
        NSMutableString * newString = [NSMutableString stringWithCapacity:[string length]];
        for (NSUInteger i = 0; i < [string length]; i++) {
            NSString * oneCharSubString = [string substringWithRange:NSMakeRange(i, 1)];
            matches = [regex matchesInString:oneCharSubString options:0 range:NSMakeRange(0, 1)];
            if (matches.count > 0) {
                [newString appendString:oneCharSubString];
            } else if (replacement != nil) {
                [newString appendString:replacement];
            }
        }
        string = newString;
    }
    
    if ([string length] < minLength) {
        return nil;
    }
    
    return string;
}

- (NSString *)en_scrubUsingRegex:(NSString *)regexPattern
                   withMinLength:(uint16_t)minLength
                       maxLength:(uint16_t)maxLength
{
    return [self en_scrubUsingRegex:regexPattern
                      withMinLength:minLength
                          maxLength:maxLength
        invalidCharacterReplacement:nil];
}

@end
