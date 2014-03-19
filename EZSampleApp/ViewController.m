//
//  ViewController.m
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 2/25/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import "ViewController.h"
#import "ENNotebook.h"
#import "ENSession.h"
#import "ENNote.h"
#import "ENResource.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)loadView
{
    UIView * view = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    view.backgroundColor = [UIColor orangeColor];
    self.view = view;
    
    // Share button.
    UIButton * button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [button setTitle:@"Test Activity" forState:UIControlStateNormal];
    [button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    button.frame = CGRectMake(0, 0, 200, 200);
    [button addTarget:self action:@selector(testActivity:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)viewDidAppear:(BOOL)animated
{
    [[ENSession sharedSession] setDefaultNotebookName:@"My Test Notebook"];
    [[ENSession sharedSession] authenticateWithViewController:self completion:^(NSError * authError) {
        if (!authError) {
            NSLog(@"Auth succeeded, w/username '%@' in biz '%@'", [[ENSession sharedSession] userDisplayName], [[ENSession sharedSession] businessName]);
//            [self uploadToBusinessAndShare];
        } else {
            NSLog(@"Auth failed: %@", authError);
        }
    }];
}

- (void)uploadTestNote
{
    NSMutableAttributedString * attrString = [[NSMutableAttributedString alloc] initWithString:@"The quick brown fox jumps over the lazy doge."];
    [attrString addAttribute:NSForegroundColorAttributeName value:[UIColor orangeColor] range:NSMakeRange(0, attrString.length)];
    ENNote * note = [[ENNote alloc] initWithAttributedString:attrString];
    note.title = @"Noteref test!";
    ENResource * image = [[ENResource alloc] initWithImage:[UIImage imageNamed:@"quantizetexture.png"]];
    [note addResource:image];
    ENNoteRef * replaceRef = [ENNoteRef noteRefFromData:[[NSUserDefaults standardUserDefaults] objectForKey:@"evernoteNoteRefTest"]];
    [[ENSession sharedSession] uploadNote:note
                                   policy:replaceRef ? ENSessionUploadPolicyReplaceOrCreate : ENSessionUploadPolicyCreate
                              replaceNote:replaceRef
                                 progress:nil completion:^(ENNoteRef * noteRef, NSError *uploadNoteError) {
                                     NSLog(@"result note %@, error %@", noteRef,uploadNoteError);
                                     [[NSUserDefaults standardUserDefaults] setObject:[noteRef asData] forKey:@"evernoteNoteRefTest"];
                                     [[NSUserDefaults standardUserDefaults] synchronize];
                                 }];
}

- (void)listAllNotebooks
{
    [[ENSession sharedSession] listNotebooksWithHandler:^(NSArray *notebooks, NSError *listNotebooksError) {
        NSLog(@"Retrieved %d notebooks", (int)notebooks.count);
        for (ENNotebook * notebook in notebooks) {
            NSLog(@"%@", notebook);
        }
    }];
}

- (void)uploadToBusinessAndShare
{
    [[ENSession sharedSession] listNotebooksWithHandler:^(NSArray *notebooks, NSError *listNotebooksError) {
        NSLog(@"Retrieved %d notebooks", (int)notebooks.count);
        ENNotebook * notebookToUse = nil;
        for (ENNotebook * notebook in notebooks) {
            if ([notebook.name isEqualToString:@"benvernote's Business Notebook"]) {
                notebookToUse = notebook;
                break;
            }
        }
        
        // Save a note to this notebook
        ENNote * note = [[ENNote alloc] initWithString:@"Check out my cool note 2"];
        note.title = @"Save & Share to Business";
        note.notebook = notebookToUse;
        [[ENSession sharedSession] uploadNote:note completion:^(ENNoteRef *noteRef, NSError *uploadNoteError) {
            if (noteRef) {
                [[ENSession sharedSession] shareNoteRef:noteRef completion:^(NSString *url, NSError *shareNoteError) {
                    if (url) {
                        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
                    }
                }];
            }
        }];
    }];
}

- (void)deleteTestNote
{
    ENNoteRef * deleteRef = [ENNoteRef noteRefFromData:[[NSUserDefaults standardUserDefaults] objectForKey:@"evernoteNoteRefTest"]];
    if (deleteRef) {
        [[ENSession sharedSession] deleteNoteRef:deleteRef completion:^(NSError *deleteNoteError) {
            NSLog(@"delete error: %@", deleteNoteError);
        }];
    }
}

- (void)testActivity:(id)sender
{
    ENEvernoteActivity * activity = [[ENEvernoteActivity alloc] init];
    activity.noteTitle = @"Medium Cheddar Cheese";
    
    NSString * content1 = @"This is some content";
    NSString * content2 = @"This is some other content!";
    UIImage * image = [UIImage imageNamed:@"quantizetexture.png"];
    
    UIActivityViewController * avc = [[UIActivityViewController alloc] initWithActivityItems:@[image,content1,content2] applicationActivities:@[activity]];
    [self presentViewController:avc animated:YES completion:nil];
}

@end
