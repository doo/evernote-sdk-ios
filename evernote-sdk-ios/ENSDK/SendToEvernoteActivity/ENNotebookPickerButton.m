//
//  ENNotebookPickerButton.m
//  evernote-sdk-ios
//
//  Created by Eric Cheng on 4/18/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import "ENNotebookPickerButton.h"
#import "ENTheme.h"

#define kTextImageSpace     10.0
#define kRightPadding       30.0

@implementation ENNotebookPickerButton

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        self.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        
        UIImage *dislosureImage = [[UIImage imageNamed:@"UITableNext"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        self.discloureIndicator = [[UIImageView alloc] initWithImage:dislosureImage];
        [self.discloureIndicator setTintColor:[UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:1]];
        
        self.discloureIndicator.center = CGPointMake(CGRectGetMaxX(self.bounds) - 20.0, CGRectGetMidY(self.bounds) - 1.0);
        [self.discloureIndicator setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleTopMargin];
        [self addSubview:self.discloureIndicator];
        
        [self.imageView setTintColor:[ENTheme defaultTintColor]];
    }
    return self;
}

- (CGSize)sizeThatFits:(CGSize)size {
    UIButton *button = [[UIButton alloc] init];
    [button setTitle:self.titleLabel.text forState:UIControlStateNormal];
    [button.titleLabel setFont:[UIFont fontWithName:@"HelveticaNeue-Medium" size:15.0]];
    [button setImage:self.imageView.image forState:UIControlStateNormal];
    CGSize s = [button sizeThatFits:CGSizeMake(0, 0)];
    CGSize t = CGSizeMake(s.width + kRightPadding, s.height);
    return t;
}

- (void)setIsBusinessNotebook:(BOOL)isBusinessNotebook {
    if (_isBusinessNotebook == isBusinessNotebook) return;
    _isBusinessNotebook = isBusinessNotebook;
    if (_isBusinessNotebook) {
        [self setImage:[[UIImage imageNamed:@"Business_icon_filled"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    } else {
        [self setImage:nil forState:UIControlStateNormal];
    }
}

@end
