//
//  ENAuthenticator.m
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 3/26/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import "ENAuthenticator.h"
#import "ENUserStoreClient.h"
#import "ENOAuthViewController.h"
#import "ENCredentials.h"
#import "ENCredentialStore.h"

#import "ENGCOAuth.h"

#import "NSRegularExpression+ENAGRegex.h"

#define OAUTH_PROTOCOL_SCHEME @"https"

typedef NS_ENUM(NSInteger, ENSessionState) {
    /*! Evernote session has been created but not logged in */
    ENSessionLoggedOut,
    /*! Authentication is in progress */
    ENSessionAuthenticationInProgress,
    /*! Session has been called back by the Evernote app*/
    ENSessionGotCallback,
    /*! Session has authenticated successfully*/
    ENSessionAuthenticated
};

@interface NSString (ENURLEncoding)
- (NSString *)en_stringByUrlEncoding;
- (NSString *)en_stringByUrlDecoding;
@end

@interface ENAuthenticator () <ENOAuthViewControllerDelegate>
@property (nonatomic, strong) UIViewController * viewController;
@property (nonatomic, strong) ENAuthenticatorCompletionHandler completion;

@property (nonatomic, assign) ENSessionState state;

@property (nonatomic, strong) NSArray * profiles;
@property (nonatomic, copy) NSString * currentProfile;

@property (nonatomic, strong) ENCredentialStore * credentialStore;

@property (nonatomic, strong) NSDate * oauthStartDate;
@property (nonatomic, copy) NSString * tokenSecret;
@property (nonatomic, assign) BOOL isMultitaskLoginDisabled;
@property (nonatomic, assign) BOOL isSwitchingInProgress;

@property (nonatomic, strong) ENOAuthViewController * oauthViewController;

@property (nonatomic, strong) NSMutableData * receivedData;
@property (nonatomic, strong) NSURLResponse * response;
@end

@implementation ENAuthenticator
- (id)init
{
    self = [super init];
    if (self) {
        //XXX: state default?
    }
    return self;
}

- (void)emptyCookieJar
{
    NSHTTPCookieStorage *cookieJar = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *cookie in [cookieJar cookies]) {
        if ([[cookie domain] hasSuffix: self.host]) {
            [cookieJar deleteCookie: cookie];
        }
    }
}

- (void)authenticateWithViewController:(UIViewController *)viewController
                            completion:(ENAuthenticatorCompletionHandler)completion
{
    NSAssert(viewController, @"Must use valid viewController");
    NSAssert(completion, @"Must use valid completion");
    NSAssert(self.delegate, @"Must set authenticator delegate");
    
    self.viewController = viewController;
    self.completion = completion;
    
    // remove all cookies from the Evernote service so that the user can log in with
    // different credentials after declining to authorize access
    [self emptyCookieJar];
    
    self.credentialStore = [[ENCredentialStore alloc] init];
    
    // Start bootstrapping
    NSString * locale = [[NSLocale currentLocale] localeIdentifier];
    ENUserStoreClient * userStore = [self.delegate userStoreClientForBootstrapping];
    [userStore getBootstrapInfoWithLocale:locale success:^(EDAMBootstrapInfo *info) {
        // Using first profile as the preferred profile.
        EDAMBootstrapProfile * profile = [info.profiles objectAtIndex:0];
        self.profiles = info.profiles;
        self.currentProfile = profile.name;
        self.host = profile.settings.serviceHost;
        // start the OAuth dance to get credentials (auth token, noteStoreUrl, etc).
        [self startOauthAuthentication];
    } failure:^(NSError * error) {
        // start the OAuth dance to get credentials (auth token, noteStoreUrl, etc).
        [self startOauthAuthentication];
    }];
}

