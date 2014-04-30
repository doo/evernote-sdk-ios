//
//  ENSession.m
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 2/25/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import "ENSDKPrivate.h"
#import "ENSDKAdvanced.h"
#import "ENAuthCache.h"
#import "ENNoteStoreClient.h"
#import "ENLinkedNoteStoreClient.h"
#import "ENBusinessNoteStoreClient.h"
#import "ENUserStoreClient.h"
#import "ENCredentialStore.h"
#import "ENOAuthAuthenticator.h"
#import "ENPreferencesStore.h"

// Strings visible publicly.
NSString * const ENSessionHostSandbox = @"sandbox.evernote.com";

// Constants valid only in this file.
static NSString * ENSessionBootstrapServerBaseURLStringCN  = @"app.yinxiang.com";
static NSString * ENSessionBootstrapServerBaseURLStringUS  = @"www.evernote.com";

static NSString * ENSessionPreferencesFilename = @"com.evernote.evernote-sdk-ios.plist";
static NSString * ENSessionPreferencesCredentialStore = @"CredentialStore";
static NSString * ENSessionPreferencesCurrentProfileName = @"CurrentProfileName";
static NSString * ENSessionPreferencesUser = @"User";
static NSString * ENSessionPreferencesAppNotebookIsLinked = @"AppNotebookIsLinked";
static NSString * ENSessionPreferencesLinkedAppNotebook = @"LinkedAppNotebook";

static NSUInteger ENSessionNotebooksCacheValidity = (5 * 60);   // 5 minutes

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
@property (nonatomic, strong) ENSessionUploadNoteCompletionHandler completion;
@property (nonatomic, strong) ENNoteStoreClient * noteStore;
@property (nonatomic, strong) ENNoteRef * noteRef;
@end

@interface ENSession () <ENLinkedNoteStoreClientDelegate, ENBusinessNoteStoreClientDelegate, ENOAuthAuthenticatorDelegate>
@property (nonatomic, assign) BOOL supportsLinkedAppNotebook;
@property (nonatomic, strong) ENOAuthAuthenticator * authenticator;
@property (nonatomic, strong) ENSessionAuthenticateCompletionHandler authenticationCompletion;

@property (nonatomic, copy) NSString * sessionHost;
@property (nonatomic, assign) BOOL isAuthenticated;
@property (nonatomic, strong) EDAMUser * user;
@property (nonatomic, strong) ENPreferencesStore * preferences;
@property (nonatomic, strong) NSString * primaryAuthenticationToken;
@property (nonatomic, strong) ENUserStoreClient * userStore;
@property (nonatomic, strong) ENNoteStoreClient * primaryNoteStore;
@property (nonatomic, strong) ENNoteStoreClient * businessNoteStore;
@property (nonatomic, strong) NSString * businessShardId;
@property (nonatomic, strong) ENAuthCache * authCache;
@property (nonatomic, strong) NSArray * notebooksCache;
@property (nonatomic, strong) NSDate * notebooksCacheDate;
@end

@implementation ENSession

static NSString * SessionHostOverride;
static NSString * ConsumerKey, * ConsumerSecret;
static NSString * DeveloperToken, * NoteStoreUrl;

+ (void)setSharedSessionConsumerKey:(NSString *)key
                     consumerSecret:(NSString *)secret
                       optionalHost:(NSString *)host
{
    ConsumerKey = key;
    ConsumerSecret = secret;
    SessionHostOverride = host;
    
    DeveloperToken = nil;
    NoteStoreUrl = nil;
}

