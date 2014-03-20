//
//  ENNotebookChooserViewController.m
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 3/20/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import "ENNotebookChooserViewController.h"

@interface ENNotebookChooserViewController ()

@end

@implementation ENNotebookChooserViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
    }
    return self;
}

- (void)viewDidLoad
{
    self.navigationItem.title = @"Notebooks";
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.notebookList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"notebook"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"notebook"];
    }
    
    ENNotebook * notebook = self.notebookList[indexPath.row];
    NSString * displayName = notebook.name;
    if (self.currentNotebook.isBusinessNotebook) {
        displayName = [displayName stringByAppendingString:@" (B)"];
    }
    cell.textLabel.text = displayName;
    
    if ([notebook isEqual:self.currentNotebook]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    ENNotebook * notebook = self.notebookList[indexPath.row];
    [self.delegate notebookChooser:self didChooseNotebook:notebook];
}
@end