- (void)startOauthAuthentication
{
    // OAuth step 1: temporary credentials (aka request token) request
    NSURLRequest * tempTokenRequest = [ENGCOAuth URLRequestForPath:@"/oauth"
                                                    GETParameters:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                   [self oauthCallback], @"oauth_callback", nil]
                                                           scheme:OAUTH_PROTOCOL_SCHEME
                                                             host:self.host
                                                      consumerKey:self.consumerKey
                                                   consumerSecret:self.consumerSecret
                                                      accessToken:nil
                                                      tokenSecret:nil];
    
    self.oauthStartDate = [NSDate date];
    NSURLConnection * connection = [NSURLConnection connectionWithRequest:tempTokenRequest delegate:self];
    if (!connection) {
        // can't make connection, so immediately fail.
        [self completeAuthenticationWithError:[NSError errorWithDomain:EvernoteSDKErrorDomain
                                                                  code:EvernoteSDKErrorCode_TRANSPORT_ERROR
                                                              userInfo:nil]];
    }
}

- (NSString *)callbackScheme
{
    // The callback scheme is client-app specific, of the form en-CONSUMERKEY
    return [NSString stringWithFormat:@"en-%@", [self.consumerKey stringByReplacingOccurrencesOfString:@"_" withString:@"+"]];
}

- (NSString *)oauthCallback
{
    // The full callback URL is en-CONSUMERKEY://response
    return [NSString stringWithFormat:@"%@://response", [self callbackScheme]];
}

/*
 * Make an authorization URL.
 *
 * E.g.,
 * https://www.evernote.com/OAuth.action?oauth_token=en_oauth_test.12345
 */
- (NSString *)userAuthorizationURLStringWithParameters:(NSDictionary *)tokenParameters
{
    NSString* deviceID = nil;
    if([[UIDevice currentDevice] respondsToSelector:@selector(identifierForVendor)]) {
        deviceID = [[self class] deviceIdentifier];
    }
    if(deviceID == nil) {
        deviceID = [NSString string];
    }
    NSString* deviceDescription = [[self class] deviceDescription];
    NSDictionary *authParameters = @{ @"oauth_token":[tokenParameters objectForKey:@"oauth_token"],
                                      @"inapp":@"ios",
                                      @"deviceDescription":deviceDescription,
                                      @"deviceIdentifier":deviceID};
    NSString *queryString = [[self class] queryStringFromParameters:authParameters];
    return [NSString stringWithFormat:@"%@://%@/OAuth.action?%@", OAUTH_PROTOCOL_SCHEME, self.host, queryString];
}

+ (NSString *)deviceIdentifier {
    NSString *deviceIdentifier = nil;
#if TARGET_OS_IPHONE
    UIDevice *currentDevice = [UIDevice currentDevice];
    if ([currentDevice respondsToSelector:@selector(identifierForVendor)]) {
        deviceIdentifier = [[currentDevice identifierForVendor] UUIDString];
    }
#else
    io_registry_entry_t ioRegistryRoot = IORegistryEntryFromPath(kIOMasterPortDefault, "IOService:/");
    CFStringRef uuid = (CFStringRef) IORegistryEntryCreateCFProperty(ioRegistryRoot, CFSTR(kIOPlatformUUIDKey), kCFAllocatorDefault, 0);
    IOObjectRelease(ioRegistryRoot);
    deviceIdentifier = (__bridge_transfer NSString *)uuid;
#endif
    
    if (deviceIdentifier == nil) {
        // Alternatively we could try ethernet mac address...
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        NSString *uuid = [userDefaults objectForKey:@"EDAMHTTPClientUUID"];
        if (uuid == nil) {
            CFUUIDRef uuidRef = CFUUIDCreate(NULL);
            CFStringRef uuidStringRef = CFUUIDCreateString(NULL, uuidRef);
            CFRelease(uuidRef);
            uuid = (__bridge_transfer NSString *)uuidStringRef;
            
            [userDefaults setObject:uuid forKey:@"EDAMHTTPClientUUID"];
        }
        deviceIdentifier = uuid;
    }
    
    deviceIdentifier = [self scrubString:deviceIdentifier
                              usingRegex:[EDAMLimitsConstants EDAM_DEVICE_ID_REGEX]
                           withMaxLength:[EDAMLimitsConstants EDAM_DEVICE_ID_LEN_MAX]];
    
    return deviceIdentifier;
}

