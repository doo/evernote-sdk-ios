//
//  ENSDKLogging.h
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 3/20/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

//
// The SDK sends some info and error messages to a log output. By default, these will just go to NSLog.
// You can plug into your app's own logging infrastructure if you wish by setting the shared ENSession's
// logger property to any object that implements this simple protocol. You can also suppress output
// entirely by setting the property to nil.
//

@protocol ENSDKLogging <NSObject>
- (void)evernoteLogInfoString:(NSString *)str;
- (void)evernoteLogErrorString:(NSString *)str;
@end
