//
//  ENSession.h
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 2/25/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "ENSDK.h"

typedef void (^ENSessionUploadNoteProgressHandler)(CGFloat progress);
typedef void (^ENSessionUploadNoteCompletionHandler)(NSString * noteId, NSError * uploadNoteError);
typedef void (^ENSessionListNotebooksCompletionHandler)(NSArray * notebooks, NSError * listNotebooksError);

typedef NS_ENUM(NSInteger, ENSessionUploadPolicy) {
    ENSessionUploadPolicyCreate,
    ENSessionUploadPolicyReplace,
    ENSessionUploadPolicyReplaceOrCreate
};

@interface ENSession : NSObject
@property (nonatomic, copy) NSString * defaultNotebookName;

@property (nonatomic, readonly) BOOL isAuthenticated;
@property (nonatomic, readonly) NSString * userDisplayName;
@property (nonatomic, readonly) NSString * businessName;

+ (void)setSharedSessionHost:(NSString *)host consumerKey:(NSString *)key consumerSecret:(NSString *)secret;
+ (void)setSharedDeveloperKey:(NSString *)key noteStoreUrl:(NSString *)url;

+ (ENSession *)sharedSession;

- (void)authenticateWithViewController:(UIViewController *)viewController handler:(void(^)(NSError * authenticateError))handler;
- (void)logout;

- (void)listNotebooksWithHandler:(ENSessionListNotebooksCompletionHandler)completion;

// Easy convenience method for creating new notes.
- (void)uploadNote:(ENNote *)note
        completion:(ENSessionUploadNoteCompletionHandler)completion;

// Use the full method if you want to track progress, overwrite existing notes, etc.
- (void)uploadNote:(ENNote *)note
            policy:(ENSessionUploadPolicy)policy
     replaceNoteId:(NSString *)noteToReplace
          progress:(ENSessionUploadNoteProgressHandler)progress
        completion:(ENSessionUploadNoteCompletionHandler)completion;
@end
