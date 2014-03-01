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

typedef void (^ENSessionUploadNoteCompletionHandler)(NSString * noteId, NSError * uploadNoteError);
typedef void (^ENSessionListNotebooksCompletionHandler)(NSArray * notebooks, NSError * listNotebooksError);

@interface ENSession : NSObject
@property (nonatomic, copy) NSString * defaultNotebookName;

@property (nonatomic, readonly) BOOL isAuthenticated;
@property (nonatomic, readonly) NSString * userDisplayName;

+ (void)setSharedSessionHost:(NSString *)host consumerKey:(NSString *)key consumerSecret:(NSString *)secret;
+ (void)setSharedDeveloperKey:(NSString *)key noteStoreUrl:(NSString *)url;

+ (ENSession *)sharedSession;

- (void)authenticateWithViewController:(UIViewController *)viewController handler:(void(^)(NSError * authenticateError))handler;
- (void)logout;

- (void)listNotebooksWithHandler:(ENSessionListNotebooksCompletionHandler)handler;
- (void)uploadNote:(ENNote *)note replaceNoteId:(NSString *)noteToReplace handler:(ENSessionUploadNoteCompletionHandler)handler;
@end
