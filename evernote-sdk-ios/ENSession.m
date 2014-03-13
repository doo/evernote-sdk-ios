//
//  ENSession.m
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 2/25/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import "EvernoteSDK.h"
#import "ENSDKPrivate.h"
#import "ENAuthCache.h"
#import "ENNoteStoreClient.h"
#import "ENCredentialStore.h"

static NSString * ENSEssionPreferencesFilename = @"com.evernote.evernote-sdk-ios.plist";

static NSString * ENSessionDefaultNotebookGuid = @"ENSessionDefaultNotebookGuid";

@interface ENSessionListNotebooksContext : NSObject
@property (nonatomic, strong) NSArray * personalNotebooks;
@property (nonatomic, strong) NSArray * linkedNotebooks;
@property (nonatomic, strong) NSDictionary * sharedNotebooks; // map linkedNotebook.guid -> sharedNotebook
@property (nonatomic, strong) NSDictionary * businessNotebooks; // map linkedNotebook.guid -> notebook
@property (nonatomic, assign) NSInteger pendingSharedNotebooks;
@property (nonatomic, strong) NSError * error;
@property (nonatomic, strong) ENSessionListNotebooksCompletionHandler completion;
@end

@interface ENSessionUploadNoteContext : NSObject
@property (nonatomic, strong) EDAMNote * note;
@property (nonatomic, strong) ENNoteStoreClient * destinationNoteStore;
@property (nonatomic, strong) ENNoteRef * refToReplace;
@property (nonatomic, assign) ENSessionUploadPolicy policy;
@property (nonatomic, assign) BOOL destinedForDefaultNotebook;
@property (nonatomic, strong) NSString * defaultNotebookName;
@property (nonatomic, strong) ENSessionUploadNoteCompletionHandler completion;
@end

@interface ENSession () <ENStoreClientDelegate, ENNoteStoreClientDelegate>
@property (nonatomic, assign) BOOL isAuthenticated;
@property (nonatomic, strong) EDAMUser * user;
@property (nonatomic, strong) ENCredentialStore * credentialStore;
@property (nonatomic, strong) NSString * primaryAuthenticationToken;
@property (nonatomic, strong) ENNoteStoreClient * primaryNoteStore;
@property (nonatomic, strong) ENNoteStoreClient * businessNoteStore;
@property (nonatomic, strong) ENAuthCache * linkedAuthCache;
@property (nonatomic, strong) dispatch_queue_t sharedQueue;
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

// XXX: This doesn't do anything yet.
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

- (id)init
{
    self = [super init];
    if (self) {
        self.sharedQueue = dispatch_queue_create("com.evernote.sdk.ENSession", NULL);
    }
    return self;
}

- (void)dealloc
{
#if !OS_OBJECT_USE_OBJC
    dispatch_release(_sharedQueue);
#endif
}

- (void)authenticateWithViewController:(UIViewController *)viewController
                            completion:(ENSessionAuthenticateCompletionHandler)completion
{
    self.isAuthenticated = NO;
    self.user = nil;
    
    if (!completion) {
        [NSException raise:NSInvalidArgumentException format:@"handler required"];
        return;
    }
    
    //XXX: use EvernoteSession to bootstrap this for now...
    if (SessionHost) {
        [EvernoteSession setSharedSessionHost:SessionHost consumerKey:ConsumerKey consumerSecret:ConsumerSecret];
    }
    [[EvernoteSession sharedSession] authenticateWithViewController:viewController completionHandler:^(NSError * error) {
        if (error) {
            completion(error);
        } else {
            self.isAuthenticated = YES;
            self.credentialStore = [ENCredentialStore loadCredentials];
            ENCredentials * credentials = [self.credentialStore credentialsForHost:SessionHost];
            self.primaryAuthenticationToken = credentials.authenticationToken;
            [[EvernoteUserStore userStore] getUserWithSuccess:^(EDAMUser * user) {
                self.user = user;
                [[EvernoteUserStore userStore] authenticateToBusinessWithSuccess:^(EDAMAuthenticationResult *authenticationResult) {
                    //XXXX: Don't do this here.
                    self.businessNoteStore = [ENNoteStoreClient noteStoreClientWithUrl:authenticationResult.noteStoreUrl authenticationToken:authenticationResult.authenticationToken];
                    self.businessNoteStore.storeClientDelegate = self;
                    self.businessNoteStore.noteStoreDelegate = self;
                    completion(nil);
                } failure:^(NSError * authenticateToBusinessError) {
                    completion(nil);
                }];
            } failure:^(NSError * getUserError) {
                //xxx Log error. Keep name nil?
                completion(nil);
            }];
        }
    }];
}

