//
//  ENResource.m
//  evernote-sdk-ios
//
//  Created by Ben Zotto on 2/25/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import "ENSDKPrivate.h"
#import "EvernoteSDK.h"
#import "NSData+EvernoteSDK.h"

@interface ENResource ()
@property (nonatomic, strong) NSString * guid;
@property (nonatomic, strong) NSData * data;
@property (nonatomic, copy) NSString * mimeType;
@property (nonatomic, copy) NSString * filename;
@property (nonatomic, strong) NSData * dataHash;
@end

@implementation ENResource
- (id)initWithData:(NSData *)data mimeType:(NSString *)mimeType filename:(NSString *)filename
{
    self = [super init];
    if (self) {
        self.data = data;
        self.mimeType = mimeType;
        self.filename = filename;
    }
    return self;
}

- (id)initWithData:(NSData *)data mimeType:(NSString *)mimeType
{
    return [self initWithData:data mimeType:mimeType filename:nil];
}

- (id)initWithImage:(UIImage *)image
{
    // Encode both ways and use the smaller of the two. Ties goes to (lossless) PNG.
    NSData * pngData = UIImagePNGRepresentation(image);
    NSData * jpegData = UIImageJPEGRepresentation(image, 0.7);
    if (jpegData.length < pngData.length) {
        pngData = nil;
        return [self initWithData:jpegData mimeType:@"image/jpeg"];
    } else {
        jpegData = nil;
        return [self initWithData:pngData mimeType:@"image/png"];
    }
}

- (NSData *)data
{
    return _data;
}

- (NSString *)mimeType
{
    return _mimeType;
}

- (NSString *)filename
{
    return _filename;
}

- (NSData *)dataHash
{
    // Compute and cache the hash value.
    if (!_dataHash && self.data.length > 0) {
        _dataHash = [self.data enmd5];
    }
    return _dataHash;
}

- (EDAMResource *)EDAMResource
{
    EDAMResource * resource = [[EDAMResource alloc] init];
    resource.guid = self.guid;
    if (!resource.guid && self.data) {
        resource.data = [[EDAMData alloc] initWithBodyHash:self.dataHash size:(int32_t)self.data.length body:self.data];
    }
    resource.mime = self.mimeType;
    if (self.filename) {
        EDAMResourceAttributes * attributes = [[EDAMResourceAttributes alloc] init];
        attributes.fileName = self.filename;
        resource.attributes = attributes;
    }
    return resource;
}
@end
