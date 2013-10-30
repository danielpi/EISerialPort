//
//  EISerialTextView.h
//  Weetbix
//
//  Created by Daniel Pink on 10/01/12.
//  Copyright (c) 2012 Electronic Innovations. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class EISerialPort;


@protocol EISerialTextViewDelegate

@optional
- (void)receivedDataFromUser:(NSData *)data;
- (void)receivedStringFromUser:(NSString *)string;
@end


@interface EISerialTextView : NSTextView

@property (readwrite, weak) id delegate;
@property (readwrite, strong) NSColor *caretColor;

- (void)keyDown:(NSEvent *)theEvent;
- (void)paste:(id)sender;

- (void)appendCharacters:(NSData *)characters;
- (void)appendString:(NSString *)aString;

// EISerialDelegate
//- (void) serialPortDidReceiveData:(NSData *)data;
//- (void) serialPortDidSendData:(NSData *)data;
@end
