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
    [[ENSession sharedSession] authenticateWithViewController:self complete:^(BOOL success, NSString * localizedError) {
        if (success) {
            NSLog(@"Auth succeeded, w/username '%@'", [[ENSession sharedSession] userDisplayName]);
            ENNote * note = [[ENNote alloc] initWithString:@"Hello World!\n\nThis is the simple SDK."];
            note.title = @"My First Note";
            ENResource * image = [[ENResource alloc] initWithImage:[UIImage imageNamed:@"quantizetexture.png"]];
            [note addResource:image];
            NSString * replaceId = [[NSUserDefaults standardUserDefaults] objectForKey:@"evernoteNote"];
            [[ENSession sharedSession] uploadNote:note
                                    replaceNoteID:replaceId
                                         complete:^(NSString * resultID, NSString * uploadError) {
                                             NSLog(@"result note %@", resultID);
                                             [[NSUserDefaults standardUserDefaults] setObject:resultID forKey:@"evernoteNote"];
            }];
        } else {
            NSLog(@"Auth failed: %@", localizedError);
        }
    }];
}

@end
