//
//  ENAuthenticator.h
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 3/26/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ENUserStoreClient.h"

typedef void (^ENAuthenticatorCompletionHandler)(NSError * error);

@protocol ENAuthenticatorDelegate <NSObject>
- (ENUserStoreClient *)userStoreClientForBootstrapping;
@end

@interface ENAuthenticator : NSObject
@property (nonatomic, weak) id<ENAuthenticatorDelegate> delegate;
@property (nonatomic, copy) NSString * consumerKey;
@property (nonatomic, copy) NSString * consumerSecret;
@property (nonatomic, copy) NSString * host;

- (void)authenticateWithViewController:(UIViewController *)viewController
                            completion:(ENAuthenticatorCompletionHandler)completion;
@end