+ (void)setSharedSessionDeveloperToken:(NSString *)token
                          noteStoreUrl:(NSString *)url
{
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

+ (BOOL)checkSharedSessionSettings
{
    if (DeveloperToken && NoteStoreUrl) {
        return YES;
    }
    
    if (ConsumerKey && ![ConsumerKey isEqualToString:@"your key"] &&
        ConsumerSecret && ![ConsumerSecret isEqualToString:@"your secret"]) {
        return YES;
    }
    
    NSString * error = @"Cannot create shared Evernote session without either a valid consumer key/secret pair, or a developer token set";
    // Use NSLog and not the session logger here, or we'll deadlock since we're still creating the session.
    NSLog(@"%@", error);
    [NSException raise:NSInvalidArgumentException format:@"%@", error];
    return NO;
}

- (id)init
{
    self = [super init];
    if (self) {
        // Check to see if the app's setup parameters are set and look reasonable.
        // If this test fails, we'll essentially set a singleton to nil and never be able
        // to fix it, which is the desired development-time behavior.
        if (![[self class] checkSharedSessionSettings]) {
            return nil;
        }
        // Default to supporting linked notebooks for app notebook. Developer can toggle this off
        // if they're using advanced features and don't want to deal with the added complexity.
        self.supportsLinkedAppNotebook = YES;
        [self startup];
    }
    return self;
}

- (void)startup
{
    self.logger = [[ENSessionDefaultLogger alloc] init];
    self.preferences = [[ENPreferencesStore alloc] initWithStoreFilename:ENSessionPreferencesFilename];

    // Determine the host to use for this session.
    if (SessionHostOverride.length > 0) {
        // Use the override given by the developer. This is optional, and
        // generally used for the sandbox.
        self.sessionHost = SessionHostOverride;
    } else if (NoteStoreUrl) {
        // If we have a developer key, just get the host from the note store url.
        NSURL * noteStoreUrl = [NSURL URLWithString:NoteStoreUrl];
        self.sessionHost = noteStoreUrl.host;
    } else if ([[self currentProfileName] isEqualToString:ENBootstrapProfileNameInternational]) {
        self.sessionHost = ENSessionBootstrapServerBaseURLStringUS;
    } else if ([[self currentProfileName] isEqualToString:ENBootstrapProfileNameChina]) {
        self.sessionHost = ENSessionBootstrapServerBaseURLStringCN;
    } else {
        // Choose the initial host based on locale.
        NSString * locale = [[NSLocale currentLocale] localeIdentifier];
        if ([[locale lowercaseString] hasPrefix:@"zh"]) {
            self.sessionHost = ENSessionBootstrapServerBaseURLStringCN;
        } else {
            self.sessionHost = ENSessionBootstrapServerBaseURLStringUS;
        }
    }
    
    // If the developer token is set, then we can short circuit the entire auth flow and just call ourselves authenticated.
    if (DeveloperToken) {
        self.isAuthenticated = YES;
        self.primaryAuthenticationToken = DeveloperToken;
        [self performPostAuthentication];
        return;
    }
    
    // We'll restore an existing session if there was one. Check to see if we have valid
    // primary credentials stashed away already.
    ENCredentials * credentials = [self credentialsForHost:self.sessionHost];
    if (!credentials || ![credentials areValid]) {
        self.isAuthenticated = NO;
        [self.preferences removeAllItems];
        return;
    }
    
    self.isAuthenticated = YES;
    self.primaryAuthenticationToken = credentials.authenticationToken;
    
    // We appear to have valid personal credentials, so populate the user object from cache,
    // and pull up business credentials. Refresh the business credentials if necessary, and the user
    // object always.
    self.user = [self.preferences decodedObjectForKey:ENSessionPreferencesUser];
    [self performPostAuthentication];
}

- (void)authenticateWithViewController:(UIViewController *)viewController
                            completion:(ENSessionAuthenticateCompletionHandler)completion
{
    if (!completion) {
        [NSException raise:NSInvalidArgumentException format:@"handler required"];
        return;
    }
    
    // Authenticate is idempotent; check if we're already authenticated
    if (self.isAuthenticated) {
        completion(nil);
        return;
    }

    // What if we're already mid-authenticating? If we have an authenticator object already, then
    // don't stomp on it.
    if (self.authenticator) {
        ENSDKLogInfo(@"Cannot restart authentication while it is still in progress.");
        completion([NSError errorWithDomain:ENErrorDomain code:ENErrorCodeUnknown userInfo:nil]);
    }

    self.user = nil;
    self.authenticationCompletion = completion;
    
    // If the developer token is set, then we can short circuit the entire auth flow and just call ourselves authenticated.
    if (DeveloperToken) {
        self.isAuthenticated = YES;
        self.primaryAuthenticationToken = DeveloperToken;
        [self performPostAuthentication];
        return;
    }
    
    self.authenticator = [[ENOAuthAuthenticator alloc] init];
    self.authenticator.delegate = self;
    self.authenticator.consumerKey = ConsumerKey;
    self.authenticator.consumerSecret = ConsumerSecret;
    self.authenticator.host = self.sessionHost;
    self.authenticator.supportsLinkedAppNotebook = self.supportsLinkedAppNotebook;
    [self.authenticator authenticateWithViewController:viewController];
}

- (void)performPostAuthentication
{
    // During an initial authentication, a failure in getUser or authenticateToBusiness is considered fatal.
    // But when refreshing a session, eg on app restart, we don't want to sign out users just for network
    // errors, or transient problems.
    BOOL failuresAreFatal = (self.authenticationCompletion != nil);
    
    [[self userStore] getUserWithSuccess:^(EDAMUser * user) {
        self.user = user;
        [self.preferences encodeObject:user forKey:ENSessionPreferencesUser];
        [self completeAuthenticationWithError:nil];
    } failure:^(NSError * getUserError) {
        ENSDKLogError(@"Failed to get user info for user: %@", getUserError);
        [self completeAuthenticationWithError:(failuresAreFatal ? getUserError : nil)];
    }];
}

- (void)completeAuthenticationWithError:(NSError *)error
{
    if (error) {
        [self unauthenticate];
    }
    if (self.authenticationCompletion) {
        self.authenticationCompletion(error);
        self.authenticationCompletion = nil;
    }
    self.authenticator = nil;
}

- (BOOL)isAuthenticationInProgress
{
    return self.authenticator != nil;
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
    NSString * name = self.user.name ?: self.user.username;
    return name ?: @"";
}

- (NSString *)businessDisplayName
{
    if ([self isBusinessUser]) {
        return self.user.accounting.businessName;
    }
    return nil;
}

- (BOOL)appNotebookIsLinked
{
    return [[self.preferences objectForKey:ENSessionPreferencesAppNotebookIsLinked] boolValue];
}

- (void)unauthenticate
{
    self.isAuthenticated = NO;
    self.user = nil;
    self.primaryAuthenticationToken = nil;
    self.userStore = nil;
    self.primaryNoteStore = nil;
    self.businessNoteStore = nil;
    self.authCache = [[ENAuthCache alloc] init];
    
    // Manually clear credentials. This ensures they're removed from the keychain also.
    ENCredentialStore * credentialStore = [self credentialStore];
    [credentialStore clearAllCredentials];
    [self saveCredentialStore:credentialStore];
    
    [self.preferences removeAllItems];
}

- (BOOL)handleOpenURL:(NSURL *)url
{
    if (self.authenticator) {
        return [self.authenticator canHandleOpenURL:url];
    }
    return NO;
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
    
    // Do we have a cached result that is unexpired?
    if (self.notebooksCache && ([self.notebooksCacheDate timeIntervalSinceNow] * -1.0) < ENSessionNotebooksCacheValidity) {
        completion(self.notebooksCache, nil);
        return;
    }
    
    self.notebooksCache = nil;
    self.notebooksCacheDate = nil;
    
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
        if ([self isErrorDueToRestrictedAuth:error]) {
            // App has a single notebook auth token, so try getting linked notebooks.
            [self listNotebooks_listLinkedNotebooksWithContext:context];
            return;
        }
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
        if ([self isErrorDueToRestrictedAuth:error]) {
            // App has a single notebook auth token, so skip to the end.
            [self listNotebooks_prepareResultsWithContext:context];
            return;
        }
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
    // If there's only one notebook, and it's not flagged as the default notebook for the account, then
    // we must be in a single-notebook auth scenario. In this case, simply override the flag so to a caller it
    // will appear to be the default anyway. Note that we only do this if it's not already the default. If a single
    // notebook result is already marked default, then it *could* be that there really is one notebook, and we don't
    // want to have the caller persist an override flag that might be inapplicable later.
    if (context.resultNotebooks.count == 1) {
        ENNotebook * soleNotebook = context.resultNotebooks[0];
        if (!soleNotebook.isDefaultNotebook) {
            soleNotebook.isDefaultNotebookOverride = YES;
        }
    }
    
    // Sort them by name. This is just a convenience for the caller in case they don't bother to sort them themselves.
    [context.resultNotebooks sortUsingComparator:^NSComparisonResult(ENNotebook * obj1, ENNotebook * obj2) {
        return [obj1.name compare:obj2.name options:NSCaseInsensitiveSearch];
    }];
    
    [self listNotebooks_completeWithContext:context error:nil];
}

- (void)listNotebooks_completeWithContext:(ENSessionListNotebooksContext *)context
                                    error:(NSError *)error
{
    self.notebooksCache = context.resultNotebooks;
    self.notebooksCacheDate = [NSDate date];
    
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
        [self uploadNote_determineDestinationWithContext:context];
    }
}