+ (NSString *)deviceDescription {
    NSString *deviceDescription = nil;
#if TARGET_OS_IPHONE
    UIDevice *currentDevice = [UIDevice currentDevice];
    deviceDescription = [[currentDevice name] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if ([deviceDescription length] == 0) {
        deviceDescription = [currentDevice model];
    }
    
#if TARGET_IPHONE_SIMULATOR
    deviceDescription = [deviceDescription stringByAppendingFormat:@" %@ (%@)", [currentDevice systemVersion], [NSString string]];
#endif
#endif
    if ([deviceDescription length] == 0) {
        deviceDescription = [NSString string];
    }
    
    deviceDescription = [self scrubString:deviceDescription
                               usingRegex:[EDAMLimitsConstants EDAM_DEVICE_DESCRIPTION_REGEX]
                            withMaxLength:[EDAMLimitsConstants EDAM_DEVICE_DESCRIPTION_LEN_MAX]];
    return deviceDescription;
}

#pragma mark -
#pragma mark Device id/name
+ (NSString *) scrubString:(NSString *)string
                usingRegex:(NSString *)regexPattern
             withMaxLength:(uint16_t)maxLength
{
    if ([string length] > maxLength) {
        string = [string substringToIndex:maxLength];
    }
    
    NSRegularExpression * regex = [NSRegularExpression enRegexWithPattern: regexPattern];
    if ([regex enFindInString: string] == NO) {
        NSMutableString * newString = [NSMutableString stringWithCapacity: [string length]];
        for (NSUInteger i = 0; i < [string length]; i++) {
            NSString * oneCharSubString = [string substringWithRange: NSMakeRange(i, 1)];
            if ([regex enFindInString: string]) {
                [newString appendString: oneCharSubString];
            }
        }
        string = newString;
    }
    
    return string;
}

- (BOOL)handleOpenURL:(NSURL *)url
{
    [self.viewController dismissViewControllerAnimated:YES completion:^{
        // only handle our specific oauth_callback URLs
        if (![[url absoluteString] hasPrefix:[self oauthCallback]]) {
            return;
        }
        // OAuth step 3: got authorization from the user, now get a real token.
        NSDictionary * parameters = [[self class] parametersFromQueryString:url.query];
        NSString * oauthToken = [parameters objectForKey:@"oauth_token"];
        NSString * oauthVerifier = [parameters objectForKey:@"oauth_verifier"];
        NSURLRequest * authTokenRequest = [ENGCOAuth URLRequestForPath:@"/oauth"
                                                        GETParameters:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                       oauthVerifier, @"oauth_verifier", nil]
                                                               scheme:OAUTH_PROTOCOL_SCHEME
                                                                 host:self.host
                                                          consumerKey:self.consumerKey
                                                       consumerSecret:self.consumerSecret
                                                          accessToken:oauthToken
                                                          tokenSecret:self.tokenSecret];
        
        self.oauthStartDate = [NSDate date];
        NSURLConnection * connection = [NSURLConnection connectionWithRequest:authTokenRequest delegate:self];
        if (!connection) {
            // can't make connection, so immediately fail.
            [self completeAuthenticationWithError:[NSError errorWithDomain:EvernoteSDKErrorDomain
                                                                      code:EvernoteSDKErrorCode_TRANSPORT_ERROR
                                                                  userInfo:nil]];
        };
    }];
    if (![[url absoluteString] hasPrefix:[self oauthCallback]]) {
        return NO;
    }
    return YES;
}

- (void)handleDidBecomeActive{
    //Unexpected to calls to app delegate's applicationDidBecomeActive are
    // handled by this method.
    const ENSessionState state = self.state;
    
    if (state == ENSessionLoggedOut ||
        state == ENSessionAuthenticated ||
        state == ENSessionGotCallback) {
        return;
    }
    [self gotCallbackURL:nil];
    self.state = ENSessionLoggedOut;
}

