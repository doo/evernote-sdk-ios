//
//  ENSendToEvernoteViewController.m
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 3/20/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import "ENSaveToEvernoteViewController.h"
#import "ENNotebookChooserViewController.h"
#import "ENSDK.h"
#import "ENTheme.h"

#define kTitleViewHeight        50.0
#define kTagsViewHeight         38.0
#define kNotebookViewHeight     50.0

@interface ENSaveToEvernoteActivity (Private)
- (ENNote *)preparedNote;
@end

@interface ENSaveToEvernoteViewController () <ENNotebookChooserViewControllerDelegate, UITextFieldDelegate>
@property (nonatomic, strong) UIBarButtonItem * saveButtonItem;
@property (nonatomic, strong) UITextField * titleField;
@property (nonatomic, strong) IBOutlet UITextField * notebookField;
@property (nonatomic, strong) IBOutlet UITextField * tagsField;

@property (nonatomic, strong) NSArray * notebookList;
@property (nonatomic, strong) ENNotebook * currentNotebook;
@end

@implementation ENSaveToEvernoteViewController

CGFloat OnePxHeight() {
    return 1.0/[UIScreen mainScreen].scale;
}

#define kDividerColor [UIColor colorWithRed:210.0/255.0 green:210.0/255.0 blue:210.0/255.0 alpha:1]
#define kPaddingWidth 20

- (void)loadView {
    [super loadView];
    [self setEdgesForExtendedLayout:UIRectEdgeNone];
    [self.view setBackgroundColor:[ENTheme defaultBackgroundColor]];
    [self.navigationController.view setTintColor:[ENTheme defaultTintColor]];
    
    UITextField *titleField = [[UITextField alloc] initWithFrame:CGRectZero];
    titleField.translatesAutoresizingMaskIntoConstraints = NO;
    [titleField setFont:[UIFont systemFontOfSize:18.0]];
    [titleField setTextColor:[UIColor colorWithRed:0.51 green:0.51 blue:0.51 alpha:1]];
    UIView *paddingView1 = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kPaddingWidth, 0)];
    titleField.leftView = paddingView1;
    titleField.leftViewMode = UITextFieldViewModeAlways;
    [self.view addSubview:titleField];
    self.titleField = titleField;
    
    UIView *divider1 = [[UIView alloc] initWithFrame:CGRectZero];
    divider1.translatesAutoresizingMaskIntoConstraints = NO;
    [divider1 setBackgroundColor: kDividerColor];
    [self.view addSubview:divider1];
    
    UITextField *tagsField = [[UITextField alloc] initWithFrame:CGRectZero];
    tagsField.translatesAutoresizingMaskIntoConstraints = NO;
    UIView *paddingView2 = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kPaddingWidth, 0)];
    tagsField.leftView = paddingView2;
    tagsField.leftViewMode = UITextFieldViewModeAlways;
    [self.view addSubview:tagsField];
    self.tagsField = tagsField;
    
    UIView *divider2 = [[UIView alloc] initWithFrame:CGRectZero];
    divider2.translatesAutoresizingMaskIntoConstraints = NO;
    [divider2 setBackgroundColor:kDividerColor];
    [self.view addSubview:divider2];
    
    UITextField *notebookField = [[UITextField alloc] initWithFrame:CGRectZero];
    notebookField.translatesAutoresizingMaskIntoConstraints = NO;
    UIView *paddingView3 = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kPaddingWidth, 0)];
    notebookField.leftView = paddingView3;
    notebookField.leftViewMode = UITextFieldViewModeAlways;
    [self.view addSubview:notebookField];
    self.notebookField = notebookField;
    
    UIView *divider3 = [[UIView alloc] initWithFrame:CGRectZero];
    divider3.translatesAutoresizingMaskIntoConstraints = NO;
    [divider3 setBackgroundColor:kDividerColor];
    [self.view addSubview:divider3];
    
    NSString *format = [NSString stringWithFormat:@"V:[titleField(%f)][divider1(%f)][tagsField(>=%f)][divider2(%f)][notebookField(%f)][divider3(%f)]", kTitleViewHeight, OnePxHeight(), kTagsViewHeight, OnePxHeight(), kNotebookViewHeight, OnePxHeight()];
    [self.view addConstraints: [NSLayoutConstraint constraintsWithVisualFormat:format
                                                                       options:NSLayoutFormatAlignAllLeft | NSLayoutFormatAlignAllRight
                                                                       metrics:nil
                                                                         views:NSDictionaryOfVariableBindings(titleField, divider1, tagsField, divider2, notebookField, divider3)]];
    [self.view addConstraints: [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[titleField]|"
                                                                       options:0
                                                                       metrics:nil
                                                                         views:NSDictionaryOfVariableBindings(titleField)]];
    
    self.navigationItem.title = NSLocalizedString(@"Save To Evernote", @"Save To Evernote");
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel:)];
    
    self.saveButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Save", @"Save") style:UIBarButtonItemStylePlain target:self action:@selector(save:)];
    self.navigationItem.rightBarButtonItem = self.saveButtonItem;
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStylePlain target:nil action:nil];
    
    self.saveButtonItem.enabled = NO;
    self.titleField.text = [self.delegate defaultNoteTitleForViewController:self];
    if (self.titleField.text.length == 0) {
        [self.titleField setPlaceholder:NSLocalizedString(@"Add Title", @"Add Title")];
    }
    self.notebookField.delegate = self;
    self.tagsField.placeholder = NSLocalizedString(@"Add Tag", @"Add Tag");
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
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
        self.saveButtonItem.enabled = YES;
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
    [self.navigationController pushViewController:chooser animated:YES];
}

#pragma mark - Actions

- (void)save:(id)sender
{
    // Fetch the note we've built so far.
    ENNote * note = [self.delegate noteForViewController:self];

    // Populate the metadata fields we offered.
    note.title = self.titleField.text;
    if (note.title.length == 0) {
        note.title = NSLocalizedString(@"Untitled note", @"Untitled note");
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

- (void)cancel:(id)sender
{
    [self.delegate viewController:self didFinishWithSuccess:NO];
}

#pragma mark - ENNotebookChooserViewControllerDelegate

- (void)notebookChooser:(ENNotebookChooserViewController *)chooser didChooseNotebook:(ENNotebook *)notebook
{
    self.currentNotebook = notebook;
    [self updateCurrentNotebookDisplay];
    [self.navigationController popViewControllerAnimated:YES];
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
