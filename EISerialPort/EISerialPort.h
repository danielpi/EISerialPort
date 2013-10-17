//
//  EISerialPort.h
//  SerialCocoaFive
//
//  Created by Daniel Pink on Thu Oct 02 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#include <CoreFoundation/CoreFoundation.h>

#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <paths.h>
#include <termios.h>
#include <sysexits.h>
#include <sys/param.h>
#include <sys/event.h>
#include <sys/ioctl.h>

#include <IOKit/IOKitLib.h>
#include <IOKit/serial/IOSerialKeys.h>
#include <IOKit/IOBSD.h>

#include <dispatch/dispatch.h>

typedef enum {	
	EIStopbitsOne = 1,
	EIStopbitsTwo = 2
} EISerialStopBits;

typedef enum {	
	EIParityNone = 0,
	EIParityOdd = 1,
	EIParityEven = 2
} EISerialParity;

typedef enum {
    EIFlowControlNone = 0,
    EIFlowControlXonXoff = 1,
    EIFlowControlHardware = 2
} EISerialFlowControl;

typedef enum {
    EIFiveDataBits = 0,
    EISixDataBits = 1,
    EISevenDataBits = 2,
    EIEightDataBits = 3
} EISerialDataBits;


@protocol EISerialDelegate

@optional

- (void) serialPortDidOpen;
- (void) serialPortFailedToOpen; // Should this return an NSError???
- (void) serialPortDidChangeSettings;
- (void) serialPortDidReceiveData:(NSData *)data;
- (void) serialPortDidClose;

@end


@interface EISerialPort : NSObject {
    NSException *serialException;
}

@property (readonly, strong) NSString *name;
@property (readonly, strong) NSString *path;
@property (readonly, strong) NSString *status;

@property (readwrite) int fileDescriptor;
@property (readwrite) io_object_t matchedMachPort;
@property (readwrite) struct __block termios modifiedAttributes;
@property (readwrite) struct __block termios originalAttributes;

@property (readwrite, unsafe_unretained) id delegate;
@property (readwrite) dispatch_queue_t delegateQueue;

@property (readwrite) BOOL isOpen;
@property (readwrite) BOOL writingCancelled;

@property (readwrite) dispatch_queue_t writeQueue;
@property (readwrite) dispatch_queue_t readQueue;
@property (readwrite) dispatch_source_t readSource;
@property (readwrite) uint writeSuspendCount;
@property (readwrite) uint idealBufferSize;

@property (atomic, retain, readwrite) NSTimer *timer;


// You shouldn't directly initialise your own EISerialPort Object.
// Get one from the EISerialPortManager instead.
- (id) initWithIOObject:(io_object_t) iOObject;

- (BOOL) isEqual:(id)other;
- (BOOL) isEqualToSerialPort:(EISerialPort *)aSerialPort;
- (NSUInteger) hash;

- (dispatch_queue_t) delegateQueue;
- (void) setDelegateQueue:(dispatch_queue_t)newDelegateQueue;

- (NSString *) status;
- (void) setStatus:(NSString *) newStatus;

- (NSString *) description;
- (NSString *) byteToBinaryString:(uint16)aByte;

- (void) open;
- (void) openByBlocking;
- (void) close;

// Attribute settings.
// Remember to call startModifyingAttributes before modifying the
// ports attributes and to call endModifyingAttributes when finished.
- (void) startModifyingAttributes;
- (void) finishModifyingAttributes;
- (void) resetAttributesToOriginal;

- (NSNumber *) baudRate;
- (void) setBaudRate:(NSNumber *)baudRate;
+ (NSArray *) standardBaudRates;

- (EISerialFlowControl) flowControl;
- (void) setFlowControl:(EISerialFlowControl)method;

- (EISerialParity) parity;
- (void) setParity:(EISerialParity)parity;

- (uint) minBytesPerRead;
- (void) setMinBytesPerRead:(uint)min;

- (uint) timeout;
- (void) setTimeout:(uint)time;

- (void) setRawMode;

- (void) setBlockingReads:(BOOL)blocking;

- (void) flushIO;

- (NSNumber *) stopBits;
- (void) setStopBits:(NSNumber *)stopBits;
- (void) setOneStopBit;
- (void) setTwoStopBits;

- (EISerialDataBits) dataBits;
- (void) setDataBits:(EISerialDataBits)dataBits;

- (void) printSerialPortAttributes:(struct termios)attributes;
- (float) calculateDelayPerByte:(struct termios)attributes;

// Writing to the serial port
- (void) writeString:(NSString *)aString;
- (void) writeData:(NSData *)dataToSend;
- (void) writeDelay:(uint)uSleep;
- (void) sendBreak;

//Controlling the write queue and buffer
- (void) setupReceiveThread;
- (void) resumeWriting;
- (void) suspendWriting;
- (void) cancelWrites;

// Controlling the read queue
- (void) resumeReading;
- (void) suspendReading;

@end

extern NSString *EISerialPortStatusChange;
extern NSString *EISerialTextDidArrive;