#pragma mark - NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    self.receivedData = nil;
    self.response = nil;
    [self completeAuthenticationWithError:error];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    self.response = response;
    self.receivedData = [NSMutableData data];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [self.receivedData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    NSString *string = [[NSString alloc] initWithData:self.receivedData
                                             encoding:NSUTF8StringEncoding];
    
    // Trap bad HTTP response status codes.
    // This might be from an invalid consumer key, a key not set up for OAuth, etc.
    // Usually this shows up as a 401 response with an error page, so
    // log it and callback an error.
    if ([self.response respondsToSelector:@selector(statusCode)]) {
        NSInteger statusCode = [(id)self.response statusCode];
        if (statusCode != 200) {
            NSLog(@"Received error HTTP response code: %ld", (long)statusCode);
            NSLog(@"%@", string);
            NSDictionary* userInfo = nil;
            if(statusCode) {
                NSNumber* statusCodeNumber = [NSNumber numberWithInteger:statusCode];
                userInfo = @{@"statusCode": statusCodeNumber};
            }
            [self completeAuthenticationWithError:
             [NSError errorWithDomain:EvernoteSDKErrorDomain
                                 code:EvernoteSDKErrorCode_TRANSPORT_ERROR
                             userInfo:userInfo]];
            self.receivedData = nil;
            self.response = nil;
            return;
        }
    }
    
    NSDictionary *parameters = [[self class] parametersFromQueryString:string];
    
    if ([parameters objectForKey:@"oauth_callback_confirmed"]) {
        // OAuth step 2: got our temp token, now get authorization from the user.
        // Save the token secret, for later use in OAuth step 3.
        self.tokenSecret = [parameters objectForKey:@"oauth_token_secret"];
        
        NSLog(@"OAuth Step 1 - Time Running is: %f",[self.oauthStartDate timeIntervalSinceNow] * - 1);
        
        // If the device supports multitasking,
        // try to get the OAuth token from the Evernote app
        // on the device.
        // If the Evernote app is not installed or it doesn't support
        // the en:// URL scheme, fall back on WebKit for obtaining the OAuth token.
        // This minimizes the chance that the user will have to enter his or
        // her credentials in order to authorize the application.
        UIDevice *device = [UIDevice currentDevice];
        if([self isEvernoteInstalled] == NO) {
            self.isMultitaskLoginDisabled = YES;
        }
        [self verifyCFBundleURLSchemes];
        if ([device respondsToSelector:@selector(isMultitaskingSupported)] &&
            [device isMultitaskingSupported] &&
            self.isMultitaskLoginDisabled==NO) {
            self.state = ENSessionAuthenticationInProgress;
            NSString* openURL = [NSString stringWithFormat:@"en://link-sdk/consumerKey/%@/profileName/%@/authorization/%@",self.consumerKey,self.currentProfile,parameters[@"oauth_token"]];
            BOOL success = [[UIApplication sharedApplication] openURL:[NSURL URLWithString:openURL]];
            if(success == NO) {
                // The Evernote app does not support the full URL, falling back
                self.isMultitaskLoginDisabled = YES;
                // Restart oAuth dance
                [self startOauthAuthentication];
            }
        }
        else {
            // Open a modal ENOAuthViewController on top of our given view controller,
            // and point it at the proper Evernote web page so the user can authorize us.
            NSString *userAuthURLString = [self userAuthorizationURLStringWithParameters:parameters];
            NSURL *userAuthURL = [NSURL URLWithString:userAuthURLString];
            [self openOAuthViewControllerWithURL:userAuthURL];
        }
    } else {
        // OAuth step 4: final callback, with our real token
        NSString *authenticationToken = [parameters objectForKey:@"oauth_token"];
        NSString *noteStoreUrl = [parameters objectForKey:@"edam_noteStoreUrl"];
        NSString *edamUserId = [parameters objectForKey:@"edam_userId"];
        NSString *webApiUrlPrefix = [parameters objectForKey:@"edam_webApiUrlPrefix"];
        
        NSLog(@"OAuth Step 3 - Time Running is: %f",[self.oauthStartDate timeIntervalSinceNow] * -1);
        // Evernote doesn't use the token secret, so we can ignore it.
        // NSString *oauthTokenSecret = [parameters objectForKey:@"oauth_token_secret"];
        
        // If any of the fields are nil, we can't continue.
        // Assume an invalid response from the server.
        if (!authenticationToken || !noteStoreUrl || !edamUserId || !webApiUrlPrefix) {
            [self completeAuthenticationWithError:[NSError errorWithDomain:EvernoteSDKErrorDomain
                                                                      code:EDAMErrorCode_INTERNAL_ERROR
                                                                  userInfo:nil]];
        } else {
            // add auth info to our credential store, saving to user defaults and keychain
            [self saveCredentialsWithEdamUserId:edamUserId
                                   noteStoreUrl:noteStoreUrl
                                webApiUrlPrefix:webApiUrlPrefix
                            authenticationToken:authenticationToken];
            // call our callback, without error.
            [self completeAuthenticationWithError:nil];
            // update the auth state
            self.state = ENSessionAuthenticated;
        }
    }
    
    self.receivedData = nil;
    self.response = nil;
}

