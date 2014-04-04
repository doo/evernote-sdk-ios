//
//  ViewController.h
//  SampleNoteApp
//
//  Created by Ben Zotto on 4/3/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController
@property (nonatomic, strong) IBOutlet UIButton * authenticateButton;
@property (nonatomic, strong) IBOutlet UILabel * userNameLabel;

@property (nonatomic, strong) IBOutlet UIView * editorContainer;

@property (nonatomic, strong) IBOutlet UITextView * textView;
@property (nonatomic, strong) IBOutlet UIImageView * imageView;
@property (nonatomic, strong) IBOutlet UIButton * imageButton;

@property (nonatomic, strong) IBOutlet UIButton * saveButton;

- (IBAction)toggleAuthentication:(id)sender;
- (IBAction)toggleImage:(id)sender;
- (IBAction)save:(id)sender;
@end
