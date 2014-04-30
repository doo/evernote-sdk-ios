//
//  ViewController.m
//  SampleNoteApp
//
//  Created by Ben Zotto on 4/3/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import "ViewController.h"
#import "ENSDK.h"

@interface ViewController () <UINavigationControllerDelegate, UIImagePickerControllerDelegate>

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    [self updateInterface];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)toggleAuthentication:(id)sender
{
    if ([[ENSession sharedSession] isAuthenticated]) {
        [[ENSession sharedSession] unauthenticate];
        [self updateInterface];
    } else {
        [[ENSession sharedSession] authenticateWithViewController:self completion:^(NSError *authenticateError) {
            if (authenticateError) {
                UIAlertView * alert = [[UIAlertView alloc] initWithTitle:nil
                                                                 message:@"Could not authenticate"
                                                                delegate:nil
                                                       cancelButtonTitle:nil
                                                       otherButtonTitles:@"OK", nil];
                [alert show];
            }
            
            [self updateInterface];
        }];
    }
}

- (void)updateInterface
{
    if ([[ENSession sharedSession] isAuthenticated]) {
        [self.authenticateButton setTitle:@"Unauthenticate" forState:UIControlStateNormal];
        NSMutableString * displayName = [NSMutableString stringWithString:[[ENSession sharedSession] userDisplayName]];
        if ([[ENSession sharedSession] businessDisplayName]) {
            [displayName appendFormat:@" (%@)", [[ENSession sharedSession] businessDisplayName]];
        }
        self.userNameLabel.text = displayName;
        self.editorContainer.hidden = NO;
    } else {
        [self.authenticateButton setTitle:@"Authenticate" forState:UIControlStateNormal];
        self.userNameLabel.text = @"";
        self.editorContainer.hidden = YES;
    }
    
    if (self.imageView.image) {
        [self.imageButton setTitle:@"Remove image" forState:UIControlStateNormal];
    } else {
        [self.imageButton setTitle:@"Add image" forState:UIControlStateNormal];
    }
}

- (void)clearNote
{
    self.textView.text = @"(Edit me.)";
    self.imageView.image = nil;
    [self updateInterface];
}

- (IBAction)toggleImage:(id)sender
{
    if (self.imageView.image) {
        self.imageView.image = nil;
    } else {
        UIImagePickerController * picker = [[UIImagePickerController alloc] init];
        if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
            picker.sourceType = UIImagePickerControllerSourceTypeCamera;
        } else {
            picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        }
        picker.delegate = self;
        [self presentViewController:picker animated:YES completion:nil];
    }
    [self updateInterface];
}

- (IBAction)save:(id)sender
{
    ENSaveToEvernoteActivity * sendActivity = [[ENSaveToEvernoteActivity alloc] init];
    NSMutableArray * items = [NSMutableArray array];
    if (self.textView.text) {
        [items addObject:self.textView.text];
    }
    if (self.imageView.image) {
        [items addObject:self.imageView.image];
    }
    UIActivityViewController * activityController = [[UIActivityViewController alloc] initWithActivityItems:items
                                                                                      applicationActivities:@[sendActivity]];
    [self presentViewController:activityController animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    self.imageView.image = [info objectForKey:UIImagePickerControllerOriginalImage];
    if (self.imageView.image) {
        [self.imageButton setTitle:@"Remove image" forState:UIControlStateNormal];
    }
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [picker dismissViewControllerAnimated:YES completion:nil];
}
@end
