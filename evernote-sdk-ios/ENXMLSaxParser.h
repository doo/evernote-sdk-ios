//
//  ENXMLSaxParser.h
//  Evernote
//
//  Created by Steve White on 11/25/09.
//  Copyright 2009 Evernote Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <libxml/tree.h>

extern NSString * const ENXMLSaxParserErrorDomain;

enum {
  ENXMLSaxParserLibXMLError = 1000,
  ENXMLSaxParserLibXMLFatalError = 1001,
  ENXMLSaxParserConnectionError = 1002,
};

@protocol ENXMLSaxParserDelegate;

@interface ENXMLSaxParser : NSObject {
  id<ENXMLSaxParserDelegate> __weak _delegate;
  xmlParserCtxtPtr _parserContext;
  BOOL _parserHalted;
  BOOL _isHTML;
  NSURLConnection *_urlConnection;
  
  NSArray *_dtds;
}

@property (weak, nonatomic) id<ENXMLSaxParserDelegate> delegate;
@property (assign, nonatomic) BOOL isHTML;

- (BOOL) parseContentsOfURLWithRequest:(NSURLRequest *)request;
- (BOOL) parseContentsOfURL:(NSURL *)url;
- (BOOL) parseContentsOfFile:(NSString *)file;
- (BOOL) parseContents:(NSString *)contents;
- (BOOL) parseData:(NSData *)data;
- (void) appendData:(NSData *)data;
- (void) finalizeParser;
- (void) stopParser;

@end

@protocol ENXMLSaxParserDelegate <NSObject>
@optional
- (void) parserDidStartDocument:(ENXMLSaxParser *)parser;
- (void) parserDidEndDocument:(ENXMLSaxParser *)parser;
- (void) parser:(ENXMLSaxParser *)parser didStartElement:(NSString *)elementName attributes:(NSDictionary *)attrDict;
- (void) parser:(ENXMLSaxParser *)parser didEndElement:(NSString *)elementName;
- (void) parser:(ENXMLSaxParser *)parser foundCharacters:(NSString *)characters;
- (void) parser:(ENXMLSaxParser *)parser foundCDATA:(NSString *)CDATABlock;
- (void) parser:(ENXMLSaxParser *)parser foundComment:(NSString *)comment;
- (void) parser:(ENXMLSaxParser *)parser didFailWithError:(NSError *)error;
@end

