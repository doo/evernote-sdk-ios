//
//  ENHTMLtoENMLConverter.h
//  CoreNote
//
//  Created by Steve White on 10/24/11.
//  Copyright (c) 2011 Evernote Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ENMLWriter.h"
#import "ENXMLSaxParser.h"

@protocol ENHTMLtoENMLConverterDelegate;

@interface ENHTMLtoENMLConverter : NSObject<ENXMLSaxParserDelegate, ENXMLWriterDelegate> {
  ENXMLSaxParser *_htmlParser;
  ENMLWriter *_enmlWriter;
  
  NSMutableString *_enml;
  __weak id<ENHTMLtoENMLConverterDelegate> _delegate;
  
  BOOL _inHTMLBody;
  int _skipCount;
}

@property (weak, nonatomic) id<ENHTMLtoENMLConverterDelegate> delegate;

- (NSString *) enmlFromContentsOfHTMLFile:(NSString *)htmlFile;
- (NSString *) enmlFromHTMLContent:(NSString *)htmlContent;

- (void) writeData:(NSData *)data;
- (void) finish;
- (void) cancel;

@end

@protocol ENHTMLtoENMLConverterDelegate <NSObject>
- (void) htmlConverterDidStart:(ENHTMLtoENMLConverter *)converter;
- (void) htmlConverterDidFinish:(ENHTMLtoENMLConverter *)converter;
- (void) htmlConverter:(ENHTMLtoENMLConverter *)converter didGenerateString:(NSString *)string;
- (void) htmlConverter:(ENHTMLtoENMLConverter *)converter didFailWithError:(NSError *)error;
@end
