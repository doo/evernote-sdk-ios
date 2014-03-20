//
//  ENSendToEvernoteViewController.m
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 3/20/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import "ENSendToEvernoteViewController.h"
#import "ENNotebookChooserViewController.h"
#import "ENSDK.h"

@interface ENSendToEvernoteActivity (Private)
- (ENNote *)preparedNote;
@end

@interface ENSendToEvernoteViewController () <ENNotebookChooserViewControllerDelegate, UITextFieldDelegate>
@property (nonatomic, strong) IBOutlet UIButton * sendButton;
@property (nonatomic, strong) IBOutlet UITextField * titleField;
@property (nonatomic, strong) IBOutlet UITextField * notebookField;
@property (nonatomic, strong) IBOutlet UITextField * tagsField;

@property (nonatomic, strong) NSArray * notebookList;
@property (nonatomic, strong) ENNotebook * currentNotebook;
@end

@implementation ENSendToEvernoteViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.sendButton.enabled = NO;
    self.titleField.text = [self.delegate defaultNoteTitleForViewController:self];
    self.notebookField.delegate = self;
    self.tagsField.placeholder = @"Enter tags, separated by commas"; // XXX loc
    
    //XXX: hack because the UI isn't final and i don't feel like subclassing.
    UIView * marginPlaceholder = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 22, self.titleField.frame.size.height)];
    marginPlaceholder.backgroundColor = self.titleField.backgroundColor;
    self.titleField.leftView = marginPlaceholder;
    self.titleField.leftViewMode = UITextFieldViewModeAlways;
    marginPlaceholder = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 22, self.notebookField.frame.size.height)];
    marginPlaceholder.backgroundColor = self.notebookField.backgroundColor;
    self.notebookField.leftView = marginPlaceholder;
    self.notebookField.leftViewMode = UITextFieldViewModeAlways;
    marginPlaceholder = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 22, self.tagsField.frame.size.height)];
    marginPlaceholder.backgroundColor = self.tagsField.backgroundColor;
    self.tagsField.leftView = marginPlaceholder;
    self.tagsField.leftViewMode = UITextFieldViewModeAlways;
    
    // Kick off the notebook list fetch.
    [[ENSession sharedSession] listNotebooksWithHandler:^(NSArray *notebooks, NSError *listNotebooksError) {
        self.notebookList = notebooks;
        // Populate the notebook picker with the default notebook.
        for (ENNotebook * notebook in notebooks) {
            if (notebook.isDefaultNotebook) {
                self.currentNotebook = notebook;
                [self updateCurrentNotebookDisplay];
                break;
            }
        }
        self.sendButton.enabled = YES;
    }];
}

- (void)updateCurrentNotebookDisplay
{
    NSString * displayName = self.currentNotebook.name;
    if (self.currentNotebook.isBusinessNotebook) {
        displayName = [displayName stringByAppendingString:@" (B)"];
    }
    self.notebookField.text = displayName;
}

- (void)showNotebookChooser
{
    ENNotebookChooserViewController * chooser = [[ENNotebookChooserViewController alloc] initWithStyle:UITableViewStylePlain];
    chooser.delegate = self;
    chooser.notebookList = self.notebookList;
    chooser.currentNotebook = self.currentNotebook;
    [self presentViewController:chooser animated:YES completion:nil];
}

#pragma mark - Actions

- (IBAction)send:(id)sender
{
    // Fetch the note we've built so far.
    ENNote * note = [self.delegate noteForViewController:self];

    // Populate the metadata fields we offered.
    note.title = self.titleField.text;
    if (note.title.length == 0) {
        note.title = @"Untitled note"; // XXX loc
    }
    note.notebook = self.currentNotebook;
    
    // Parse out tags from between commas and trim whitespace.
    NSArray * tags = [self.tagsField.text componentsSeparatedByString:@","];
    NSMutableArray * sanitizedTags = [NSMutableArray array];
    for (NSString * tag in tags) {
        NSString * sanitizedTag = [tag stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (sanitizedTag.length > 1) {
            [sanitizedTags addObject:sanitizedTag];
        }
    }
    if (sanitizedTags.count > 0) {
        note.tagNames = sanitizedTags;
    }
    
    // Upload the note.
    [[ENSession sharedSession] uploadNote:note completion:^(ENNoteRef *noteRef, NSError *uploadNoteError) {
        [self.delegate viewController:self didFinishWithSuccess:(noteRef != nil)];
    }];
}

- (IBAction)cancel:(id)sender
{
    [self.delegate viewController:self didFinishWithSuccess:NO];
}

#pragma mark - ENNotebookChooserViewControllerDelegate

- (void)notebookChooser:(ENNotebookChooserViewController *)chooser didChooseNotebook:(ENNotebook *)notebook
{
    self.currentNotebook = notebook;
    [self updateCurrentNotebookDisplay];
    [chooser dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    if (textField == self.notebookField) {
        [self showNotebookChooser];
        return NO;
    }
    
    return YES;
}
@end
