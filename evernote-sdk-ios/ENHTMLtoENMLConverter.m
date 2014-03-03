//
//  ENHTMLtoENMLConverter.m
//  CoreNote
//
//  Created by Steve White on 10/24/11.
//  Copyright (c) 2011 Evernote Corporation. All rights reserved.
//

#import "ENHTMLtoENMLConverter.h"
#import "ENConstants.h"

#define AppLogDebug NSLog
#define AppLogInfo NSLog
#define AppLogError NSLog

@implementation ENHTMLtoENMLConverter

@synthesize delegate = _delegate;

#pragma mark -
#pragma mark
- (ENMLWriter *) enmlWriter {
  if (_enmlWriter == nil) {
    _enmlWriter = [[ENMLWriter alloc] initWithDelegate:self];
  }
  return _enmlWriter;
}

- (ENXMLSaxParser *) htmlParser {
  if (_htmlParser == nil) {
    _htmlParser = [[ENXMLSaxParser alloc] init];
    _htmlParser.isHTML = YES;
    _htmlParser.delegate = self;
  }
  return _htmlParser;
}

- (NSString *) enmlFromContentsOfHTMLFile:(NSString *)htmlFile {
  _enml = [[NSMutableString alloc] init];
  [[self htmlParser] parseContentsOfFile:htmlFile];
  return [NSString stringWithString:_enml];
}

- (NSString *) enmlFromHTMLContent:(NSString *)htmlContent {
  _enml = [[NSMutableString alloc] init];
  [[self htmlParser] parseContents:htmlContent];
  return [NSString stringWithString:_enml];
}

#pragma mark -
#pragma mark
- (void) writeData:(NSData *)data {
  [[self htmlParser] appendData:data];
}

- (void) finish {
  [[self htmlParser] finalizeParser];
//  [_delegate enmlConverterDidFinish:self];
}

- (void) cancel {
  [[self htmlParser] stopParser];
  [[self htmlParser] setDelegate:nil];
}

#pragma mark -
#pragma mark ENXMLSaxParser delegates
- (void) parserDidStartDocument:(ENXMLSaxParser *)parser {
  id<ENHTMLtoENMLConverterDelegate> strongDelegate = _delegate;
  if (strongDelegate != nil) {
    [strongDelegate htmlConverterDidStart:self];
  }
}

- (void) parserDidEndDocument:(ENXMLSaxParser *)parser {
  [_enmlWriter endDocument];
}

- (void) parser:(ENXMLSaxParser *)parser didStartElement:(NSString *)elementName attributes:(NSDictionary *)attrDict {
  if (_skipCount > 0) {
    _skipCount++;
    return;
  }

  NSString *tag = [elementName lowercaseString];
  if (_inHTMLBody == NO) {
    if ([tag isEqualToString:@"body"] == YES) {
      NSMutableDictionary *noteAttributes = [NSMutableDictionary dictionaryWithDictionary:attrDict];
      [noteAttributes removeObjectForKey:@"class"];
      [[self enmlWriter] startDocumentWithAttributes:attrDict];
      _inHTMLBody = YES;
    }
    return;
  }
  
  NSArray *classNames = [[attrDict objectForKey:@"class"] componentsSeparatedByString:@" "];
  if ([classNames containsObject:ENHTMLClassIgnore] == YES) {
    _skipCount++;
  }
  else {
    BOOL success = [_enmlWriter startElement:tag
                              withAttributes:attrDict];
    if (success == NO) {
      AppLogDebug(@"startElement:%@ returned NO, skipping element and children", tag);
      _skipCount++;
    }
  }
}

- (void) parser:(ENXMLSaxParser *)parser didEndElement:(NSString *)elementName {
  if (_skipCount > 0) {
    _skipCount--;
    return;
  }
  
  if (_inHTMLBody == NO) {
    return;
  }
  if ([[elementName lowercaseString] isEqualToString:@"body"] == YES) {
    _inHTMLBody = NO;
    return;
  }
  
  [_enmlWriter endElement];
}

- (void) parser:(ENXMLSaxParser *)parser foundCharacters:(NSString *)characters {
  if (_inHTMLBody == NO || _skipCount > 0) {
    return;
  }

  [_enmlWriter writeString:characters];
}

- (void) parser:(ENXMLSaxParser *)parser didFailWithError:(NSError *)error {
  id<ENHTMLtoENMLConverterDelegate> strongDelegate = _delegate;
  if (strongDelegate != nil) {
    [strongDelegate htmlConverter:self didFailWithError:error];
  }  
}

#pragma mark -
#pragma mark ENXMLWriter delegates
- (void) xmlWriter:(ENXMLWriter *)writer didGenerateData:(NSData*)data {
  NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  id<ENHTMLtoENMLConverterDelegate> strongDelegate = _delegate;
  if (strongDelegate != nil) {
    [strongDelegate htmlConverter:self didGenerateString:string];
  }
  else {
    [_enml appendString:string];
  }
}

- (void) xmlWriterDidEndWritingDocument:(ENXMLWriter *)writer {
  id<ENHTMLtoENMLConverterDelegate> strongDelegate = _delegate;
  if (strongDelegate != nil) {
    [strongDelegate htmlConverterDidFinish:self];
  }
}

@end
