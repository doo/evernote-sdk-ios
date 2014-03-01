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

static NSString * ENSEssionPreferencesFilename = @"com.evernote.evernote-sdk-ios.plist";

static NSString * ENSessionDefaultNotebookGuid = @"ENSessionDefaultNotebookGuid";

@interface ENSessionUploadNoteContext : NSObject
@property (nonatomic, strong) EDAMNote * note;
@property (nonatomic, strong) NSString * guidToReplace;
@property (nonatomic, strong) NSString * defaultNotebookName;
@property (nonatomic, strong) ENSessionUploadNoteCompletionHandler handler;
@end

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

- (void)authenticateWithViewController:(UIViewController *)viewController handler:(void(^)(NSError * authenticateError))handler;
{
    self.isAuthenticated = NO;
    self.user = nil;
    
    //XXX: use EvernoteSession to bootstrap this for now...
    if (SessionHost) {
        [EvernoteSession setSharedSessionHost:SessionHost consumerKey:ConsumerKey consumerSecret:ConsumerSecret];
    }
    [[EvernoteSession sharedSession] authenticateWithViewController:viewController completionHandler:^(NSError * error) {
        if (error) {
            handler(error);
        } else {
            self.isAuthenticated = YES;
            [[EvernoteUserStore userStore] getUserWithSuccess:^(EDAMUser * user) {
                self.user = user;
                handler(nil);
            } failure:^(NSError * getUserError) {
                //xxx Log error. Keep name nil?
                handler(nil);
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
    [self removeAllPreferences];
    [[EvernoteSession sharedSession] logout];
}

- (void)listNotebooksWithHandler:(ENSessionListNotebooksCompletionHandler)handler
{
    if (!handler) {
        [NSException raise:NSInvalidArgumentException format:@"handler required"];
        return;
    }
    if (!self.isAuthenticated) {
        handler(nil, [NSError errorWithDomain:EvernoteSDKErrorDomain code:EDAMErrorCode_INVALID_AUTH userInfo:nil]);
        return;
    }
    [[EvernoteNoteStore noteStore] listNotebooksWithSuccess:^(NSArray * notebooks) {
        NSMutableArray * results = [NSMutableArray array];
        for (EDAMNotebook * edamNotebook in notebooks) {
            BOOL isApplicationDefaultNotebook = [[self defaultNotebookGuid] isEqualToString:edamNotebook.guid];
            ENNotebook * notebook = [[ENNotebook alloc] initWithEdamNotebook:edamNotebook isApplicationDefault:isApplicationDefaultNotebook];
            [results addObject:notebook];
        }
        handler(results, nil);
    } failure:^(NSError * error) {
        handler(nil, error);
    }];
}

#pragma mark - uploadNote

- (void)uploadNote:(ENNote *)note replaceNoteId:(NSString *)noteToReplace handler:(ENSessionUploadNoteCompletionHandler)handler
{
    if (!note || !handler) {
        [NSException raise:NSInvalidArgumentException format:@"note and handler required"];
        return;
    }
    
    if (!self.isAuthenticated) {
        handler(nil, [NSError errorWithDomain:EvernoteSDKErrorDomain code:EDAMErrorCode_INVALID_AUTH userInfo:nil]);
        return;
    }
    
    ENSessionUploadNoteContext * context = [[ENSessionUploadNoteContext alloc] init];
    context.note = [note EDAMNote];
    context.guidToReplace = noteToReplace;
    context.handler = handler;
    
    if (noteToReplace) {
        [self uploadNote_updateWithContext:context];
    } else {
        if (!context.note.notebookGuid) {
            // Caller has not specified an explicit notebook. Is there a default notebook set?
            if (self.defaultNotebookName) {
                // Check to see if we already know about a notebook GUID.
                NSString * notebookGuid = [self defaultNotebookGuid];
                if (notebookGuid) {
                    context.note.notebookGuid = notebookGuid;
                } else {
                    // We need to create/find the notebook that corresponds to this.
                    // Need to do a lookup.
                    context.defaultNotebookName = self.defaultNotebookName;
                    [self uploadNote_findDefaultNotebookWithContext:context];
                    return;
                }
            }
        }
        [self uploadNote_createWithContext:context];
    }
}

- (void)uploadNote_findDefaultNotebookWithContext:(ENSessionUploadNoteContext *)context
{
    [[EvernoteNoteStore noteStore] listNotebooksWithSuccess:^(NSArray * notebooks) {
        // Walk the notebooks to see if any of them match the default that we're looking for.
        for (EDAMNotebook * notebook in notebooks) {
            if ([notebook.name caseInsensitiveCompare:context.defaultNotebookName] == NSOrderedSame) {
                [self setDefaultNotebookGuid:notebook.guid];
                context.note.guid = notebook.guid;
                [self uploadNote_createWithContext:context];
                return;
            }
        }
        // None matched. Create it.
        [self uploadNote_createNotebookWithContext:context];
    } failure:^(NSError * error) {
        context.handler(nil, error);
    }];
}

- (void)uploadNote_createNotebookWithContext:(ENSessionUploadNoteContext *)context
{
    EDAMNotebook * notebook = [[EDAMNotebook alloc] init];
    notebook.name = context.defaultNotebookName;
    [[EvernoteNoteStore noteStore] createNotebook:notebook success:^(EDAMNotebook * resultNotebook) {
        [self setDefaultNotebookGuid:resultNotebook.guid];
        context.note.notebookGuid = resultNotebook.guid;
        [self uploadNote_createWithContext:context];
    } failure:^(NSError * error) {
        context.handler(nil, error);
    }];
}

- (void)uploadNote_updateWithContext:(ENSessionUploadNoteContext *)context
{
    context.note.guid = context.guidToReplace;
    [[EvernoteNoteStore noteStore] updateNote:context.note success:^(EDAMNote * resultNote) {
        context.handler(resultNote.guid, nil);
    } failure:^(NSError *error) {
        context.handler(nil, error);
    }];
}

- (void)uploadNote_createWithContext:(ENSessionUploadNoteContext *)context
{
    [[EvernoteNoteStore noteStore] createNote:context.note success:^(EDAMNote * resultNote) {
        context.handler(resultNote.guid, nil);
    } failure:^(NSError * error) {
        context.handler(nil, error);
    }];
}

#pragma mark - Private routines

static NSString * PreferencesPath()
{
    NSArray * paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    return [[paths[0] stringByAppendingPathComponent:@"Preferences"] stringByAppendingPathComponent:ENSEssionPreferencesFilename];
}

- (id)preferencesObjectForKey:(NSString *)key
{
    NSDictionary * prefs = [NSDictionary dictionaryWithContentsOfFile:PreferencesPath()];
    return [prefs objectForKey:key];
}

- (void)setPreferencesObject:(id)obj forKey:(NSString *)key
{
    NSMutableDictionary * prefs = [NSDictionary dictionaryWithContentsOfFile:PreferencesPath()];
    if (!prefs) {
        prefs = [NSMutableDictionary dictionary];
    }
    [prefs setObject:obj forKey:key];
    [prefs writeToFile:PreferencesPath() atomically:YES];
}

- (void)removeAllPreferences
{
    [[NSFileManager defaultManager] removeItemAtPath:PreferencesPath() error:NULL];
}

- (NSString *)defaultNotebookGuid
{
    return [self preferencesObjectForKey:ENSessionDefaultNotebookGuid];
}

- (void)setDefaultNotebookGuid:(NSString *)guid
{
    [self setPreferencesObject:guid forKey:ENSessionDefaultNotebookGuid];
}
@end

#pragma mark - ENSessionUploadNoteContext implementation

@implementation ENSessionUploadNoteContext
@end
