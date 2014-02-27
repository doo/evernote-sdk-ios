//
//  ENSession.m
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 2/25/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import "ENSession.h"
#import "EvernoteSDK.h"
#import "ENNotebook.h"
#import "ENSDKPrivate.h"

@interface ENSession ()
@property (nonatomic, assign) BOOL isAuthenticated;
@property (nonatomic, strong) EDAMUser * user;
@end

@implementation ENSession

static NSString * SessionHost, * ConsumerKey, * ConsumerSecret;
static NSString * DeveloperKey, * NoteStoreUrl;

+ (void)setSharedSessionHost:(NSString *)host consumerKey:(NSString *)key consumerSecret:(NSString *)secret
{
    SessionHost = host;
    ConsumerKey = key;
    ConsumerSecret = secret;
    
    DeveloperKey = nil;
    NoteStoreUrl = nil;
}

+ (void)setSharedDeveloperKey:(NSString *)key noteStoreUrl:(NSString *)url
{
    DeveloperKey = key;
    NoteStoreUrl = url;

    SessionHost = nil;
    ConsumerKey = nil;
    ConsumerSecret = nil;
}

+ (ENSession *)sharedSession
{
    static ENSession * session = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        session = [[ENSession alloc] init];
    });
    return session;
}

- (void)authenticateWithViewController:(UIViewController *)viewController
                              complete:(void(^)(BOOL success, NSString * localizedError))complete;
{
    self.isAuthenticated = NO;
    self.user = nil;
    
    //XXX: use EvernoteSession to bootstrap this for now...
    if (SessionHost) {
        [EvernoteSession setSharedSessionHost:SessionHost consumerKey:ConsumerKey consumerSecret:ConsumerSecret];
    }
    [[EvernoteSession sharedSession] authenticateWithViewController:viewController completionHandler:^(NSError * error) {
        if (error) {
            complete(NO, [error localizedDescription]);
        } else {
            self.isAuthenticated = YES;
            [[EvernoteUserStore userStore] getUserWithSuccess:^(EDAMUser * user) {
                self.user = user;
                complete(YES, nil);
            } failure:^(NSError * getUserError) {
                //xxx Log error. Keep name nil?
                complete(YES, nil);
            }];
        }
    }];
}

- (NSString *)userDisplayName
{
    return self.user.name ?: self.user.username;
}

- (void)logout
{
    self.isAuthenticated = NO;
    self.user = nil;
    [[EvernoteSession sharedSession] logout];
}

- (void)notebooks:(void(^)(NSArray * notebooks, NSString * localizedError))complete
{
    if (!self.isAuthenticated) {
        complete(nil, @"Not authenticated"); // xxx string + callback ordering?
        return;
    }
    [[EvernoteNoteStore noteStore] listNotebooksWithSuccess:^(NSArray * notebooks) {
        NSMutableArray * results = [NSMutableArray array];
        for (EDAMNotebook * edamNotebook in notebooks) {
            ENNotebook * notebook = [[ENNotebook alloc] initWithGuid:edamNotebook.guid name:edamNotebook.name];
            if (notebook) {
                [results addObject:notebook];
            }
        }
        complete(results, nil);
    } failure:^(NSError * error) {
        complete(nil, [error localizedDescription]);
    }];
}

- (void)uploadNote:(ENNote *)note replaceNoteID:(NSString *)noteToReplace complete:(void(^)(NSString * noteID, NSString * localizedError))complete
{
    if (!self.isAuthenticated) {
        complete(nil, @"Not authenticated"); // xxx string + callback ordering?
        return;
    }
    if (noteToReplace) {
        // updateNote
        EDAMNote * edamNote = [note EDAMNote];
        edamNote.guid = noteToReplace;
        [[EvernoteNoteStore noteStore] updateNote:edamNote success:^(EDAMNote * resultNote) {
            complete(noteToReplace, nil);
        } failure:^(NSError *error) {
            complete(nil, [error localizedDescription]);
        }];
    } else {
        // createNote
        [[EvernoteNoteStore noteStore] createNote:[note EDAMNote] success:^(EDAMNote * resultNote) {
            complete(resultNote.guid, nil);
        } failure:^(NSError * error) {
            complete(nil, [error localizedDescription]);
        }];
    }
}
@end