- (void)openOAuthViewControllerWithURL:(NSURL *)authorizationURL
{
    BOOL isSwitchAllowed = NO;
    if([self.profiles count]>1) {
        isSwitchAllowed = YES;
    }
    else {
        isSwitchAllowed = NO;
    }
    if(!self.isSwitchingInProgress ) {
        self.oauthViewController = [[ENOAuthViewController alloc] initWithAuthorizationURL:authorizationURL
                                                                       oauthCallbackPrefix:[self oauthCallback]
                                                                               profileName:self.currentProfile
                                                                            allowSwitching:isSwitchAllowed
                                                                                  delegate:self];
        UINavigationController *oauthNavController = [[UINavigationController alloc] initWithRootViewController:self.oauthViewController];
        
        // use a formsheet on iPad
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            self.oauthViewController.modalPresentationStyle = UIModalPresentationFormSheet;
            oauthNavController.modalPresentationStyle = UIModalPresentationFormSheet;
        }
        [self.viewController presentViewController:oauthNavController animated:YES completion:^{
            ;
        }];
    }
    else {
        [self.oauthViewController updateUIForNewProfile:self.currentProfile withAuthorizationURL:authorizationURL];
        self.isSwitchingInProgress = NO;
        
    }
}

- (void)saveCredentialsWithEdamUserId:(NSString *)edamUserId
                         noteStoreUrl:(NSString *)noteStoreUrl
                      webApiUrlPrefix:(NSString *)webApiUrlPrefix
                  authenticationToken:(NSString *)authenticationToken
{
    ENCredentials  *ec = [[ENCredentials alloc] initWithHost:self.host
                                                 edamUserId:edamUserId
                                               noteStoreUrl:noteStoreUrl
                                            webApiUrlPrefix:webApiUrlPrefix
                                        authenticationToken:authenticationToken];
    [self.credentialStore addCredentials:ec];
    if([self.currentProfile isEqualToString:ENBootstrapProfileNameChina]) {
        [ENCredentialStore saveCurrentProfile:EVERNOTE_SERVICE_YINXIANG];
    }
    else if([self.currentProfile isEqualToString:ENBootstrapProfileNameInternational]) {
        [ENCredentialStore saveCurrentProfile:EVERNOTE_SERVICE_INTERNATIONAL];
    }
}

- (void)saveBusinessCredentialsWithEdamUserId:(NSString *)edamUserId
                                 noteStoreUrl:(NSString *)noteStoreUrl
                              webApiUrlPrefix:(NSString *)webApiUrlPrefix
                          authenticationToken:(NSString *)authenticationToken
{
    ENCredentials *ec = [[ENCredentials alloc] initWithHost:[NSString stringWithFormat:@"%@%@",self.host,BusinessHostNameSuffix]
                                                 edamUserId:edamUserId
                                               noteStoreUrl:noteStoreUrl
                                            webApiUrlPrefix:webApiUrlPrefix
                                        authenticationToken:authenticationToken];
    [self.credentialStore addCredentials:ec];
}

- (void)completeAuthenticationWithError:(NSError *)error
{
    if(error) {
        self.state = ENSessionLoggedOut;
    }

    ENAuthenticator * strongSelf = self;
    
    if (self.completion) {
        self.completion(error);
    }
    
    // Nil these out; the authenticator object can in theory be reused, but in case the completion
    // is used release the authenticator, set these on a strong ref.
    strongSelf.completion = nil;
    strongSelf.viewController = nil;
}

