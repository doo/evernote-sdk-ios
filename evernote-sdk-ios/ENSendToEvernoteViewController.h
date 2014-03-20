//
//  ENSendToEvernoteViewController.h
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 3/20/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ENSDK.h"
@class ENSendToEvernoteViewController;

@protocol ENSendToEvernoteViewControllerDelegate <NSObject>
- (ENNote *)noteForViewController:(ENSendToEvernoteViewController *)viewController;
- (NSString *)defaultNoteTitleForViewController:(ENSendToEvernoteViewController *)viewController;
- (void)viewController:(ENSendToEvernoteViewController *)viewController didFinishWithSuccess:(BOOL)success;
@end

@interface ENSendToEvernoteViewController : UIViewController
@property (nonatomic, weak) id<ENSendToEvernoteViewControllerDelegate> delegate;
@end
