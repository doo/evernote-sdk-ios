//
//  ENBusinessNoteStoreClient.h
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 4/7/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import "ENNoteStoreClient.h"
@class ENBusinessNoteStoreClient;

@protocol ENBusinessNoteStoreClientDelegate <NSObject>
- (NSString *)noteStoreUrlForBusinessStoreClient:(ENBusinessNoteStoreClient *)client;
- (NSString *)authenticationTokenForBusinessStoreClient:(ENBusinessNoteStoreClient *)client;
@end

@interface ENBusinessNoteStoreClient : ENNoteStoreClient
@property (nonatomic, weak) id<ENBusinessNoteStoreClientDelegate> delegate;
@property (nonatomic, copy) NSString * noteStoreUrl;
+ (instancetype)noteStoreClientForBusiness;
@end

