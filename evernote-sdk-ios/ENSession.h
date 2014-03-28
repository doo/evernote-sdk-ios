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
#import "ENSDKLogging.h"

typedef void (^ENSessionAuthenticateCompletionHandler)(NSError * authenticateError);
typedef void (^ENSessionListNotebooksCompletionHandler)(NSArray * notebooks, NSError * listNotebooksError);
typedef void (^ENSessionUploadNoteProgressHandler)(CGFloat progress);
typedef void (^ENSessionUploadNoteCompletionHandler)(ENNoteRef * noteRef, NSError * uploadNoteError);
typedef void (^ENSessionShareNoteCompletionHandler)(NSString * url, NSError * shareNoteError);
typedef void (^ENSessionDeleteNoteCompletionHandler)(NSError * deleteNoteError);

typedef NS_ENUM(NSInteger, ENSessionUploadPolicy) {
    ENSessionUploadPolicyCreate,
    ENSessionUploadPolicyReplace,
    ENSessionUploadPolicyReplaceOrCreate
};

@interface ENSession : NSObject
@property (nonatomic, strong) id<ENSDKLogging> logger;
@property (nonatomic, copy) NSString * defaultNotebookName;
@property (nonatomic, copy) NSString * sourceApplication;  

@property (nonatomic, readonly) BOOL isAuthenticated;
@property (nonatomic, readonly) BOOL isAuthenticationInProgress;

@property (nonatomic, readonly) BOOL isPremiumUser;
@property (nonatomic, readonly) BOOL isBusinessUser;
@property (nonatomic, readonly) NSString * userDisplayName;
@property (nonatomic, readonly) NSString * businessDisplayName;

+ (void)setSharedSessionHost:(NSString *)host
                 consumerKey:(NSString *)key
              consumerSecret:(NSString *)secret;

+ (void)setSharedSessionHost:(NSString *)host
              developerToken:(NSString *)token
                noteStoreUrl:(NSString *)url;

+ (ENSession *)sharedSession;

- (void)authenticateWithViewController:(UIViewController *)viewController
                            completion:(ENSessionAuthenticateCompletionHandler)completion;
- (void)logout;

- (void)listNotebooksWithHandler:(ENSessionListNotebooksCompletionHandler)completion;

// Easy convenience method for creating new notes.
- (void)uploadNote:(ENNote *)note
        completion:(ENSessionUploadNoteCompletionHandler)completion;

// Use the full method if you want to track progress, overwrite existing notes, etc.
- (void)uploadNote:(ENNote *)note
            policy:(ENSessionUploadPolicy)policy
       replaceNote:(ENNoteRef *)noteToReplace
          progress:(ENSessionUploadNoteProgressHandler)progress
        completion:(ENSessionUploadNoteCompletionHandler)completion;

- (void)shareNoteRef:(ENNoteRef *)noteRef
          completion:(ENSessionShareNoteCompletionHandler)completion;

- (void)deleteNoteRef:(ENNoteRef *)noteRef
           completion:(ENSessionDeleteNoteCompletionHandler)completion;
@end
