//
//  ENSDKPrivate.h
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 2/25/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#ifndef evernote_sdk_ios_ENSDKPrivate_h
#define evernote_sdk_ios_ENSDKPrivate_h

#import "ENSDK.h"
#import "EvernoteSDK.h"

@interface ENNotebook (Private)
@property (nonatomic, readonly) NSString * guid;
- (id)initWithEdamNotebook:(EDAMNotebook *)notebook isApplicationDefault:(BOOL)isDefault;
@end

@interface ENResource (Private)
- (EDAMResource *)EDAMResource;
@end

@interface ENNote (Private)
- (NSString *)content;
- (void)setGuid:(NSString *)guid;
- (void)setEnmlContent:(NSString *)enmlContent;
- (void)setResources:(NSArray *)resources;
- (EDAMNote *)EDAMNote;
@end

#endif
