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
#import "ENLinkedNoteStoreClient.h"
#import "ENUserStoreClient.h"
#import "ENCredentialStore.h"

static NSString * ENSEssionPreferencesFilename = @"com.evernote.evernote-sdk-ios.plist";

static NSString * ENSessionDefaultNotebookGuid = @"ENSessionDefaultNotebookGuid";

@interface ENSessionDefaultLogger : NSObject <ENSDKLogging>
@end

@interface ENSessionListNotebooksContext : NSObject
@property (nonatomic, strong) NSMutableArray * resultNotebooks;
@property (nonatomic, strong) NSMutableArray * linkedPersonalNotebooks;
@property (nonatomic, strong) NSMutableDictionary * sharedBusinessNotebooks;
@property (nonatomic, strong) NSMutableDictionary * businessNotebooks;
@property (nonatomic, strong) NSMutableDictionary * sharedNotebooks;
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

@interface ENSession () <ENLinkedNoteStoreClientDelegate>
@property (nonatomic, assign) BOOL isAuthenticated;
@property (nonatomic, strong) EDAMUser * user;
@property (nonatomic, strong) ENCredentialStore * credentialStore;
@property (nonatomic, strong) NSString * primaryAuthenticationToken;
@property (nonatomic, strong) ENUserStoreClient * userStore;
@property (nonatomic, strong) ENNoteStoreClient * primaryNoteStore;
@property (nonatomic, strong) ENNoteStoreClient * businessNoteStore;
@property (nonatomic, strong) NSString * businessShardId;
@property (nonatomic, strong) ENAuthCache * linkedAuthCache;
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
        self.logger = [[ENSessionDefaultLogger alloc] init];
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
        // If we know this user is a business user, authenticate to their business store as well.
        // XXX We should keep business credentials in the credential store and use them as
        // appropriate. Currently we'll do the roundtrip every time.
        if (user.accounting.businessId != 0) {
            [[self userStore] authenticateToBusinessWithSuccess:^(EDAMAuthenticationResult *authenticationResult) {
                self.businessShardId = authenticationResult.user.shardId;
                self.businessNoteStore = [ENNoteStoreClient noteStoreClientWithUrl:authenticationResult.noteStoreUrl authenticationToken:authenticationResult.authenticationToken];
                completion(nil);
            } failure:^(NSError * authenticateToBusinessError) {
                ENSDKLogError(@"Failed to authenticate to business for business user: %@", authenticateToBusinessError);
                completion(nil);
            }];
        } else {
            // Not a business user. OK.
            completion(nil);
        }
    } failure:^(NSError * getUserError) {
        ENSDKLogError(@"Failed to get user info for user: %@", getUserError);
        completion(nil);
    }];
}

- (BOOL)isIsPremiumUser
{
    return self.user.privilege >= PrivilegeLevel_PREMIUM;
}

- (BOOL)isBusinessUser
{
    return self.user.accounting.businessIdIsSet;
}

- (NSString *)userDisplayName
{
    return self.user.name ?: self.user.username;
}

