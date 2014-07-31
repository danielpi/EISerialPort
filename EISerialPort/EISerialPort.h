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

@class EISerialPort;

typedef enum {	
	EIStopbitsOne           = 0,
	EIStopbitsTwo           = 1
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
    EIDataBitsFive          = 0,
    EIDataBitsSix           = 1,
    EIDataBitsSeven         = 2,
    EIDataBitsEight         = 3
} EISerialDataBits;

typedef enum {
    EIUnknownSerialPort     = 0,
    EIBluetoothSerialPort   = 1,
    EIUSBSerialPort         = 2,
} EISerialPortType;



@protocol EISerialDelegate <NSObject>

@optional

- (BOOL) serialPortShouldOpen:(EISerialPort *)port;
- (void) serialPortWillOpen:(EISerialPort *)port;
- (void) serialPortDidOpen:(EISerialPort *)port;

- (BOOL) serialPortShouldClose:(EISerialPort *)port;
- (void) serialPortWillClose:(EISerialPort *)port;
- (void) serialPortDidClose:(EISerialPort *)port;

- (BOOL) serialPortShouldChangeSettings:(EISerialPort *)port;
- (void) serialPortWillChangeSettings:(EISerialPort *)port;
- (void) serialPortDidChangeSettings:(EISerialPort *)port;

- (void) serialPort:(EISerialPort *)port experiencedAnError:(NSError *)anError;

- (void) serialPort:(EISerialPort *)port didReceiveData:(NSData *)data;

- (BOOL) serialPort:(EISerialPort *)port shouldSendData:(NSData *)data;
- (void) serialPort:(EISerialPort *)port willSendData:(NSData *)data;
- (void) serialPort:(EISerialPort *)port didSendData:(NSData *)data;

- (void) serialPortPinsDidChangeState:(EISerialPort *)port;
@end


@interface EISerialPort : NSObject

@property (readonly, strong) NSString *name;
@property (readonly, strong) NSString *path;
@property (readonly) EISerialPortType type;
@property (readonly, getter = isOpen) BOOL open;
@property (readonly, getter = isCancelled) BOOL cancelled; // What is cancelled? Writing I think

@property (readwrite, weak, nonatomic) id delegate;

@property (readwrite) NSNumber *baudRate;
@property (readwrite) EISerialParity parity;
@property (readwrite) EISerialStopBits stopBits;
@property (readwrite) EISerialDataBits dataBits;
@property (readwrite) EISerialFlowControl flowControl;
@property (readwrite, nonatomic) NSNumber *latency; // Latency is measured in microseconds

@property (readonly) NSArray *standardBaudRates;
@property (readonly) NSArray *baudRateLabels;
@property (readonly) NSArray *parityLabels;
@property (readonly) NSArray *stopBitLabels;
@property (readonly) NSArray *dataBitLabels;
@property (readonly) NSArray *flowControlLabels;

@property (readwrite) uint minBytesPerRead;
@property (readwrite) uint timeout;

@property (readwrite) BOOL RTS;
@property (readwrite) BOOL DTR;
@property (readonly) BOOL CTS;
@property (readonly) BOOL DSR;
@property (readonly) BOOL DCD;


// You shouldn't directly initialise your own EISerialPort Object.
// Get one from the EISerialPortManager instead.
- (id) initWithIOObject:(io_object_t) iOObject;

- (NSString *) description;
+ (NSArray *) standardBaudRates;    // Returns an array of 

- (void) addDelegate:(id)aDelegate;     // This allows for multiple broadcast of data that comes in from the serial port
- (void) removeDelegate:(id)aDelegate;

- (void) open;
- (void) close;

// Writing to the serial port
- (void) sendString:(NSString *)aString;
- (void) sendString:(NSString *)aString inChunksSplitBy:(NSString *)delimiter;
- (void) sendString:(NSString *)aString inChunksSplitBy:(NSString *)delimiter replaceDelimiterWith:(NSString *)lineEnding;
- (void) sendKeyCode:(unsigned short)keyCode;
- (void) sendData:(NSData *)dataToSend;
- (void) sendData:(NSData *)dataToSend inChunksOfSize:(NSNumber *)chunkSize;
- (void) delayTransmissionForDuration:(NSTimeInterval)seconds;
- (void) sendBreak;

- (void) cancelCurrentTransmission;

@end

