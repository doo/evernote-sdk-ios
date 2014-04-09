//
//  ENPreferencesStore.h
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 4/9/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ENPreferencesStore : NSObject
- (id)initWithStoreFilename:(NSString *)filename;
- (id)objectForKey:(NSString *)key;
- (void)setObject:(id)object forKey:(NSString *)key;
- (id)decodedObjectForKey:(NSString *)key;
- (void)encodeObject:(id)object forKey:(NSString *)key;
- (void)save;
- (void)removeAllItems;
@end
