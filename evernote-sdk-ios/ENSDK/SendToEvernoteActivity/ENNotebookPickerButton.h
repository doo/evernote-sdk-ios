//
//  ENNotebookPickerButton.h
//  evernote-sdk-ios
//
//  Created by Eric Cheng on 4/18/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ENNotebookPickerButton : UIButton

@property (nonatomic, assign) BOOL isBusinessNotebook;
@property (nonatomic, strong) UIImageView *discloureIndicator;

@end
