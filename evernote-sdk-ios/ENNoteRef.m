//
//  ENNoteRef.m
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 3/7/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import "ENNoteRef.h"

@interface ENNoteRef ()
@property (nonatomic, copy) NSString * guid;
@end

@implementation ENNoteRef
+ (instancetype)noteRefFromData:(NSData *)data
{
    if (!data) {
        return nil;
    }
    id root = nil;
    @try {
        root = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    }
    @catch(id e) {
    }
    if (root && [root isKindOfClass:[self class]]) {
        return root;
    }
    return nil;
}

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super init];
    if (self) {
        self.guid = [decoder decodeObjectForKey:@"guid"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:self.guid forKey:@"guid"];
}

- (NSData *)asData
{
    return [NSKeyedArchiver archivedDataWithRootObject:self];
}
@end
