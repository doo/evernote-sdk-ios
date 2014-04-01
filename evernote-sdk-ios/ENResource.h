//
//  ENResource.h
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 2/25/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface ENResource : NSObject
- (id)initWithData:(NSData *)data mimeType:(NSString *)mimeType filename:(NSString *)filename;
- (id)initWithData:(NSData *)data mimeType:(NSString *)mimeType;
- (id)initWithImage:(UIImage *)image;

- (NSData *)data;
- (NSString *)mimeType;
- (NSString *)filename;

// This is only useful if you're writing ENML manually. If that doesn't mean anything to you, then
// it's not useful. :)
- (NSData *)dataHash;
@end