- (void) switchProfile {
    NSUInteger profileIndex = 0;
    for (profileIndex = 0; profileIndex<self.profiles.count; profileIndex++) {
        EDAMBootstrapProfile *profile = [self.profiles objectAtIndex:profileIndex];
        if([self.currentProfile isEqualToString:profile.name]) {
            break;
        }
    }
    
    EDAMBootstrapProfile* nextProfile = [self.profiles objectAtIndex:(profileIndex+1)%self.profiles.count];
    [self updateCurrentBootstrapProfileWithName:nextProfile.name];
}

- (void)updateCurrentBootstrapProfileWithName:(NSString *)aProfileName {
    BOOL wasProfileFound = NO;
    for (EDAMBootstrapProfile *p in self.profiles) {
        if ([aProfileName isEqualToString:[p name]]) {
            self.currentProfile = p.name;
            self.host = p.settings.serviceHost;
            wasProfileFound = YES;
            break;
        }
    }
    if(wasProfileFound == NO) {
        // We could not find any profile mathching with the evernote app
        self.isMultitaskLoginDisabled = YES;
    }
    // Restart oAuth dance
    [self startOauthAuthentication];
}

// Make sure our Info.plist has the needed CFBundleURLTypes/CGBundleURLSchemes entries.
// E.g.
// <key>CFBundleURLTypes</key>
// <array>
//   <dict>
//     <key>CFBundleURLSchemes</key>
//     <array>
//       <string>en-YOUR_CONSUMER_KEY</string>
//     </array>
//   </dict>
// </array>

- (void)verifyCFBundleURLSchemes {
    NSArray *urlTypes = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleURLTypes"];
    NSString* callbackScheme = [NSString stringWithFormat:@"en-%@",self.consumerKey];
    
    for (NSDictionary *dict in urlTypes) {
        NSArray *urlSchemes = [dict objectForKey:@"CFBundleURLSchemes"];
        for (NSString *urlScheme in urlSchemes) {
            if ([callbackScheme isEqualToString:urlScheme]) {
                return;
            }
        }
    }
    self.isMultitaskLoginDisabled = YES;
}

#pragma mark - querystring parsing

+ (NSString *)queryStringFromParameters:(NSDictionary *)parameters
{
    NSMutableArray *entries = [NSMutableArray array];
    [parameters enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        NSString *entry = [NSString stringWithFormat:@"%@=%@", [key en_stringByUrlEncoding], [obj en_stringByUrlEncoding]];
        [entries addObject:entry];
    }];
    return [entries componentsJoinedByString:@"&"];
}

+ (NSDictionary *)parametersFromQueryString:(NSString *)queryString
{
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    NSArray *nameValues = [queryString componentsSeparatedByString:@"&"];
    for (NSString *nameValue in nameValues) {
        NSArray *components = [nameValue componentsSeparatedByString:@"="];
        if ([components count] == 2) {
            NSString *name = [[components objectAtIndex:0] en_stringByUrlDecoding];
            NSString *value = [[components objectAtIndex:1] en_stringByUrlDecoding];
            if (name && value) {
                [dict setObject:value forKey:name];
            }
        }
    }
    return dict;
}

#pragma mark - ENOAuthViewControllerDelegate

- (void)oauthViewControllerDidCancel:(ENOAuthViewController *)sender
{
    [self.viewController dismissViewControllerAnimated:YES completion:^{
        NSError* error = [NSError errorWithDomain:EvernoteSDKErrorDomain code:EvernoteSDKErrorCode_USER_CANCELLED userInfo:nil];
        [self completeAuthenticationWithError:error];
    }];
}

- (void)oauthViewControllerDidSwitchProfile:(ENOAuthViewController *)sender {
    self.isSwitchingInProgress = YES;
    [self switchProfile];
}

- (void)oauthViewController:(ENOAuthViewController *)sender didFailWithError:(NSError *)error
{
    [self.viewController dismissViewControllerAnimated:YES completion:^{
        [self completeAuthenticationWithError:error];
    }];
    
}

