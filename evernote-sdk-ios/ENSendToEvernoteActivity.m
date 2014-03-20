//
//  ENEvernoteActivity.m
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 3/19/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import "ENSendToEvernoteActivity.h"
#import "ENSendToEvernoteViewController.h"
#import "ENSDK.h"

@interface ENSendToEvernoteActivity () <ENSendToEvernoteViewControllerDelegate>
@property (nonatomic, strong) ENNote * preparedNote;
@property (nonatomic, strong) NSArray * notebooks;
@end

@implementation ENSendToEvernoteActivity
+ (UIActivityCategory)activityCategory
{
    return UIActivityCategoryAction;
}

- (NSString *)activityType
{
    return @"com.evernote.sdk.activity";
}

- (NSString *)activityTitle
{
    return @"Send to Evernote";
}

- (UIImage *)activityImage
{
    return [UIImage imageNamed:@"quantizetexture.png"];
}

- (BOOL)canPerformWithActivityItems:(NSArray *)activityItems
{
    // A prepared ENNote is allowed if it's the only item given.
    if (activityItems.count == 1 && [activityItems[0] isKindOfClass:[ENNote class]]) {
        return YES;
    }

    for (id item in activityItems) {
        if ([item isKindOfClass:[NSString class]] ||
            [item isKindOfClass:[UIImage class]] ||
            [item isKindOfClass:[ENResource class]]) {
            return YES;
        }
    }
    
    return NO;
}

- (void)prepareWithActivityItems:(NSArray *)activityItems
{
    NSMutableArray * strings = [NSMutableArray array];
    NSMutableArray * images = [NSMutableArray array];
    NSMutableArray * resources = [NSMutableArray array];
    
    if (activityItems.count == 1 && [activityItems[0] isKindOfClass:[ENNote class]]) {
        self.preparedNote = activityItems[0];
        return;
    }
    
    for (id item in activityItems) {
        if ([item isKindOfClass:[NSString class]]) {
            [strings addObject:item];
        } else if ([item isKindOfClass:[UIImage class]]) {
            [images addObject:item];
        } else if ([item isKindOfClass:[ENResource class]]) {
            [resources addObject:item];
        }
    }
    
    NSMutableString * content = [NSMutableString string];
    for (NSUInteger i = 0; i < strings.count; i++) {
        if (i > 0) {
            [content appendString:@"\n"];
        }
        [content appendString:strings[i]];
    }
    
    ENNote * note = [[ENNote alloc] initWithString:content];
    
    // Add prebaked resources
    for (ENResource * resource in resources) {
        [note addResource:resource];
    }
    
    // Turn images into resources
    for (UIImage * image in images) {
        ENResource * imageResource = [[ENResource alloc] initWithImage:image];
        [note addResource:imageResource];
    }
    
    self.preparedNote = note;
}

- (UIViewController *)activityViewController
{
    ENSendToEvernoteViewController * s2a = [[ENSendToEvernoteViewController alloc] initWithNibName:@"ENSendToEvernoteViewController" bundle:nil];
    s2a.delegate = self;
    return s2a;
}

#pragma mark - ENSendToEvernoteViewControllerDelegate

- (ENNote *)noteForViewController:(ENSendToEvernoteViewController *)viewController
{
    return self.preparedNote;
}

- (NSString *)defaultNoteTitleForViewController:(ENSendToEvernoteViewController *)viewController
{
    return self.noteTitle;
}

- (void)viewController:(ENSendToEvernoteViewController *)viewController didFinishWithSuccess:(BOOL)success
{
    [self activityDidFinish:success];
}
@end
