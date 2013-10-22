//
//  EISerialPort.h
//  SerialCocoaFive
//
//  Created by Daniel Pink on Thu Oct 02 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <IOKit/IOTypes.h>
#import <termios.h>


typedef enum {	
	EIStopbitsOne           = 1,
	EIStopbitsTwo           = 2
} EISerialStopBits;

typedef enum {	
	EIParityNone            = 0,
	EIParityOdd             = 1,
	EIParityEven            = 2
} EISerialParity;

typedef enum {
    EIFlowControlNone       = 0,
    EIFlowControlXonXoff    = 1,
    EIFlowControlHardware   = 2
} EISerialFlowControl;

typedef enum {
    EIFiveDataBits          = 0,
    EISixDataBits           = 1,
    EISevenDataBits         = 2,
    EIEightDataBits         = 3
} EISerialDataBits;


@protocol EISerialDelegate

@optional
- (void) serialPortDidOpen;
- (void) serialPortFailedToOpen; // Should this return an NSError???
- (void) serialPortDidChangeSettings;
- (void) serialPortDidReceiveData:(NSData *)data;
- (void) serialPortDidClose;
- (void) serialPortPinsDidChangeState;
@end


@interface EISerialPort : NSObject

@property (readonly, strong) NSString *name;
@property (readonly, strong) NSString *path;
@property (readonly, getter = isOpen) BOOL open;

@property (readwrite, weak) id delegate;

@property (nonatomic, readwrite) NSNumber *baudRate;
@property (nonatomic, readwrite) EISerialParity parity;
@property (nonatomic, readwrite) EISerialStopBits stopBits;
@property (nonatomic, readwrite) EISerialDataBits dataBits;
@property (nonatomic, readwrite) EISerialFlowControl flowControl;

@property (readonly) NSArray *standardBaudRates;
@property (readonly) NSArray *baudRateLabels;
@property (readonly) NSArray *parityLabels;
@property (readonly) NSArray *stopBitLabels;
@property (readonly) NSArray *dataBitLabels;
@property (readonly) NSArray *flowControlLabels;

@property (nonatomic, readwrite) uint minBytesPerRead;
@property (nonatomic, readwrite) uint timeout;

@property (nonatomic) BOOL RTS;
@property (nonatomic) BOOL DTR;
@property (nonatomic, readonly) BOOL CTS;
@property (nonatomic, readonly) BOOL DSR;
@property (nonatomic, readonly) BOOL DCD;

// You shouldn't directly initialise your own EISerialPort Object.
// Get one from the EISerialPortManager instead.
- (id) initWithIOObject:(io_object_t) iOObject;

- (NSString *) description;
+ (NSArray *) standardBaudRates;

- (void) open;
- (void) close;

// Writing to the serial port
- (void) sendString:(NSString *)aString;
- (void) sendString:(NSString *)aString inChunksSplitBy:(NSString *)delimiter;
- (void) sendString:(NSString *)aString inChunksSplitBy:(NSString *)delimiter replaceDelimiterWith:(NSString *)lineEnding;
- (void) sendData:(NSData *)dataToSend;
- (void) sendData:(NSData *)dataToSend inChunksOfSize:(NSNumber *)chunkSize;
- (void) delayTransmissionForDuration:(NSTimeInterval)seconds;
- (void) sendBreak;
- (void) sendBreakForDuration:(NSTimeInterval)seconds;

- (void) cancelCurrentTransmission;

@end

