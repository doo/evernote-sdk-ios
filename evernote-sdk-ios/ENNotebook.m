//
//  ENNotebook.m
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 2/25/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import "ENNotebook.h"
#import "EvernoteSDK.h"

@interface ENNotebook ()
@property (nonatomic, strong) NSString * guid;
@property (nonatomic, strong) NSString * name;
@property (nonatomic, assign) BOOL isApplicationDefaultNotebook;
@property (nonatomic, assign) BOOL isAccountDefaultNotebook;
@end

@implementation ENNotebook
- (id)initWithEdamNotebook:(EDAMNotebook *)notebook isApplicationDefault:(BOOL)isDefault
{
    self = [super init];
    if (self) {
        self.guid = notebook.guid;
        self.name = notebook.name;
        self.isApplicationDefaultNotebook = isDefault;
        self.isAccountDefaultNotebook = notebook.defaultNotebook;
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super init];
    if (self) {
        self.guid = [decoder decodeObjectForKey:@"guid"];
        self.name = [decoder decodeObjectForKey:@"name"];
        self.isApplicationDefaultNotebook = [decoder decodeBoolForKey:@"isApplicationDefaultNotebook"];
        self.isAccountDefaultNotebook = [decoder decodeBoolForKey:@"isAccountDefaultNotebook"];
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
    [encoder encodeBool:self.isApplicationDefaultNotebook forKey:@"isApplicationDefaultNotebook"];
    [encoder encodeBool:self.isAccountDefaultNotebook forKey:@"isAccountDefaultNotebook"];
}
@end
