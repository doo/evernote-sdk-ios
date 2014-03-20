//
//  ENNotebookChooserViewController.h
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 3/20/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ENSDK.h"
@class ENNotebookChooserViewController;

@protocol ENNotebookChooserViewControllerDelegate <NSObject>
- (void)notebookChooser:(ENNotebookChooserViewController *)chooser didChooseNotebook:(ENNotebook *)notebook;
@end

@interface ENNotebookChooserViewController : UITableViewController
@property (nonatomic, weak) id<ENNotebookChooserViewControllerDelegate> delegate;
@property (nonatomic, strong) NSArray * notebookList;
@property (nonatomic, strong) ENNotebook * currentNotebook;
@end
