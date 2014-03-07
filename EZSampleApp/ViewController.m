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
    [[ENSession sharedSession] setDefaultNotebookName:@"Biiger"];
    [[ENSession sharedSession] authenticateWithViewController:self handler:^(NSError * authError) {
        if (!authError) {
            NSLog(@"Auth succeeded, w/username '%@' in biz '%@'", [[ENSession sharedSession] userDisplayName], [[ENSession sharedSession] businessName]);
            
            [[ENSession sharedSession] listNotebooksWithHandler:^(NSArray *notebooks, NSError *listNotebooksError) {
                for (ENNotebook * notebook in notebooks) {
                    NSLog(@"NOTEBOOK: %@ %@ %@", notebook.name, notebook.isLinked ? @"L" : @"", notebook.allowsWriting ? @"RW" : @"RO");
                    if ([notebook.name isEqualToString:@"mys Business Notebook"]) {
                        NSMutableAttributedString * attrString = [[NSMutableAttributedString alloc] initWithString:@"The quick brown fox jumps over the lazy doge."];
                        [attrString addAttribute:NSForegroundColorAttributeName value:[UIColor orangeColor] range:NSMakeRange(0, attrString.length)];
                        ENNote * note = [[ENNote alloc] initWithAttributedString:attrString];
                        note.title = @"My BUSINESS Note";
                        note.notebook = notebook;
                        ENResource * image = [[ENResource alloc] initWithImage:[UIImage imageNamed:@"quantizetexture.png"]];
                        [note addResource:image];
                        NSString * replaceId = nil; //[[NSUserDefaults standardUserDefaults] objectForKey:@"evernoteNote"];
                        [[ENSession sharedSession] uploadNote:note
                                                       policy:replaceId ? ENSessionUploadPolicyReplaceOrCreate : ENSessionUploadPolicyCreate
                                                replaceNoteId:replaceId
                                                     progress:nil completion:^(NSString *noteId, NSError *uploadNoteError) {
                                                         NSLog(@"result note %@, error %@", noteId,uploadNoteError);
                                                         [[NSUserDefaults standardUserDefaults] setObject:noteId forKey:@"evernoteNote"];
                                                     }];

                    }
                }
            }];
            
        } else {
            NSLog(@"Auth failed: %@", authError);
        }
    }];
}

@end
