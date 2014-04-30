//
//  ENSendToEvernoteViewController.h
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 3/20/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ENSDK.h"
@class ENSaveToEvernoteViewController;

@protocol ENSendToEvernoteViewControllerDelegate <NSObject>
- (ENNote *)noteForViewController:(ENSaveToEvernoteViewController *)viewController;
- (NSString *)defaultNoteTitleForViewController:(ENSaveToEvernoteViewController *)viewController;
- (void)viewController:(ENSaveToEvernoteViewController *)viewController didFinishWithSuccess:(BOOL)success;
@end

@interface ENSaveToEvernoteViewController : UIViewController
@property (nonatomic, weak) id<ENSendToEvernoteViewControllerDelegate> delegate;
@end
