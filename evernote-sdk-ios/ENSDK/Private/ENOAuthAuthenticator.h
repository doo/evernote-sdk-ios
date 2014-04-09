//
//  ENOAuthAuthenticator.h
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 3/26/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ENUserStoreClient.h"
#import "ENCredentials.h"

@protocol ENOAuthAuthenticatorDelegate <NSObject>
- (ENUserStoreClient *)userStoreClientForBootstrapping;
- (void)authenticatorDidAuthenticateWithCredentials:(ENCredentials *)credentials;
- (void)authenticatorDidFailWithError:(NSError *)error;
@end

@interface ENOAuthAuthenticator : NSObject
@property (nonatomic, weak) id<ENOAuthAuthenticatorDelegate> delegate;
@property (nonatomic, copy) NSString * consumerKey;
@property (nonatomic, copy) NSString * consumerSecret;
@property (nonatomic, copy) NSString * host;

- (void)authenticateWithViewController:(UIViewController *)viewController;

- (BOOL)canHandleOpenURL:(NSURL *)url;
@end