- (BOOL)canHandleOpenURL:(NSURL *)url {
    if([[url host] isEqualToString:@"invalidURL"]) {
        NSLog(@"Invalid URL sent to Evernote!");
        return NO;
    }
    // update state
    self.state = ENSessionGotCallback;
    NSString* hostName = [NSString stringWithFormat:@"en-%@",
                          [[EvernoteSession sharedSession] consumerKey]];
    BOOL canHandle = NO;
    // Check if we got back the oauth token
    if ([hostName isEqualToString:[url scheme]] == YES
        && [@"oauth" isEqualToString:[url host]] == YES) {
        canHandle = YES;
        NSString* oAuthPrefix = [NSString stringWithFormat:@"en-%@://oauth/",[[EvernoteSession sharedSession] consumerKey]];
        NSString *callback = [url.absoluteString stringByReplacingOccurrencesOfString:oAuthPrefix withString:@""];
        [[self class] gotCallbackURL:callback];
    }
    // Check if the login was cancelled
    else if ([hostName isEqualToString:[url scheme]] == YES
             && [@"loginCancelled" isEqualToString:[url host]] == YES) {
        canHandle = YES;
        [self gotCallbackURL:nil];
    }
    // Check if we need to switch profiles
    else if ([hostName isEqualToString:[url scheme]] == YES
             && [@"incorrectProfile" isEqualToString:[url host]] == YES) {
        return [self canHandleSwitchProfileURL:url];
    }
    return  canHandle;
}

- (BOOL) canHandleSwitchProfileURL:(NSURL *)url {
    NSString *requestURL = [url path];
    NSArray *components = [requestURL componentsSeparatedByString:@"/"];
    if ([components count] < 2) {
        NSLog(@"URL:%@ has invalid component count: %lu", url, (unsigned long)[components count]);
        return NO;
    }
    [[EvernoteSession sharedSession] updateCurrentBootstrapProfileWithName:components[1]];
    return YES;
}

- (void)gotCallbackURL : (NSString*)callback {
    NSURL* callbackURL = [NSURL URLWithString:callback];
    [self getOAuthTokenForURL:callbackURL];
}

- (void)oauthViewController:(ENOAuthViewController *)sender receivedOAuthCallbackURL:(NSURL *)url
{
    [self.viewController dismissViewControllerAnimated:YES completion:^{
        [self getOAuthTokenForURL:url];
    }];
}

- (void)getOAuthTokenForURL:(NSURL*)url {
    // OAuth step 3: got authorization from the user, now get a real token.
    NSDictionary *parameters = [[self class] parametersFromQueryString:url.query];
    NSString *oauthToken = [parameters objectForKey:@"oauth_token"];
    NSString *oauthVerifier = [parameters objectForKey:@"oauth_verifier"];
    NSURLRequest *authTokenRequest = [ENGCOAuth URLRequestForPath:@"/oauth"
                                                    GETParameters:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                   oauthVerifier, @"oauth_verifier", nil]
                                                           scheme:OAUTH_PROTOCOL_SCHEME
                                                             host:self.host
                                                      consumerKey:self.consumerKey
                                                   consumerSecret:self.consumerSecret
                                                      accessToken:oauthToken
                                                      tokenSecret:self.tokenSecret];
    self.oauthStartDate = [NSDate date];
    NSURLConnection * connection = [NSURLConnection connectionWithRequest:authTokenRequest delegate:self];
    if (!connection) {
        // can't make connection, so immediately fail.
        [self completeAuthenticationWithError:[NSError errorWithDomain:EvernoteSDKErrorDomain
                                                                  code:EvernoteSDKErrorCode_TRANSPORT_ERROR
                                                              userInfo:nil]];
    };
}

- (BOOL)isEvernoteInstalled
{
    return [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"en://"]];
}

@end

@implementation NSString (ENURLEncoding)
- (NSString *)en_stringByUrlEncoding
{
    return (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL,
                                                                                 (CFStringRef)self,
                                                                                 NULL,
                                                                                 (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ",
                                                                                 kCFStringEncodingUTF8));
}

- (NSString *)en_stringByUrlDecoding
{
	return (NSString *)CFBridgingRelease(CFURLCreateStringByReplacingPercentEscapesUsingEncoding(kCFAllocatorDefault,
                                                                                                             (CFStringRef)self,
                                                                                                             CFSTR(""),
                                                                                                             kCFStringEncodingUTF8));
}
@end