- (NSString *)userDisplayName
{
    return self.user.name ?: self.user.username;
}

- (NSString *)businessName
{
    if (self.user.accounting.businessId) {
        return self.user.accounting.businessName;
    }
    return nil;
}

- (void)logout
{
    self.isAuthenticated = NO;
    self.user = nil;
    self.primaryAuthenticationToken = nil;
    self.primaryNoteStore = nil;
    self.businessNoteStore = nil;
    self.linkedAuthCache = nil;
    [self removeAllPreferences];
    [[EvernoteSession sharedSession] logout];
}

#pragma mark - listNotebooks

- (void)listNotebooksWithHandler:(ENSessionListNotebooksCompletionHandler)completion
{
    if (!completion) {
        [NSException raise:NSInvalidArgumentException format:@"handler required"];
        return;
    }
    if (!self.isAuthenticated) {
        completion(nil, [NSError errorWithDomain:EvernoteSDKErrorDomain code:EDAMErrorCode_INVALID_AUTH userInfo:nil]);
        return;
    }
    ENSessionListNotebooksContext * context = [[ENSessionListNotebooksContext alloc] init];
    context.completion = completion;
    [self listNotebooks_listNotebooksWithContext:context];
}

- (void)listNotebooks_listNotebooksWithContext:(ENSessionListNotebooksContext *)context
{
    [self.primaryNoteStore listNotebooksWithSuccess:^(NSArray * notebooks) {
        context.personalNotebooks = notebooks;
        // Now get any linked notebooks.
        [self listNotebooks_listLinkedNotebooksWithContext:context];
    } failure:^(NSError * error) {
        [self listNotebooks_completeWithContext:context notebooks:nil error:error];
    }];
}

- (void)listNotebooks_listLinkedNotebooksWithContext:(ENSessionListNotebooksContext *)context
{
    [self.primaryNoteStore listLinkedNotebooksWithSuccess:^(NSArray *linkedNotebooks) {
        if (linkedNotebooks.count == 0) {
            [self listNotebooks_prepareResultsWithContext:context];
        } else {
            context.linkedNotebooks = linkedNotebooks;
            // We need to figure out privilege levels on all of these notebooks, which is byzantine
            // at best, but here we go.
            [self listNotebooks_fetchSharedNotebooksWithContext:context];
        }
    } failure:^(NSError *error) {
        [self listNotebooks_completeWithContext:context notebooks:nil error:error];
    }];
}

- (void)listNotebooks_fetchSharedNotebooksWithContext:(ENSessionListNotebooksContext *)context
{
    context.pendingSharedNotebooks = context.linkedNotebooks.count;
    NSMutableDictionary * sharedNotebooks = [[NSMutableDictionary alloc] init];
    context.sharedNotebooks = sharedNotebooks;
    NSMutableDictionary * businessNotebooks = [[NSMutableDictionary alloc] init];
    context.businessNotebooks = businessNotebooks;
    
    for (EDAMLinkedNotebook * linkedNotebook in context.linkedNotebooks) {
        ENNoteStoreClient * noteStore = [self noteStoreForLinkedNotebook:linkedNotebook];
        [noteStore getSharedNotebookByAuthWithSuccess:^(EDAMSharedNotebook * sharedNotebook) {
            // Add the shared notebook to the map.
            [sharedNotebooks setObject:sharedNotebook forKey:linkedNotebook.guid];
            // If the shared notebook shows a group privilege level, we're on the hook for another call to get the actual
            // notebook object that corresponds to it, which will contain the real privilege level.
            if (sharedNotebook.privilege == SharedNotebookPrivilegeLevel_GROUP) {
                ENNoteStoreClient * businessNoteStore = [self businessNoteStore];
                [businessNoteStore getNotebookWithGuid:sharedNotebook.notebookGuid success:^(EDAMNotebook * correspondingNotebook) {
                    [businessNotebooks setObject:correspondingNotebook forKey:linkedNotebook.guid];
                    [self listNotebooks_completePendingSharedNotebookWithContext:context];
                } failure:^(NSError *error) {
                    context.error = error;
                    [self listNotebooks_completePendingSharedNotebookWithContext:context];
                }];
                return;
            }
            [self listNotebooks_completePendingSharedNotebookWithContext:context];
        } failure:^(NSError * error) {
            context.error = error;
            [self listNotebooks_completePendingSharedNotebookWithContext:context];
        }];
    }
}