- (void)uploadNote_updateWithContext:(ENSessionUploadNoteContext *)context
{
    context.note.guid = context.refToReplace.guid;
    context.note.active = YES;
    if (context.note.notebookGuidIsSet) {
        // Allowing arbitrary update of notebook that the note is in would require a ton of logic that would require deleting and re-creating
        // if it moves across shard (share/business) boundaries. We punt on that whole problem here by simply disallowing notebook change
        // as part of an update flow.
        ENSDKLogInfo(@"Cannot replace a note and change its notebook; location will be preserved.");
        context.note.notebookGuid = nil;
    }
    ENNoteStoreClient * noteStore = [self noteStoreForNoteRef:context.refToReplace];
    [noteStore updateNote:context.note success:^(EDAMNote * resultNote) {
        [self uploadNote_completeWithContext:context error:nil];
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
        [self uploadNote_completeWithContext:context error:error];
    }];
}

- (void)uploadNote_determineDestinationWithContext:(ENSessionUploadNoteContext *)context
{
    // Begin prepping a resulting note ref.
    context.noteRef = [[ENNoteRef alloc] init];
    
    // If the destination is not specified, and this app uses app notebook, we are responsible for
    // choosing the right note store (personal or linked). We default to personal, but if we know the
    // user chose a linked notebook, then we'll need to use its shard info to talk to it.
    if (!context.notebook) {
        if ([self appNotebookIsLinked]) {
            // Do we have a cached linked notebook record to use as a destination?
            EDAMLinkedNotebook * linkedNotebook = [self.preferences decodedObjectForKey:ENSessionPreferencesLinkedAppNotebook];
            if (linkedNotebook) {
                context.noteStore = [self noteStoreForLinkedNotebook:linkedNotebook];
                context.noteRef.type = ENNoteRefTypeShared;
                context.noteRef.linkedNotebook = [ENLinkedNotebookRef linkedNotebookRefFromLinkedNotebook:linkedNotebook];
            } else {
                // We don't have a linked notebook record to use. We need to go find one.
                [self uploadNote_findLinkedAppNotebookWithContext:context];
                return;
            }
        } else {
            // Either the app doesn't use app notebook, or it does and the single notebook is a personal one.
            // (We'll fall into the catch-all else case below and end up on the personal note store.)
        }
    }
    
    if (!context.noteStore) {
        if (context.notebook.isBusinessNotebook) {
            context.noteStore = [self businessNoteStore];
            context.noteRef.type = ENNoteRefTypeBusiness;
        } else if (context.notebook.isLinked) {
            context.noteStore = [self noteStoreForLinkedNotebook:context.notebook.linkedNotebook];
            context.noteRef.type = ENNoteRefTypeShared;
            context.noteRef.linkedNotebook = [ENLinkedNotebookRef linkedNotebookRefFromLinkedNotebook:context.notebook.linkedNotebook];
        } else {
            // This is the normal case. Either the app has not specified a destination notebook, or the
            // notebook is personal.
            context.noteStore = [self primaryNoteStore];
            context.noteRef.type = ENNoteRefTypePersonal;
        }
    }
    
    [self uploadNote_createWithContext:context];
}

