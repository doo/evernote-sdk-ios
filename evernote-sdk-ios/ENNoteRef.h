//
//  ENNoteRef.h
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 3/7/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import <Foundation/Foundation.h>

// An opaque reference to an existing note in the service. It can be used to
// share or update that same note at a later time.
@interface ENNoteRef : NSObject <NSCoding>
+ (instancetype)noteRefFromData:(NSData *)data;
- (NSData *)asData;
@end

