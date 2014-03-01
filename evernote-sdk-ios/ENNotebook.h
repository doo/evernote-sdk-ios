//
//  ENNotebook.h
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 2/25/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ENNotebook : NSObject <NSCoding>
@property (nonatomic, readonly) NSString * name;
@property (nonatomic, readonly) BOOL isApplicationDefaultNotebook;
@property (nonatomic, readonly) BOOL isAccountDefaultNotebook;
@end