- (NSString *)businessDisplayName
{
    if ([self isBusinessUser]) {
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

// Notes on the flow of this process, because it's somewhat byzantine:
// 1. Get all of the user's personal notebooks.
// 2. Get all of the user's linked notebooks. These will include business and/or shared notebooks.
// 3. If the user is a business user:
//   a. Get the business's shared notebooks. Some of these may match to personal linked notebooks.
//   b. Get the business's linked notebooks. Some of these will match to shared notebooks in (a), providing a
//      complete authorization story for the notebook.
// 4. For any remaining linked nonbusiness notebooks, auth to each and get authorization information.
// 5. Sort and return the full result set.
//
// For personal users, therefore, this will make 2 + n roundtrips, where n is the number of shared notebooks.
// For business users, this will make 2 + 2 + n roundtrips, where n is the number of nonbusiness shared notebooks.

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
    context.resultNotebooks = [[NSMutableArray alloc] init];
    [self listNotebooks_listNotebooksWithContext:context];
}

- (void)listNotebooks_listNotebooksWithContext:(ENSessionListNotebooksContext *)context
{
    [self.primaryNoteStore listNotebooksWithSuccess:^(NSArray * notebooks) {
        // Populate the result list with personal notebooks.
        for (EDAMNotebook * notebook in notebooks) {
            ENNotebook * result = [[ENNotebook alloc] initWithNotebook:notebook];
            [context.resultNotebooks addObject:result];
        }
        // Now get any linked notebooks.
        [self listNotebooks_listLinkedNotebooksWithContext:context];
    } failure:^(NSError * error) {
        ENSDKLogError(@"Error from listNotebooks in user's store: %@", error);
        [self listNotebooks_completeWithContext:context error:error];
    }];
}

- (void)listNotebooks_listLinkedNotebooksWithContext:(ENSessionListNotebooksContext *)context
{
    [self.primaryNoteStore listLinkedNotebooksWithSuccess:^(NSArray *linkedNotebooks) {
        if (linkedNotebooks.count == 0) {
            [self listNotebooks_prepareResultsWithContext:context];
        } else {
            context.linkedPersonalNotebooks = [NSMutableArray arrayWithArray:linkedNotebooks];
            if ([self businessNoteStore]) {
                [self listNotebooks_fetchSharedBusinessNotebooksWithContext:context];
            } else {
                [self listNotebooks_fetchSharedNotebooksWithContext:context];
            }
        }
    } failure:^(NSError *error) {
        ENSDKLogError(@"Error from listLinkedNotebooks in user's store: %@", error);
        [self listNotebooks_completeWithContext:context error:error];
    }];
}

- (void)listNotebooks_fetchSharedBusinessNotebooksWithContext:(ENSessionListNotebooksContext *)context
{
    [self.businessNoteStore listSharedNotebooksWithSuccess:^(NSArray *sharedNotebooks) {
        // Run through the results, and set each notebook keyed by its shareKey, which
        // is how we'll find corresponding linked notebooks.
        context.sharedBusinessNotebooks = [[NSMutableDictionary alloc] init];
        for (EDAMSharedNotebook * notebook in sharedNotebooks) {
            [context.sharedBusinessNotebooks setObject:notebook forKey:notebook.shareKey];
        }
        
        // Now continue on to grab all of the linked notebooks for the business.
        [self listNotebooks_fetchLinkedBusinessNotebooksWithContext:context];
    } failure:^(NSError *error) {
        ENSDKLogError(@"Error from listSharedNotebooks in business store: %@", error);
        [self listNotebooks_completeWithContext:context error:error];
    }];
}

- (void)listNotebooks_fetchLinkedBusinessNotebooksWithContext:(ENSessionListNotebooksContext *)context
{
    [self.businessNoteStore listNotebooksWithSuccess:^(NSArray *notebooks) {
        // Run through the results, and set each notebook keyed by its guid, which
        // is how we'll find it from the shared notebook.
        context.businessNotebooks = [[NSMutableDictionary alloc] init];
        for (EDAMNotebook * notebook in notebooks) {
            [context.businessNotebooks setObject:notebook forKey:notebook.guid];
        }
        [self listNotebooks_processBusinessNotebooksWithContext:context];
    } failure:^(NSError *error) {
        ENSDKLogError(@"Error from listNotebooks in business store: %@", error);
        [self listNotebooks_completeWithContext:context error:error];
    }];
}

- (void)listNotebooks_processBusinessNotebooksWithContext:(ENSessionListNotebooksContext *)context
{
    // Postprocess our notebook sets for business notebooks. For every linked notebook in the personal
    // account, check for a corresponding business shared notebook (by shareKey). If we find it, also
    // grab its corresponding notebook object from the business notebook list.
    for (EDAMLinkedNotebook * linkedNotebook in [context.linkedPersonalNotebooks copy]) {
        EDAMSharedNotebook * sharedNotebook = [context.sharedBusinessNotebooks objectForKey:linkedNotebook.shareKey];
        if (sharedNotebook) {
            // This linked notebook corresponds to a business notebook.
            EDAMNotebook * businessNotebook = [context.businessNotebooks objectForKey:sharedNotebook.notebookGuid];
            ENNotebook * result = [[ENNotebook alloc] initWithSharedNotebook:sharedNotebook forLinkedNotebook:linkedNotebook withBusinessNotebook:businessNotebook];
            [context.resultNotebooks addObject:result];
            [context.linkedPersonalNotebooks removeObjectIdenticalTo:linkedNotebook]; // OK since we're enumerating a copy.
        }
    }
    
    // Any remaining linked notebooks are personal shared notebooks. No shared notebooks?
    // Then go directly to results preparation.
    if (context.linkedPersonalNotebooks.count == 0) {
        [self listNotebooks_prepareResultsWithContext:context];
    } else {
        [self listNotebooks_fetchSharedNotebooksWithContext:context];
    }
}

- (void)listNotebooks_fetchSharedNotebooksWithContext:(ENSessionListNotebooksContext *)context
{
    // Fetch shared notebooks for any non-business linked notebooks remaining in the
    // array in the context. We will have already pulled out the linked notebooks that
    // were processed for business.
    context.pendingSharedNotebooks = context.linkedPersonalNotebooks.count;
    NSMutableDictionary * sharedNotebooks = [[NSMutableDictionary alloc] init];
    context.sharedNotebooks = sharedNotebooks;
    
    for (EDAMLinkedNotebook * linkedNotebook in context.linkedPersonalNotebooks) {
        ENNoteStoreClient * noteStore = [self noteStoreForLinkedNotebook:linkedNotebook];
        [noteStore getSharedNotebookByAuthWithSuccess:^(EDAMSharedNotebook * sharedNotebook) {
            // Add the shared notebook to the map.
            [sharedNotebooks setObject:sharedNotebook forKey:linkedNotebook.guid];
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
        ENSDKLogError(@"Error from getSharedNotebookByAuth against a personal linked notebook: %@", context.error);
        [self listNotebooks_completeWithContext:context error:context.error];
        return;
    }
    
    // Process the results
    for (EDAMLinkedNotebook * linkedNotebook in context.linkedPersonalNotebooks) {
        EDAMSharedNotebook * sharedNotebook = [context.sharedNotebooks objectForKey:linkedNotebook.guid];
        ENNotebook * result = [[ENNotebook alloc] initWithSharedNotebook:sharedNotebook forLinkedNotebook:linkedNotebook];
        [context.resultNotebooks addObject:result];
    }
    
    [self listNotebooks_prepareResultsWithContext:context];
}

- (void)listNotebooks_prepareResultsWithContext:(ENSessionListNotebooksContext *)context
{
    // Mark the application's default notebook.
    NSString * defaultGuid = [self defaultNotebookGuid];
    for (ENNotebook * notebook in context.resultNotebooks) {
        notebook.isApplicationDefaultNotebook = [defaultGuid isEqualToString:notebook.guid];
    }
    
    // Sort them by name. This is just an convenience for the caller in case they don't bother to sort them themselves.
    [context.resultNotebooks sortUsingComparator:^NSComparisonResult(ENNotebook * obj1, ENNotebook * obj2) {
        return [obj1.name compare:obj2.name options:NSCaseInsensitiveSearch];
    }];
    
    [self listNotebooks_completeWithContext:context error:nil];
}

- (void)listNotebooks_completeWithContext:(ENSessionListNotebooksContext *)context
                                    error:(NSError *)error
{
    context.completion(context.resultNotebooks, error);
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
    
    // Run size validation on any resources included with the note. This is done at upload time because
    // the sizes are a function of the user's service level, which can change.
    if (![note validateForLimits]) {
        ENSDKLogError(@"Note failed limits validation. Cannot upload. %@", self);
        completion(nil, [NSError errorWithDomain:ENErrorDomain code:ENErrorCodeLimitReached userInfo:nil]);
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
        ENSDKLogError(@"Failed to listNotebooks for uploadNote: %@", error);
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
        ENSDKLogError(@"Failed to createNotebook for uploadNote: %@", error);
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
        ENSDKLogError(@"Failed to updateNote for uploadNote: %@", error);
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
        ENSDKLogError(@"Failed to createNote for uploadNote: %@", error);
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
        ENSDKLogError(@"Failed to shareNote: %@", error);
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
        ENSDKLogError(@"Failed to deleteNote: %@", error);
        if (completion) {
            completion(error);;
        }
    }];
}

#pragma mark - Private routines

- (ENAuthCache *)linkedAuthCache
{
    if (!_linkedAuthCache) {
        _linkedAuthCache = [[ENAuthCache alloc] init];
    }
    return _linkedAuthCache;
}

- (ENUserStoreClient *)userStore
{
    if (!_userStore) {
        _userStore = [ENUserStoreClient userStoreClientWithUrl:[[self class] userStoreUrl] authenticationToken:self.primaryAuthenticationToken];
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
    }
    return _primaryNoteStore;
}

- (ENNoteStoreClient *)noteStoreForLinkedNotebook:(EDAMLinkedNotebook *)linkedNotebook
{
    ENLinkedNotebookRef * linkedNotebookRef = [ENLinkedNotebookRef linkedNotebookRefFromLinkedNotebook:linkedNotebook];
    ENLinkedNoteStoreClient * linkedClient = [ENLinkedNoteStoreClient noteStoreClientForLinkedNotebookRef:linkedNotebookRef];
    linkedClient.delegate = self;
    return linkedClient;
}

- (ENNoteStoreClient *)noteStoreForNoteRef:(ENNoteRef *)noteRef
{
    if (noteRef.type == ENNoteRefTypePersonal) {
        return [self primaryNoteStore];
    } else if (noteRef.type == ENNoteRefTypeBusiness) {
        return [self businessNoteStore];
    } else if (noteRef.type == ENNoteRefTypeShared) {
        ENLinkedNoteStoreClient * linkedClient = [ENLinkedNoteStoreClient noteStoreClientForLinkedNotebookRef:noteRef.linkedNotebook];
        linkedClient.delegate = self;
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
    // Use a simple regex to check for a colon and port number suffix.
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

#pragma mark - ENLinkedNoteStoreClientDelegate

- (NSString *)authenticationTokenForLinkedNotebookRef:(ENLinkedNotebookRef *)linkedNotebookRef
{
    NSAssert(![NSThread isMainThread], @"Cannot authenticate to linked notebook on main thread");
    
    // See if we have auth data already for this notebook.
    EDAMAuthenticationResult * auth = [self.linkedAuthCache authenticationResultForLinkedNotebookGuid:linkedNotebookRef.guid];
    if (!auth) {
        // Create a temporary note store client for the linked note store, with our primary auth token,
        // in order to authenticate to the shared notebook.
        ENNoteStoreClient * linkedNoteStore = [ENNoteStoreClient noteStoreClientWithUrl:linkedNotebookRef.noteStoreUrl authenticationToken:self.primaryAuthenticationToken];
        auth = [linkedNoteStore authenticateToSharedNotebookWithShareKey:linkedNotebookRef.shareKey];
        [self.linkedAuthCache setAuthenticationResult:auth forLinkedNotebookGuid:linkedNotebookRef.guid];
    }
    return auth.authenticationToken;
}

@end

#pragma mark - Default logger

@implementation ENSessionDefaultLogger
- (void)logInfoString:(NSString *)str
{
    NSLog(@"ENSDK: %@", str);
}

- (void)logErrorString:(NSString *)str
{
    NSLog(@"ENSDK ERROR: %@", str);
}
@end


#pragma mark - Private context definitions
                                                
@implementation ENSessionListNotebooksContext
@end

@implementation ENSessionUploadNoteContext
@end