- (void)uploadNote_findLinkedAppNotebookWithContext:(ENSessionUploadNoteContext *)context
{
    // We know the app notebook is linked. List linked notebooks; we expect to find a single result.
    [self.primaryNoteStore listLinkedNotebooksWithSuccess:^(NSArray * linkedNotebooks) {
        if (linkedNotebooks.count < 1) {
            ENSDKLogInfo(@"Cannot find linked app notebook. Perhaps user deleted it?");
            // Uh-oh; there's no destination to use. We have to fail the request.
            NSError * error = [NSError errorWithDomain:ENErrorDomain code:ENErrorCodeNotFound userInfo:nil];
            [self uploadNote_completeWithContext:context error:error];
            return;
        }
        if (linkedNotebooks.count > 1) {
            ENSDKLogInfo(@"Expected to find single linked notebook, found %lu", (unsigned long)linkedNotebooks.count);
        }
        // Take this notebook, and cache it.
        EDAMLinkedNotebook * linkedNotebook = linkedNotebooks[0];
        [self.preferences encodeObject:linkedNotebook forKey:ENSessionPreferencesLinkedAppNotebook];
        
        // Go back and redetermine the destination.
        [self uploadNote_determineDestinationWithContext:context];
    } failure:^(NSError * error) {
        ENSDKLogInfo(@"Failed to listLinkedNotebooks for uploadNote; turning into NotFound: %@", error);
        // Uh-oh; there's no destination to use. We have to fail the request.
        error = [NSError errorWithDomain:ENErrorDomain code:ENErrorCodeNotFound userInfo:nil];
        [self uploadNote_completeWithContext:context error:error];
    }];
}

