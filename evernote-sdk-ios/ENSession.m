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
#import "ENUserStoreClient.h"
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
@property (nonatomic, strong) ENNoteRef * refToReplace;
@property (nonatomic, strong) ENNotebook * notebook;
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
@property (nonatomic, strong) ENUserStoreClient * userStore;
@property (nonatomic, strong) ENNoteStoreClient * primaryNoteStore;
@property (nonatomic, strong) ENNoteStoreClient * businessNoteStore;
@property (nonatomic, strong) NSString * businessShardId;
@property (nonatomic, strong) ENAuthCache * linkedAuthCache;
@property (nonatomic, strong) dispatch_queue_t sharedQueue;
@end

@implementation ENSession

static NSString * SessionHost, * ConsumerKey, * ConsumerSecret;
static NSString * DeveloperToken, * NoteStoreUrl;

+ (void)setSharedSessionHost:(NSString *)host
                 consumerKey:(NSString *)key
              consumerSecret:(NSString *)secret
{
    SessionHost = host;
    ConsumerKey = key;
    ConsumerSecret = secret;
    
    DeveloperToken = nil;
    NoteStoreUrl = nil;
}

+ (void)setSharedSessionHost:(NSString *)host
              developerToken:(NSString *)token
                noteStoreUrl:(NSString *)url
{
    SessionHost = host;
    DeveloperToken = token;
    NoteStoreUrl = url;

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
    
    // If the developer token is set, then we can short circuit the entire auth flow and just call ourselves authenticated.
    if (DeveloperToken) {
        self.isAuthenticated = YES;
        self.primaryAuthenticationToken = DeveloperToken;
        [self performPostAuthenticationWithCompletion:completion];
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
            [self performPostAuthenticationWithCompletion:completion];
        }
    }];
}