- (void)listNotebooks_completePendingSharedNotebookWithContext:(ENSessionListNotebooksContext *)context
{
    if (--context.pendingSharedNotebooks == 0) {
        [self listNotebooks_processSharedNotebooksWithContext:context];
    }
}

- (void)listNotebooks_processSharedNotebooksWithContext:(ENSessionListNotebooksContext *)context
{
    if (context.error) {
        // One of the calls failed. Currently we treat this as a hard error, and fail the entire call.
        [self listNotebooks_completeWithContext:context notebooks:nil error:context.error];
        return;
    }
    
    [self listNotebooks_prepareResultsWithContext:context];
}

- (void)listNotebooks_prepareResultsWithContext:(ENSessionListNotebooksContext *)context
{
    NSMutableArray * result = [NSMutableArray array];
    
    // Add all personal notebooks.
    NSString * defaultGuid = [self defaultNotebookGuid];
    for (EDAMNotebook * personalNotebook in context.personalNotebooks) {
        ENNotebook * notebook = [[ENNotebook alloc] initWithNotebook:personalNotebook];
        notebook.isApplicationDefaultNotebook = [defaultGuid isEqualToString:personalNotebook.guid];
        [result addObject:notebook];
    }
    
    // Add linked notebooks.
    for (EDAMLinkedNotebook * linkedNotebook in context.linkedNotebooks) {
        EDAMSharedNotebook * sharedNotebook = [context.sharedNotebooks objectForKey:linkedNotebook.guid];
        EDAMNotebook * businessNotebook = [context.businessNotebooks objectForKey:linkedNotebook.guid];
        if (sharedNotebook) {
            ENNotebook * notebook = [[ENNotebook alloc] initWithLinkedNotebook:linkedNotebook sharedNotebook:sharedNotebook businessNotebook:businessNotebook];
            [result addObject:notebook];
        }
    }
    
    // Sort them by name. This is just an convenience for the caller in case they don't bother to sort them themselves.
    [result sortUsingComparator:^NSComparisonResult(ENNotebook * obj1, ENNotebook * obj2) {
        return [obj1.name compare:obj2.name options:NSCaseInsensitiveSearch];
    }];
    
    [self listNotebooks_completeWithContext:context notebooks:result error:nil];
}

- (void)listNotebooks_completeWithContext:(ENSessionListNotebooksContext *)context
                                notebooks:(NSArray *)notebooks
                                    error:(NSError *)error
{
    context.completion(notebooks, error);
}

#pragma mark - uploadNote

- (void)uploadNote:(ENNote *)note
        completion:(ENSessionUploadNoteCompletionHandler)completion
{
    [self uploadNote:note policy:ENSessionUploadPolicyCreate replaceNote:nil progress:nil completion:completion];
}

