//
//  ENSDKLogging.h
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 3/20/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

@protocol ENSDKLogging <NSObject>
- (void)logInfoString:(NSString *)str;
- (void)logErrorString:(NSString *)str;
@end
