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
            [self listAllNotebooks];
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
                                 }];
}

- (void)listAllNotebooks
{
    [[ENSession sharedSession] listNotebooksWithHandler:^(NSArray *notebooks, NSError *listNotebooksError) {
        NSLog(@"Retrieved %d notebooks", notebooks.count);
        for (ENNotebook * notebook in notebooks) {
            NSLog(@"%@", notebook);
        }
    }];
}

@end