- (void)uploadNote:(ENNote *)note
            policy:(ENSessionUploadPolicy)policy
       replaceNote:(ENNoteRef *)noteToReplace
          progress:(ENSessionUploadNoteProgressHandler)progress
        completion:(ENSessionUploadNoteCompletionHandler)completion
{
    if (!note) {
        [NSException raise:NSInvalidArgumentException format:@"note required"];
        return;
    }
    
    if (policy == ENSessionUploadPolicyCreate && noteToReplace) {
        [NSException raise:NSInvalidArgumentException format:@"can't use create policy when specifying an existing ID"];
        return;
    }
    if ((policy == ENSessionUploadPolicyReplace && !noteToReplace) ||
        (policy == ENSessionUploadPolicyReplaceOrCreate && !noteToReplace)) {
        [NSException raise:NSInvalidArgumentException format:@"must specify existing ID when requesting a replacement policy"];
        return;
    }
    
    if (note.notebook && !note.notebook.allowsWriting) {
        [NSException raise:NSInvalidArgumentException format:@"a specified notebook must not be readonly"];
        return;
    }
    
    if (!self.isAuthenticated) {
        completion(nil, [NSError errorWithDomain:EvernoteSDKErrorDomain code:EDAMErrorCode_INVALID_AUTH userInfo:nil]);
        return;
    }
    
    ENSessionUploadNoteContext * context = [[ENSessionUploadNoteContext alloc] init];
    context.note = [note EDAMNote];
    context.refToReplace = noteToReplace;
    context.policy = policy;
    context.completion = completion;
    context.defaultNotebookName = self.defaultNotebookName;

    // Track a whole new destination note store only for explicit, linked notebook destinations.
    if (note.notebook.linkedNotebook) {
        context.destinationNoteStore = [self noteStoreForLinkedNotebook:note.notebook.linkedNotebook];
    } else {
        context.destinationNoteStore = [self primaryNoteStore];
    }
    
    if (progress) {
//        [context.destinationNoteStore setUploadProgressBlock:^(NSUInteger bytesWritten, long long totalBytesWritten, long long totalBytesExpectedToWrite) {
//            if (totalBytesExpectedToWrite > 0) {
//                CGFloat t = totalBytesWritten / totalBytesExpectedToWrite;
//                progress(t);
//            }
//        }];
    }
    
    if (noteToReplace) {
        [self uploadNote_updateWithContext:context];
    } else {
        if (!context.note.notebookGuid) {
            // Caller has not specified an explicit notebook. Is there a default notebook set?
            if (self.defaultNotebookName) {
                context.destinedForDefaultNotebook = YES;
                // Check to see if we already know about a notebook GUID.
                NSString * notebookGuid = [self defaultNotebookGuid];
                if (notebookGuid) {
                    context.note.notebookGuid = notebookGuid;
                } else {
                    // We need to create/find the notebook that corresponds to this.
                    // Need to do a lookup.
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
    [self.primaryNoteStore listNotebooksWithSuccess:^(NSArray * notebooks) {
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
        [self uploadNote_completeWithContext:context resultingGuid:nil error:error];
    }];
}

- (void)uploadNote_createNotebookWithContext:(ENSessionUploadNoteContext *)context
{
    EDAMNotebook * notebook = [[EDAMNotebook alloc] init];
    notebook.name = context.defaultNotebookName;
    [self.primaryNoteStore createNotebook:notebook success:^(EDAMNotebook * resultNotebook) {
        [self setDefaultNotebookGuid:resultNotebook.guid];
        context.note.notebookGuid = resultNotebook.guid;
        [self uploadNote_createWithContext:context];
    } failure:^(NSError * error) {
        [self uploadNote_completeWithContext:context resultingGuid:nil error:error];
    }];
}

- (void)uploadNote_updateWithContext:(ENSessionUploadNoteContext *)context
{
    context.note.guid = context.refToReplace.guid;
    context.note.active = YES;
    [context.destinationNoteStore updateNote:context.note success:^(EDAMNote * resultNote) {
        [self uploadNote_completeWithContext:context resultingGuid:resultNote.guid error:nil];
    } failure:^(NSError *error) {
        if ([error.userInfo[@"parameter"] isEqualToString:@"Note.guid"]) {
            // We tried to replace a note that isn't there anymore. Now we look at the replacement policy.
            if (context.policy == ENSessionUploadPolicyReplaceOrCreate) {
                // Can't update it, just create it anew.
                context.note.guid = nil;
                context.policy = ENSessionUploadPolicyCreate;
                context.refToReplace = nil;
                [self uploadNote_createWithContext:context];
                return;
            }
        }
        [self uploadNote_completeWithContext:context resultingGuid:nil error:error];
    }];
}

- (void)uploadNote_createWithContext:(ENSessionUploadNoteContext *)context
{
    [context.destinationNoteStore createNote:context.note success:^(EDAMNote * resultNote) {
        [self uploadNote_completeWithContext:context resultingGuid:resultNote.guid error:nil];
    } failure:^(NSError * error) {
        if ([error.userInfo[@"parameter"] isEqualToString:@"Note.notebookGuid"] &&
            context.destinedForDefaultNotebook) {
            // We tried to get the default notebook but we failed to get it. Remove our cached guid and
            // try again.
            [self setDefaultNotebookGuid:nil];
            [self uploadNote_findDefaultNotebookWithContext:context];
            return;
        }
        [self uploadNote_completeWithContext:context resultingGuid:nil error:error];
    }];
}

- (void)uploadNote_completeWithContext:(ENSessionUploadNoteContext *)context
                         resultingGuid:(NSString *)guid
                                 error:(NSError *)error
{
//    [context.destinationNoteStore setUploadProgressBlock:nil];
    if (context.completion) {
        ENNoteRef * noteRef = [[ENNoteRef alloc] init];
        noteRef.guid = guid;
        context.completion(noteRef, error);
    }
}

#pragma mark - shareNote

- (void)shareNoteRef:(ENNoteRef *)noteRef
          completion:(ENSessionShareNoteCompletionHandler)completion
{
    // XXX: This only works for personal notes. To function against shared or business notebooks, we'd
    // need to have enough info to construct a note store object for the note.
    [self.primaryNoteStore shareNoteWithGuid:noteRef.guid success:^(NSString * noteKey) {
        NSString * shardId = self.user.shardId;
        NSString * shareUrl = [NSString stringWithFormat:@"http://%@/shard/%@/sh/%@/%@", [[EvernoteSession sharedSession] host], shardId, noteRef.guid, noteKey];
        if (completion) {
            completion(shareUrl, nil);
        }
    } failure:^(NSError * error) {
        if (completion) {
            completion(nil, error);
        }
    }];
}

#pragma mark - Private routines

- (ENNoteStoreClient *)primaryNoteStore
{
    if (!_primaryNoteStore) {
        ENCredentials * credentials = [self.credentialStore credentialsForHost:SessionHost];
        _primaryNoteStore = [ENNoteStoreClient noteStoreClientWithUrl:credentials.noteStoreUrl authenticationToken:credentials.authenticationToken];
        _primaryNoteStore.storeClientDelegate = self;
        _primaryNoteStore.noteStoreDelegate = self;
    }
    return _primaryNoteStore;
}

- (ENNoteStoreClient *)businessNoteStore
{
    //XXX Currently this is not lazily initialized, but constructed at normal auth time directly because we don't yet have user store stuff migrated.    
    if (!_businessNoteStore) {
//        EDAMAuthenticationResult * authResult = [self.userStoreClient authenticateToBusiness:self.primaryAuthenticationToken];
//        _businessNoteStore = [ENNoteStoreClient noteStoreClientWithUrl:authResult.noteStoreUrl authenticationToken:authResult.authenticationToken];
    }
    return _businessNoteStore;
}

- (ENNoteStoreClient *)noteStoreForLinkedNotebook:(EDAMLinkedNotebook *)linkedNotebook
{
    ENNoteStoreClientLinkedNotebookRef * linkedNotebookRef = [ENNoteStoreClientLinkedNotebookRef linkedNotebookRefFromLinkedNotebook:linkedNotebook];
    ENNoteStoreClient * linkedClient = [ENNoteStoreClient noteStoreClientForLinkedNotebookRef:linkedNotebookRef];
    linkedClient.storeClientDelegate = self;
    linkedClient.noteStoreDelegate = self;
    return linkedClient;
}

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
    NSMutableDictionary * prefs = [NSMutableDictionary dictionaryWithContentsOfFile:PreferencesPath()];
    if (!prefs) {
        prefs = [NSMutableDictionary dictionary];
    }
    if (obj) {
        [prefs setObject:obj forKey:key];
    } else {
        [prefs removeObjectForKey:key];
    }
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

#pragma - ENStoreClientDelegate

- (dispatch_queue_t)dispatchQueueForStoreClient:(ENStoreClient *)client
{
    return self.sharedQueue;
}

#pragma - ENNoteStoreClientDelegate

- (NSString *)authenticationTokenForLinkedNotebookRef:(ENNoteStoreClientLinkedNotebookRef *)linkedNotebookRef
{
    NSAssert(![NSThread isMainThread], @"Cannot authenticate to linked notebook on main thread");
    
    // See if we have auth data already for this notebook.
    EDAMAuthenticationResult * auth = [self.linkedAuthCache authenticationResultForLinkedNotebookGuid:linkedNotebookRef.guid];
    if (!auth) {
        // Create a temporary note store client for the linked note store, with our primary auth token,
        // in order to authenticate to the shared notebook.
        ENNoteStoreClient * linkedNoteStore = [ENNoteStoreClient noteStoreClientWithUrl:linkedNotebookRef.noteStoreUrl authenticationToken:self.primaryAuthenticationToken];
        linkedNoteStore.noteStoreDelegate = self;
        linkedNoteStore.storeClientDelegate = self;
        auth = [linkedNoteStore authenticateToSharedNotebookWithShareKey:linkedNotebookRef.shareKey];
        [self.linkedAuthCache setAuthenticationResult:auth forLinkedNotebookGuid:linkedNotebookRef.guid];
    }
    return auth.authenticationToken;
}

@end

#pragma mark - Private context definitions
                                                
@implementation ENSessionListNotebooksContext
@end

@implementation ENSessionUploadNoteContext
@end