- (void)performPostAuthenticationWithCompletion:(ENSessionAuthenticateCompletionHandler)completion
{
    [[self userStore] getUserWithSuccess:^(EDAMUser * user) {
        self.user = user;
        [[self userStore] authenticateToBusinessWithSuccess:^(EDAMAuthenticationResult *authenticationResult) {
            //XXXX: Don't do this here.
            self.businessShardId = authenticationResult.user.shardId;
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
        completion(nil, [NSError errorWithDomain:ENErrorDomain code:ENErrorCodeAuthExpired userInfo:nil]);
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
        completion(nil, [NSError errorWithDomain:ENErrorDomain code:ENErrorCodeAuthExpired userInfo:nil]);
        return;
    }
    
    ENSessionUploadNoteContext * context = [[ENSessionUploadNoteContext alloc] init];
    context.note = [note EDAMNote];
    context.refToReplace = noteToReplace;
    context.notebook = note.notebook;
    context.policy = policy;
    context.completion = completion;
    context.defaultNotebookName = self.defaultNotebookName;
    
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
        if (!context.notebook) {
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
        [self uploadNote_completeWithContext:context resultingNoteRef:nil error:error];
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
        [self uploadNote_completeWithContext:context resultingNoteRef:nil error:error];
    }];
}

- (void)uploadNote_updateWithContext:(ENSessionUploadNoteContext *)context
{
    context.note.guid = context.refToReplace.guid;
    context.note.active = YES;
    ENNoteStoreClient * noteStore = [self noteStoreForNoteRef:context.refToReplace];
    [noteStore updateNote:context.note success:^(EDAMNote * resultNote) {
        [self uploadNote_completeWithContext:context resultingNoteRef:context.refToReplace error:nil];
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
        [self uploadNote_completeWithContext:context resultingNoteRef:nil error:error];
    }];
}

- (void)uploadNote_createWithContext:(ENSessionUploadNoteContext *)context
{
    // Create a note store for wherever we're going to put this note. Also begin to construct the final note ref,
    // which will vary based on location of note.
    ENNoteStoreClient * noteStore = nil;
    ENNoteRef * finalNoteRef = [[ENNoteRef alloc] init];
    if (context.notebook.isBusinessNotebook) {
        noteStore = [self businessNoteStore];
        finalNoteRef.type = ENNoteRefTypeBusiness;
    } else if (context.notebook.isLinked) {
        noteStore = [self noteStoreForLinkedNotebook:context.notebook.linkedNotebook];
        finalNoteRef.type = ENNoteRefTypeShared;
        finalNoteRef.linkedNotebook = [ENLinkedNotebookRef linkedNotebookRefFromLinkedNotebook:context.notebook.linkedNotebook];
    } else {
        noteStore = [self primaryNoteStore];
        finalNoteRef.type = ENNoteRefTypePersonal;
    }
    
    [noteStore createNote:context.note success:^(EDAMNote * resultNote) {
        finalNoteRef.guid = resultNote.guid;
        [self uploadNote_completeWithContext:context resultingNoteRef:finalNoteRef error:nil];
    } failure:^(NSError * error) {
        if ([error.userInfo[@"parameter"] isEqualToString:@"Note.notebookGuid"] &&
            context.destinedForDefaultNotebook) {
            // We tried to get the default notebook but we failed to get it. Remove our cached guid and
            // try again.
            [self setDefaultNotebookGuid:nil];
            [self uploadNote_findDefaultNotebookWithContext:context];
            return;
        }
        [self uploadNote_completeWithContext:context resultingNoteRef:nil error:error];
    }];
}

- (void)uploadNote_completeWithContext:(ENSessionUploadNoteContext *)context
                      resultingNoteRef:(ENNoteRef *)noteRef
                                 error:(NSError *)error
{
//    [context.destinationNoteStore setUploadProgressBlock:nil];
    if (context.completion) {
        context.completion(noteRef, error);
    }
}

#pragma mark - shareNote

- (void)shareNoteRef:(ENNoteRef *)noteRef
          completion:(ENSessionShareNoteCompletionHandler)completion
{
    ENNoteStoreClient * noteStore = [self noteStoreForNoteRef:noteRef];
    [noteStore shareNoteWithGuid:noteRef.guid success:^(NSString * noteKey) {
        NSString * shardId = [self shardIdForNoteRef:noteRef];
        NSString * shareUrl = [NSString stringWithFormat:@"http://%@/shard/%@/sh/%@/%@", SessionHost, shardId, noteRef.guid, noteKey];
        if (completion) {
            completion(shareUrl, nil);
        }
    } failure:^(NSError * error) {
        if (completion) {
            completion(nil, error);
        }
    }];
}

#pragma mark - deleteNote

- (void)deleteNoteRef:(ENNoteRef *)noteRef
           completion:(ENSessionDeleteNoteCompletionHandler)completion
{
    ENNoteStoreClient * noteStore = [self noteStoreForNoteRef:noteRef];
    [noteStore deleteNoteWithGuid:noteRef.guid success:^(int32_t usn) {
        if (completion) {
            completion(nil);
        }
    } failure:^(NSError * error) {
        if (completion) {
            completion(error);;
        }
    }];
}

#pragma mark - Private routines

- (ENUserStoreClient *)userStore
{
    if (!_userStore) {
        _userStore = [ENUserStoreClient userStoreClientWithUrl:[[self class] userStoreUrl] authenticationToken:self.primaryAuthenticationToken];
        _userStore.storeClientDelegate = self;
    }
    return _userStore;
}

- (ENNoteStoreClient *)primaryNoteStore
{
    if (!_primaryNoteStore) {
        if (DeveloperToken) {
            _primaryNoteStore = [ENNoteStoreClient noteStoreClientWithUrl:NoteStoreUrl authenticationToken:DeveloperToken];
        } else {
            ENCredentials * credentials = [self.credentialStore credentialsForHost:SessionHost];
            _primaryNoteStore = [ENNoteStoreClient noteStoreClientWithUrl:credentials.noteStoreUrl authenticationToken:credentials.authenticationToken];
        }
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
    ENLinkedNotebookRef * linkedNotebookRef = [ENLinkedNotebookRef linkedNotebookRefFromLinkedNotebook:linkedNotebook];
    ENNoteStoreClient * linkedClient = [ENNoteStoreClient noteStoreClientForLinkedNotebookRef:linkedNotebookRef];
    linkedClient.storeClientDelegate = self;
    linkedClient.noteStoreDelegate = self;
    return linkedClient;
}

- (ENNoteStoreClient *)noteStoreForNoteRef:(ENNoteRef *)noteRef
{
    if (noteRef.type == ENNoteRefTypePersonal) {
        return [self primaryNoteStore];
    } else if (noteRef.type == ENNoteRefTypeBusiness) {
        return [self businessNoteStore];
    } else if (noteRef.type == ENNoteRefTypeShared) {
        ENNoteStoreClient * linkedClient = [ENNoteStoreClient noteStoreClientForLinkedNotebookRef:noteRef.linkedNotebook];
        linkedClient.storeClientDelegate = self;
        linkedClient.noteStoreDelegate = self;
        return linkedClient;
    }
    return nil;
}

- (NSString *)shardIdForNoteRef:(ENNoteRef *)noteRef
{
    if (noteRef.type == ENNoteRefTypePersonal) {
        return self.user.shardId;
    } else if (noteRef.type == ENNoteRefTypeBusiness) {
        return self.businessShardId;
    } else if (noteRef.type == ENNoteRefTypeShared) {
        return noteRef.linkedNotebook.shardId;
    }
    return nil;
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

+ (NSString *)userStoreUrl
{
    // If the host string includes an explict port (e.g., foo.bar.com:8080), use http. Otherwise https.
    
    // use a simple regex to check for a colon and port number suffix
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@".*:[0-9]+"
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:nil];
    NSUInteger numberOfMatches = [regex numberOfMatchesInString:SessionHost
                                                        options:0
                                                          range:NSMakeRange(0, [SessionHost length])];
    BOOL hasPort = (numberOfMatches > 0);
    NSString *scheme = (hasPort) ? @"http" : @"https";
    return [NSString stringWithFormat:@"%@://%@/edam/user", scheme, SessionHost];
}

#pragma - ENStoreClientDelegate

- (dispatch_queue_t)dispatchQueueForStoreClient:(ENStoreClient *)client
{
    return self.sharedQueue;
}

#pragma - ENNoteStoreClientDelegate

- (NSString *)authenticationTokenForLinkedNotebookRef:(ENLinkedNotebookRef *)linkedNotebookRef
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
