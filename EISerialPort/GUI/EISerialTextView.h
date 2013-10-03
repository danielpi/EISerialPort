//
//  EISerialTextView.h
//  Weetbix
//
//  Created by Daniel Pink on 10/01/12.
//  Copyright (c) 2012 Electronic Innovations. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "EISerialPort.h"
#include <stdlib.h>
#include <math.h>
//#import "OverlayView.h"


@interface EISerialTextView : NSTextView <EISerialDelegate>
{
    __weak EISerialPort *serialPort;
    NSCharacterSet *controlCharactersSet;
    NSRange terminalInsertionPoint;
    uint numBytesToSend;
    uint numBytesRemaining;
    //OverlayView *overlayView;
    NSFileHandle *outputFile;
}

@property (weak) EISerialPort *serialPort;
@property (strong) NSCharacterSet *controlCharactersSet;
@property NSRange terminalInsertionPoint;
@property (readwrite, strong) NSDate *xoffTime;
@property (readwrite, strong) NSTimer *scrollCoalesenceTimer;
@property (readwrite, atomic) BOOL *pauseDisplay;

- (void) keyDown:(NSEvent *)theEvent;
- (void) serialPortReadData:(NSDictionary *)dataDictionary;
- (NSString *) processStringPortion:(NSString *)inputString;
- (void) willWriteData:(NSData *)data ofLength:(uint)len;
- (void) didPartialWriteData:(NSData *)sentData ofLength:(uint)len;
- (void) didWriteData:(NSData *)sentData ofLength:(uint)len;
- (void) didCancelWriteDataWithoutSendingRemainingData:(NSData *)unsentData;


@end

extern NSString *EIDidPartialWriteData;