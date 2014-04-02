//
//  EvernoteService.h
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 4/1/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#ifndef evernote_sdk_ios_EvernoteService_h
#define evernote_sdk_ios_EvernoteService_h

typedef enum {
    /** No service */
    EVERNOTE_SERVICE_NONE = 0,
    /** Evernote international only */
    EVERNOTE_SERVICE_INTERNATIONAL = 1,
    /** Evernote China only */
    EVERNOTE_SERVICE_YINXIANG = 2,
    /** Evernote international and China services */
    EVERNOTE_SERVICE_BOTH = 3
} EvernoteService;

#endif
