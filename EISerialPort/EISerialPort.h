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
    EIFiveDataBits          = 0,
    EISixDataBits           = 1,
    EISevenDataBits         = 2,
    EIEightDataBits         = 3
} EISerialDataBits;

typedef enum {
    EIUnknownSerialPort     = 0,
    EIBluetoothSerialPort   = 1,
    EIUSBSerialPort         = 2,
} EISerialPortType;

@protocol EISerialDelegate

@optional
- (void) serialPortDidOpen;
- (void) serialPortExperiencedAnError:(NSError *)anError;
- (void) serialPortDidChangeSettings;
- (void) serialPortDidReceiveData:(NSData *)data;
- (void) serialPortDidSendData:(NSData *)data;
- (void) serialPortDidClose;
- (void) serialPortPinsDidChangeState;

//- (void) serialPortDidOpen:(EISerialPort *)port;
//- (void) serialPort:(EISerialPort *)port experiencedAnError:(NSError *)anError;
//- (void) serialPortDidChangeSettings:(EISerialPort *)port ;
//- (void) serialPort:(EISerialPort *)port didReceiveData:(NSData *)data;
//- (void) serialPort:(EISerialPort *)port didSendData:(NSData *)data;
//- (void) serialPortDidClose:(EISerialPort *)port;
//- (void) serialPortPinsDidChangeState:(EISerialPort *)port;
@end


@interface EISerialPort : NSObject

@property (readonly, strong) NSString *name;
@property (readonly, strong) NSString *path;
@property (readonly) EISerialPortType type;
@property (readonly, getter = isOpen) BOOL open;
@property (readonly, getter = isCancelled) BOOL cancelled;

@property (readwrite, weak, nonatomic) id delegate;

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

- (void) addDelegate:(id)aDelegate;
- (void) removeDelegate:(id)aDelegate;

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

- (void) cancelCurrentTransmission;

@end

