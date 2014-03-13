//
//  ENNoteRefInternal.h
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 3/13/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#ifndef evernote_sdk_ios_ENNoteRefInternal_h
#define evernote_sdk_ios_ENNoteRefInternal_h

typedef NS_ENUM(NSInteger, ENNoteRefType) {
    ENNoteRefTypePersonal,
    ENNoteRefTypeBusiness,
    ENNoteRefTypeShared
};

@interface ENNoteRef ()
@property (nonatomic, assign) ENNoteRefType type;
@property (nonatomic, copy) NSString * guid;
@property (nonatomic, strong) ENLinkedNotebookRef * linkedNotebook;
@end

#endif
