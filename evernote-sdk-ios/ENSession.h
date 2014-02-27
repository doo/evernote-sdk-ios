//
//  ENSession.h
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 2/25/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "ENNote.h"

@interface ENSession : NSObject
@property (nonatomic, readonly) BOOL isAuthenticated;
@property (nonatomic, readonly) NSString * userDisplayName;

+ (void)setSharedSessionHost:(NSString *)host consumerKey:(NSString *)key consumerSecret:(NSString *)secret;
+ (void)setSharedDeveloperKey:(NSString *)key noteStoreUrl:(NSString *)url;

+ (ENSession *)sharedSession;

- (void)authenticateWithViewController:(UIViewController *)viewController complete:(void(^)(BOOL success, NSString * localizedError))complete;
- (void)logout;

- (void)notebooks:(void(^)(NSArray * notebooks, NSString * localizedError))complete;

- (void)uploadNote:(ENNote *)note replaceNoteID:(NSString *)noteToReplace complete:(void(^)(NSString * noteID, NSString * localizedError))complete;
@end
