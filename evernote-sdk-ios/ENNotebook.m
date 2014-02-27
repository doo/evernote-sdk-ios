//
//  ENNotebook.m
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 2/25/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import "ENNotebook.h"

@interface ENNotebook ()
@property (nonatomic, strong) NSString * guid;
@property (nonatomic, strong) NSString * name;
@end

@implementation ENNotebook
- (id)initWithGuid:(NSString *)guid name:(NSString *)name
{
    self = [super init];
    if (self) {
        self.guid = guid;
        self.name = name;
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super init];
    if (self) {
        self.guid = [decoder decodeObjectForKey:@"guid"];
        self.name = [decoder decodeObjectForKey:@"name"];
        if (!self.guid || !self.name) {
            return nil;
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:self.guid forKey:@"guid"];
    [encoder encodeObject:self.name forKey:@"name"];
}
@end