- (void)uploadNote_createWithContext:(ENSessionUploadNoteContext *)context
{
    [context.noteStore createNote:context.note success:^(EDAMNote * resultNote) {
        context.noteRef.guid = resultNote.guid;
        [self uploadNote_completeWithContext:context error:nil];
    } failure:^(NSError * error) {
        context.noteRef = nil;
        ENSDKLogError(@"Failed to createNote for uploadNote: %@", error);
        [self uploadNote_completeWithContext:context error:error];
    }];
}

- (void)uploadNote_completeWithContext:(ENSessionUploadNoteContext *)context
                                 error:(NSError *)error
{
//    [context.destinationNoteStore setUploadProgressBlock:nil];
    if (context.completion) {
        context.completion(error ? nil : context.noteRef, error);
    }
}

#pragma mark - shareNote

- (void)shareNoteRef:(ENNoteRef *)noteRef
          completion:(ENSessionShareNoteCompletionHandler)completion
{
    ENNoteStoreClient * noteStore = [self noteStoreForNoteRef:noteRef];
    [noteStore shareNoteWithGuid:noteRef.guid success:^(NSString * noteKey) {
        NSString * shardId = [self shardIdForNoteRef:noteRef];
        NSString * shareUrl = [NSString stringWithFormat:@"http://%@/shard/%@/sh/%@/%@", self.sessionHost, shardId, noteRef.guid, noteKey];
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

#pragma mark - API helpers

- (BOOL)isErrorDueToRestrictedAuth:(NSError *)error
{
    int edamError = [error.userInfo[@"EDAMErrorCode"] intValue];
    NSString * parameter = error.userInfo[@"parameter"];
    if (edamError == EDAMErrorCode_PERMISSION_DENIED && [parameter isEqualToString:@"authenticationToken"]) {
        return YES;
    }
    return NO;
}

#pragma mark - Credential Store

- (ENCredentialStore *)credentialStore
{
    ENCredentialStore * store = [self.preferences decodedObjectForKey:ENSessionPreferencesCredentialStore];
    if (!store) {
        // Try loading from the previous location in app'd defaults.
        store = [ENCredentialStore loadCredentialsFromAppDefaults];
        if (store) {
            // Oh, we found it there? OK, put it into our own prefs vault immediately.
            [self.preferences encodeObject:store forKey:ENSessionPreferencesCredentialStore];
        }
    }
    if (!store) {
        store = [[ENCredentialStore alloc] init];
    }
    return store;
}

- (ENCredentials *)credentialsForHost:(NSString *)host
{
    return [[self credentialStore] credentialsForHost:host];
}

- (void)addCredentials:(ENCredentials *)credentials
{
    ENCredentialStore * store = [self credentialStore];
    [store addCredentials:credentials];
    [self saveCredentialStore:store];
}

- (void)saveCredentialStore:(ENCredentialStore *)credentialStore
{
    [self.preferences encodeObject:credentialStore forKey:ENSessionPreferencesCredentialStore];
}

#pragma mark - Credentials & Auth

- (ENCredentials *)primaryCredentials
{
    //XXX: Is here a good place to check for no credentials and trigger an unauthed state?
    return [self credentialsForHost:self.sessionHost];
}

- (EDAMAuthenticationResult *)validBusinessAuthenticationResult
{
    NSAssert(![NSThread isMainThread], @"Cannot authenticate to linked notebook on main thread");
    EDAMAuthenticationResult * auth = [self.authCache authenticationResultForBusiness];
    if (!auth) {
        auth = [self.userStore authenticateToBusiness];
        [self.authCache setAuthenticationResultForBusiness:auth];
    }
    return auth;
}

- (ENAuthCache *)authCache
{
    if (!_authCache) {
        _authCache = [[ENAuthCache alloc] init];
    }
    return _authCache;
}

#pragma mark - Store clients

- (ENUserStoreClient *)userStore
{
    if (!_userStore) {
        _userStore = [ENUserStoreClient userStoreClientWithUrl:[self userStoreUrl] authenticationToken:self.primaryAuthenticationToken];
    }
    return _userStore;
}

- (ENNoteStoreClient *)primaryNoteStore
{
    if (!_primaryNoteStore) {
        if (DeveloperToken) {
            _primaryNoteStore = [ENNoteStoreClient noteStoreClientWithUrl:NoteStoreUrl authenticationToken:DeveloperToken];
        } else {
            ENCredentials * credentials = [self primaryCredentials];
            if (credentials) {
                _primaryNoteStore = [ENNoteStoreClient noteStoreClientWithUrl:credentials.noteStoreUrl authenticationToken:credentials.authenticationToken];
            }
        }
    }
    return _primaryNoteStore;
}

- (ENNoteStoreClient *)businessNoteStore
{
    if (!_businessNoteStore && [self isBusinessUser]) {
        ENBusinessNoteStoreClient * client = [ENBusinessNoteStoreClient noteStoreClientForBusiness];
        client.delegate = self;
        _businessNoteStore = client;
    }
    return _businessNoteStore;
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

#pragma mark - Preferences helpers

- (NSString *)currentProfileName
{
    return [self.preferences objectForKey:ENSessionPreferencesCurrentProfileName];
}

- (void)setCurrentProfileNameFromHost:(NSString *)host
{
    NSString * profileName = nil;
    if ([host isEqualToString:ENSessionBootstrapServerBaseURLStringUS]) {
        profileName = ENBootstrapProfileNameInternational;
    } else if ([host isEqualToString:ENSessionBootstrapServerBaseURLStringCN]) {
        profileName = ENBootstrapProfileNameChina;
    }
    [self.preferences setObject:profileName forKey:ENSessionPreferencesCurrentProfileName];
}

- (NSString *)userStoreUrl
{
    // If the host string includes an explict port (e.g., foo.bar.com:8080), use http. Otherwise https.
    // Use a simple regex to check for a colon and port number suffix.
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@".*:[0-9]+"
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:nil];
    NSUInteger numberOfMatches = [regex numberOfMatchesInString:self.sessionHost
                                                        options:0
                                                          range:NSMakeRange(0, [self.sessionHost length])];
    BOOL hasPort = (numberOfMatches > 0);
    NSString *scheme = (hasPort) ? @"http" : @"https";
    return [NSString stringWithFormat:@"%@://%@/edam/user", scheme, self.sessionHost];
}

#pragma mark - ENBusinessNoteStoreClientDelegate

- (NSString *)authenticationTokenForBusinessStoreClient:(ENBusinessNoteStoreClient *)client
{
    EDAMAuthenticationResult * auth = [self validBusinessAuthenticationResult];
    return auth.authenticationToken;
}

- (NSString *)noteStoreUrlForBusinessStoreClient:(ENBusinessNoteStoreClient *)client
{
    EDAMAuthenticationResult * auth = [self validBusinessAuthenticationResult];
    return auth.noteStoreUrl;
}

#pragma mark - ENLinkedNoteStoreClientDelegate

- (NSString *)authenticationTokenForLinkedNotebookRef:(ENLinkedNotebookRef *)linkedNotebookRef
{
    NSAssert(![NSThread isMainThread], @"Cannot authenticate to linked notebook on main thread");
    
    // See if we have auth data already for this notebook.
    EDAMAuthenticationResult * auth = [self.authCache authenticationResultForLinkedNotebookGuid:linkedNotebookRef.guid];
    if (!auth) {
        // Create a temporary note store client for the linked note store, with our primary auth token,
        // in order to authenticate to the shared notebook.
        ENNoteStoreClient * linkedNoteStore = [ENNoteStoreClient noteStoreClientWithUrl:linkedNotebookRef.noteStoreUrl authenticationToken:self.primaryAuthenticationToken];
        auth = [linkedNoteStore authenticateToSharedNotebookWithShareKey:linkedNotebookRef.shareKey];
        [self.authCache setAuthenticationResult:auth forLinkedNotebookGuid:linkedNotebookRef.guid];
    }
    return auth.authenticationToken;
}

#pragma mark - ENAuthenticatorDelegate

- (ENUserStoreClient *)userStoreClientForBootstrapping
{
    // The user store for bootstrapping does not require authenticated access.
    return [ENUserStoreClient userStoreClientWithUrl:[self userStoreUrl] authenticationToken:nil];
}

- (void)authenticatorDidAuthenticateWithCredentials:(ENCredentials *)credentials authInfo:(NSDictionary *)authInfo
{
    self.isAuthenticated = YES;
    [self addCredentials:credentials];
    [self setCurrentProfileNameFromHost:credentials.host];
    self.sessionHost = credentials.host;
    self.primaryAuthenticationToken = credentials.authenticationToken;
    BOOL appNotebookIsLinked = [[authInfo objectForKey:ENOAuthAuthenticatorAuthInfoAppNotebookIsLinked] boolValue];
    if (appNotebookIsLinked) {
        [self.preferences setObject:@YES forKey:ENSessionPreferencesAppNotebookIsLinked];
    }
    [self performPostAuthentication];
}

- (void)authenticatorDidFailWithError:(NSError *)error
{
    [self completeAuthenticationWithError:error];
}

@end

#pragma mark - Default logger

@implementation ENSessionDefaultLogger
- (void)evernoteLogInfoString:(NSString *)str;
{
    NSLog(@"ENSDK: %@", str);
}

- (void)evernoteLogErrorString:(NSString *)str;
{
    NSLog(@"ENSDK ERROR: %@", str);
}
@end


#pragma mark - Private context definitions
                                                
@implementation ENSessionListNotebooksContext
@end

@implementation ENSessionUploadNoteContext
@end
