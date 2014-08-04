//
//  EISerialPortThread.m
//  Weetbix
//
//  Created by Daniel Pink on 3/04/13.
//  Copyright (c) 2013 Electronic Innovations. All rights reserved.
//

#import "EISerialPort.h"
#import "EISerialPortError.h"
#include <sys/ioctl.h>
#include <sys/errno.h>

#include <IOKit/IOKitLib.h>
#include <IOKit/serial/IOSerialKeys.h>
#include <IOKit/serial/ioss.h>
#include <IOKit/IOBSD.h>

#include <dispatch/dispatch.h>


@interface EISerialPort ()

@property (readwrite) int fileDescriptor;
@property (readwrite) io_object_t matchedMachPort;
@property (readwrite) __block struct termios modifiedAttributes;
@property (readwrite) __block struct termios originalAttributes;

@property (readwrite, getter = isCancelled) BOOL cancelled;

@property (readwrite) dispatch_queue_t sendQueue;
@property (readwrite) dispatch_queue_t receiveQueue;
@property (readwrite) NSMutableSet *delegates;
@property (atomic, retain, readwrite) NSTimer *timer;
@property (readonly) uint idealBufferSize;

- (void) startModifyingSettings;
- (void) finishModifyingSettings;

- (NSString *) byteToBinaryString:(uint16)aByte;
- (BOOL) openSynchronously:(NSError**)anError;

- (BOOL) isEqual:(id)other;
- (BOOL) isEqualToSerialPort:(EISerialPort *)aSerialPort;
- (NSUInteger) hash;

@end



@implementation EISerialPort


#pragma mark Lifecycle
- (id) initWithIOObject:(io_object_t) iOObject
{
	self = [super init];
    if (self) {
        _open = NO;
        _cancelled = NO;
        _matchedMachPort = iOObject;
        CFTypeRef ioKitReturn;
        
        ioKitReturn = IORegistryEntryCreateCFProperty(_matchedMachPort, CFSTR(kIOTTYDeviceKey), kCFAllocatorDefault, 0);
        _name = [NSString stringWithString:(__bridge_transfer NSString *)ioKitReturn];
        
        ioKitReturn = IORegistryEntryCreateCFProperty(_matchedMachPort, CFSTR(kIOCalloutDeviceKey), kCFAllocatorDefault, 0);
        _path = [NSString stringWithString:(__bridge_transfer NSString *) ioKitReturn];
        
        // Try to look back up the IO Registry tree to see if this port is being run over Bluetooth or USB
        io_object_t parent;
        IORegistryEntryGetParentEntry(_matchedMachPort, kIOServicePlane, &parent);
        CFTypeRef parentClass = IOObjectCopyClass(parent);
        NSString *parentClassString = [NSString stringWithString:(__bridge_transfer NSString *) parentClass];
        NSLog(@"Parent Class:%@",parentClassString);
        
        if ([parentClassString rangeOfString:@"Bluetooth"].location == NSNotFound) {
            io_object_t grandParent;
            IORegistryEntryGetParentEntry(parent, kIOServicePlane, &grandParent);
            CFTypeRef grandParentClass = IOObjectCopyClass(grandParent);
            NSString *grandParentClassString = [NSString stringWithString:(__bridge_transfer NSString *) grandParentClass];
            NSLog(@"Grand Parent Class:%@",grandParentClassString);
            if ([grandParentClassString rangeOfString:@"USB"].location == NSNotFound) {
                _type = EIUnknownSerialPort;
            } else {
                _type = EIUSBSerialPort;
            }
        } else {
            _type = EIBluetoothSerialPort;
        }
        
        _fileDescriptor = -1;
        
        _idealBufferSize = 512;
        
        _sendQueue = dispatch_queue_create("au.com.electronicinnovations.sendQueue", NULL);
        _receiveQueue = dispatch_queue_create("au.com.electronicinnovations.receiveQueue", NULL);
        _timer = [[NSTimer alloc] init];
        _delegates = [[NSMutableSet alloc] init];
    }
    return self;
}

#pragma mark Properties
+ (NSArray *) standardBaudRates
{
    return @[ @2400, @4800, @9600, @19200, @38400, @57600, @115200, @230400, @460800];
}

#pragma mark Comparison
- (BOOL)isEqual:(id)other
{
    if (other == self)
        return YES;
    if (!other || ![other isKindOfClass:[self class]])
        return NO;
    return [self isEqualToSerialPort:other];
}


- (BOOL)isEqualToSerialPort:(EISerialPort *)aSerialPort
{
    if (self == aSerialPort)
        return YES;
    if (![(id)[self name] isEqual:[aSerialPort name]])
        return NO;
    if (![[self name] isEqualToString:[aSerialPort name]])
        return NO;
    return YES;
}


- (NSUInteger)hash
{
    return [[self name] hash];
}

#pragma mark NSObject
- (NSString *) description
{
    NSString *theDescription;
    NSString *openOrClosed = @"closed";
    
    if (self.isOpen) { openOrClosed = @"open"; }
    
    NSArray *dataBitsLabels = @[ @"5", @"6", @"7", @"8"];
    NSArray *parityLabels = @[ @"N", @"O", @"E"];
    NSArray *stopBitsLabels = @[ @"1", @"2"];
    NSArray *flowControlLabels = @[ @"None", @"XOFF", @"RTS"];
    
    if ([self isOpen]) {
        // @"usbSerial-1234 <open 19200 8N1 XOFF>"
        theDescription = [[NSString alloc] initWithFormat:@"%@ <%@ %@ %@%@%@ %@>\n", _name, openOrClosed, self.baudRate.stringValue, dataBitsLabels[self.dataBits], parityLabels[self.parity], stopBitsLabels[self.stopBits], flowControlLabels[self.flowControl]];
    } else {
        // @"usbSerial-1234 <closed>"
        theDescription = [[NSString alloc] initWithFormat:@"%@ <%@>\n", _name, openOrClosed];
    }
    
    
    return theDescription;
}


- (void) setDelegate:(id)delegate
{
    [self removeDelegate:_delegate];
    [self addDelegate:delegate];
    _delegate = delegate;
}

- (void) addDelegate:(id)aDelegate
{
    if (aDelegate) {
        [self.delegates addObject:aDelegate];
    }
}

- (void) removeDelegate:(id)aDelegate
{
    if (aDelegate) {
        [self.delegates removeObject:aDelegate];
    }
}

- (void) removeAllDelegates
{
    [self.delegates removeAllObjects];
    _delegate = nil;
}


- (NSString *) byteToBinaryString:(uint16)aByte
{
    NSMutableString *binaryRep;
    
    binaryRep = [[NSMutableString alloc] initWithCapacity:9];
    
    int z;
    for (z = pow(2,16); z > 0; z >>= 1)
    {
        [binaryRep appendString:(((aByte & z) == z) ? @"1" : @"0")];
    }
    
    return binaryRep;
}


#pragma mark Delegate Assistance methods
/*
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
 */

- (void) performSelectorForDelegates:(SEL)selector
{
    dispatch_async(dispatch_get_main_queue(), ^{
        for (id delegate in self.delegates) {
            if ([delegate respondsToSelector:selector])
            {
                [delegate performSelector:selector withObject:self];
            }
        }
    });
}

// This will be called on the serial ports background thread.
- (BOOL) portShouldOpen
{
    BOOL reply = YES;
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(serialPortShouldOpen:)])
        {
            if (![delegate serialPortShouldOpen:self]) {
                reply = NO;
            }
        }
    }
    return reply;
}

- (void) reportErrorToDelegate:(NSError *)error
{
    dispatch_async(dispatch_get_main_queue(), ^{
        for (id delegate in self.delegates) {
            if ([delegate respondsToSelector:@selector(serialPort:experiencedAnError:)])
            {
                [delegate serialPort:self experiencedAnError:error];
            }
        }
    });
}

#pragma mark OpenClose
- (void) open
{
    // Perform a normal non-blocking open operation
    //[self openAndNotifyObject:nil withSelector:nil];
    void (^openPort)(void);
    openPort = ^ {
        NSError *error = nil;
        
        BOOL success = [self openSynchronously:&error];
        
        if (!success) {
            [self reportErrorToDelegate:error];
        }
    };
    
    dispatch_async([self sendQueue], openPort);
}


- (BOOL) openSynchronously:(NSError**)anError;
{
    int returnCode;
    int connectAttempts = 2;
    
    if ([self isOpen]) {
        return YES;
    } else {
        if ([self portShouldOpen]) {
            [self performSelectorForDelegates:@selector(serialPortWillOpen:)];
            while (connectAttempts > 0 & self.fileDescriptor == -1) {
                self.fileDescriptor = open([[self path] UTF8String], O_RDWR | O_NOCTTY | O_NDELAY);
                connectAttempts = connectAttempts - 1;
            }
            if (self.fileDescriptor == -1) {
                if (anError != NULL) {
                    NSString *description;
                    int errCode;
                    
                    switch (errno) {
                        default:
                            description = NSLocalizedString(@"Serial port failed to open for an unknown reason", @"");
                            errCode = EISerialPortUnknownOpeningError;
                            break;
                    }
                    
                    // Create the underlying error.
                    NSError *underlyingError = [[NSError alloc] initWithDomain:NSPOSIXErrorDomain
                                                                          code:errno userInfo:nil];
                    // Create and return the custom domain error.
                    NSDictionary *errorDictionary = @{ NSLocalizedDescriptionKey : description,
                                                       NSUnderlyingErrorKey : underlyingError,
                                                       NSFilePathErrorKey : [self path] };
                    
                    *anError = [[NSError alloc] initWithDomain:@"au.com.electronicinnovations.EISerialPort"
                                                          code:errCode userInfo:errorDictionary];
                }
                return NO;
            } else {
                // Notify of successful opening
                [self performSelectorForDelegates:@selector(serialPortDidOpen:)];
                //dispatch_async(dispatch_get_main_queue(), ^{
                //    for (id delegate in self.delegates) {
                //        if ([delegate respondsToSelector:@selector(serialPortDidOpen:)])
                //        {
                //            [delegate serialPortDidOpen:self];
                //        }
                //    }
                //});
                
                //Stop any further open calls by non-root processes eg no other program can open the port
                returnCode = ioctl(self.fileDescriptor, TIOCEXCL);
                if (returnCode == -1) {
                    //NSLog(@"Error setting TIOCEXCL on %@ - %s(%d).\n", self.name, strerror(errno), errno);
                    if (anError != NULL) {
                        NSString *description;
                        int errCode;
                        
                        switch (errno) {
                            case EBADF:
                                description = NSLocalizedString(@"Error setting TIOCEXCL", @"");
                                errCode = EISerialPortUnknownOpeningError;
                                break;
                            default:
                                description = NSLocalizedString(@"Error setting TIOCEXCL", @"");
                                errCode = EISerialPortUnknownIOCTLError;
                                break;
                        }
                        
                        // Create the underlying error.
                        NSError *underlyingError = [[NSError alloc] initWithDomain:NSPOSIXErrorDomain
                                                                              code:errno userInfo:nil];
                        // Create and return the custom domain error.
                        NSDictionary *errorDictionary = @{ NSLocalizedDescriptionKey : description,
                                                           NSUnderlyingErrorKey : underlyingError,
                                                           NSFilePathErrorKey : [self path] };
                        
                        *anError = [[NSError alloc] initWithDomain:@"au.com.electronicinnovations.EISerialPort"
                                                              code:errCode userInfo:errorDictionary];
                    }
                }
                
                returnCode = tcgetattr(self.fileDescriptor, &_originalAttributes);
                if (returnCode == -1) {
                    NSLog(@"Error getting original tty attributes in openByBlocking %s(%d).\n", strerror(errno), errno);
                }
                
                returnCode = tcgetattr(self.fileDescriptor, &_modifiedAttributes);
                if (returnCode == -1) {
                    NSLog(@"Error getting tty attributes in openByBlocking %s(%d).\n", strerror(errno), errno);
                }
                
                //Set options
                _modifiedAttributes.c_oflag &= ~OPOST;	// Postprocess output (not set = raw output)
                _modifiedAttributes.c_cflag |= CLOCAL; // Set local mode on
                _modifiedAttributes.c_iflag |= IGNBRK;
                
                returnCode = tcsetattr(self.fileDescriptor, TCSANOW, &_modifiedAttributes);
                if (returnCode == -1)
                {
                    NSLog(@"Failed to modify attributes for %@", self);
                    NSLog(@"Error setting tty attributes in openByBlocking %s(%d).\n", strerror(errno), errno);
                }
                
                _open = YES;
                
                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                
                [self setBaudRate:[defaults objectForKey:[NSString stringWithFormat:@"%@-baudRate", self.name]]];
                [self setDataBits:(EISerialDataBits)[[defaults objectForKey:[NSString stringWithFormat:@"%@-dataBits", self.name]] integerValue]];
                [self setParity:(EISerialParity)[[defaults objectForKey:[NSString stringWithFormat:@"%@-parity", self.name]] integerValue]];
                [self setStopBits:(EISerialStopBits)[[defaults objectForKey:[NSString stringWithFormat:@"%@-stopBits", self.name]] integerValue]];
                [self setFlowControl:(EISerialFlowControl)[[defaults objectForKey:[NSString stringWithFormat:@"%@-flowControl", self.name]] integerValue]];
                [self setLatency:@1];
                
                [self setupReceiveThread];
                
                return YES;
            }
            
        } else {
            return NO;
        }
    }
}

/*
 - (BOOL) serialPortShouldClose:(EISerialPort *)port;
 - (void) serialPortWillClose:(EISerialPort *)port;
 - (void) serialPortDidClose:(EISerialPort *)port;
 */
- (BOOL) portShouldClose
{
    BOOL reply = YES;
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(serialPortShouldClose:)])
        {
            if (![delegate serialPortShouldClose:self]) {
                reply = NO;
            }
        }
    }
    return reply;
}


- (void) closeImmediately
{
    if ([self isOpen] && [self portShouldClose]) {
        _open = NO;
        sleep(0.2);
        // flush all input and output.
        // Note that this call is simply passed on to the serial device driver.
        // See tcsendbreak(3) ("man 3 tcsendbreak") for details.
        if (tcflush([self fileDescriptor], TCIOFLUSH) == -1)
        {
            NSLog(@"Flush command failed");
        }
        
        //Re-allow other processes access to the serial Port
        if (ioctl([self fileDescriptor], TIOCNXCL) == -1)
        {
            NSLog(@"TIOCNXCL Failed");
        }
        
        // It is good practice to reset a serial port back to the state in
        // which you found it. This is why we saved the original termios struct
        // The constant TCSANOW (defined in termios.h) indicates that
        // the change should take effect immediately.
        if (tcsetattr([self fileDescriptor], TCSANOW, &_originalAttributes) == -1)
        {
            //@throw serialException;
            NSLog(@"Error resetting tty attributes - %s(%d).\n",
                   strerror(errno), errno);
        }
        
        [self performSelectorForDelegates:@selector(serialPortWillClose:)];
        close([self fileDescriptor]);
        self.fileDescriptor = -1;
        [self performSelectorForDelegates:@selector(serialPortDidClose:)];
    }
}

- (void) close
{
    dispatch_async(self.sendQueue, ^{
        [self closeImmediately];
    });
}


#pragma mark Settings
/*
 - (BOOL) serialPortShouldChangeSettings:(EISerialPort *)port;
 - (void) serialPortWillChangeSettings:(EISerialPort *)port;
 - (void) serialPortDidChangeSettings:(EISerialPort *)port;
 */
- (void) startModifyingSettings;
{
    dispatch_async(self.sendQueue, ^{
        int returnCode;
        
        returnCode = tcgetattr(self.fileDescriptor, &_modifiedAttributes);
        if (returnCode == -1)
        {
            NSLog(@"Failed to read attributes for %@", self);
            NSLog(@"is Open %@",[self isOpen] ? @"YES" : @"NO");
        }
    } );
}


- (void) finishModifyingSettings;
{
    dispatch_async(self.sendQueue, ^{
        int returnCode;
        
        [self performSelectorForDelegates:@selector(serialPortWillChangeSettings:)];
        returnCode = tcsetattr(self.fileDescriptor, TCSANOW, &_modifiedAttributes);
        if (returnCode == -1)
        {
            NSLog(@"Failed to modify attributes for %@", self);
            NSLog(@"is Open %@",[self isOpen] ? @"YES" : @"NO");
            NSLog(@"Error setting tty attributes in endModifyingAttributes %s(%d).\n", strerror(errno), errno);
        } else {
            [self performSelectorForDelegates:@selector(serialPortDidChangeSettings:)];
        }
    } );
}


- (void)resetAttributesToOriginal
{
    dispatch_async(self.sendQueue, ^ {
        int returnCode;
        
        returnCode = tcsetattr(self.fileDescriptor, TCSAFLUSH, &_originalAttributes);
        if (returnCode == -1)
        {
            NSLog(@"Failed to modify attributes for %@", self);
            NSLog(@"is Open %@",[self isOpen] ? @"YES" : @"NO");
        }
    } );
}


- (NSNumber *) baudRate
{
    NSNumber *baudRate;
    int returnCode;
    struct termios currentAttributes;
	
    returnCode = tcgetattr([self fileDescriptor], &currentAttributes);
    if (returnCode == -1)
    {
        NSLog(@"Error getting tty attributes in getBaudRate");
        return @(returnCode);
    }
    baudRate = @(cfgetispeed(&currentAttributes));
    
	return baudRate;
}


- (void) setBaudRate:(NSNumber *) baudRate;
{
    [self startModifyingSettings];
    dispatch_async(self.sendQueue, ^ {
        cfsetispeed(&_modifiedAttributes, [baudRate longValue]);
        cfsetospeed(&_modifiedAttributes, [baudRate longValue]);
    } );
    [self finishModifyingSettings];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:baudRate forKey:[NSString stringWithFormat:@"%@-baudRate", self.name]];
}


-(EISerialFlowControl)flowControl
{
    int returnCode;
    struct termios currentAttributes;
    
    returnCode = tcgetattr(self.fileDescriptor, &currentAttributes);
    if (returnCode == -1)
    {
        NSLog(@"Failed to read attributes for %@", self);
    }
    
    if (currentAttributes.c_iflag & (IXON | IXOFF | IXANY)) {
        return EIFlowControlXonXoff;
    } else if (currentAttributes.c_cflag & (CCTS_OFLOW | CRTS_IFLOW)) {
        return EIFlowControlHardware;
    } else {
        return EIFlowControlNone;
    }
}

-(void)setFlowControl:(EISerialFlowControl)method
{
    [self startModifyingSettings];
    dispatch_async(self.sendQueue, ^ {
        switch (method) {
            case EIFlowControlNone:
                _modifiedAttributes.c_iflag &= ~(IXON | IXOFF | IXANY);
                _modifiedAttributes.c_cflag &= ~(CRTSCTS);
                break;
            case EIFlowControlXonXoff:
                _modifiedAttributes.c_iflag |= (IXON | IXOFF | IXANY);
                _modifiedAttributes.c_cflag &= ~(CCTS_OFLOW | CRTS_IFLOW);
                break;
            case EIFlowControlHardware:
                _modifiedAttributes.c_iflag &= ~(IXON | IXOFF | IXANY);
                _modifiedAttributes.c_cflag |= (CCTS_OFLOW | CRTS_IFLOW);
                break;
            default:
                break;
        }
    } );
    [self finishModifyingSettings];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:@(method) forKey:[NSString stringWithFormat:@"%@-flowControl", self.name]];
}


// [serialPort setParity:EIParityNone];
-(EISerialParity)parity
{
    int returnCode;
    struct termios currentAttributes;
    
    returnCode = tcgetattr(self.fileDescriptor, &currentAttributes);
    if (returnCode == -1)
    {
        NSLog(@"Failed to read attributes for %@", self);
    }
    
    if (currentAttributes.c_cflag & PARENB) {
        if (currentAttributes.c_cflag & PARODD) {
            return EIParityOdd;
        } else {
            return EIParityEven;
        }
    } else {
        return EIParityNone;
    }
}


-(void)setParity:(EISerialParity)parity
{
    [self startModifyingSettings];
    dispatch_async(self.sendQueue, ^ {
        switch (parity) {
            case EIParityNone:
                _modifiedAttributes.c_cflag &= ~PARENB;
                break;
            case EIParityOdd:
                _modifiedAttributes.c_cflag |= PARENB;
                _modifiedAttributes.c_cflag |= PARODD;
                break;
            case EIParityEven:
                _modifiedAttributes.c_cflag |= PARENB;
                _modifiedAttributes.c_cflag &= ~PARODD;
                break;
            default:
                break;
        }
    } );
    [self finishModifyingSettings];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:@(parity) forKey:[NSString stringWithFormat:@"%@-parity", self.name]];
}


- (void) setLatency:(NSNumber *)latency
{
    unsigned long mics;
    mics = [latency unsignedLongValue]; // latency is in microseconds
    dispatch_async(self.sendQueue, ^ {
        if (ioctl(self.fileDescriptor, IOSSDATALAT, &mics) == -1) {
            NSLog(@"Error setting read latency - %s(%d).\n", strerror(errno), errno);
        }
    });
    // Need to set the defaults here
}

/*
- (NSNumber *) latency
{
    
}
*/

-(uint)minBytesPerRead
{
    int returnCode;
    struct termios currentAttributes;
    
    returnCode = tcgetattr(self.fileDescriptor, &currentAttributes);
    if (returnCode == -1)
    {
        NSLog(@"Failed to read attributes for %@", self);
    }
    
    return currentAttributes.c_cc[VMIN];
}


-(void)setMinBytesPerRead:(uint)min
{
    [self startModifyingSettings];
    dispatch_async(self.sendQueue, ^ {
        _modifiedAttributes.c_cc[VMIN] = min;
    } );
    [self finishModifyingSettings];
}


-(uint)timeout
{
    int returnCode;
    struct termios currentAttributes;
    
    returnCode = tcgetattr(self.fileDescriptor, &currentAttributes);
    if (returnCode == -1)
    {
        NSLog(@"Failed to read attributes for %@", self);
    }
    
    return currentAttributes.c_cc[VTIME];
}


-(void)setTimeout:(uint)time
{
    [self startModifyingSettings];
    dispatch_async(self.sendQueue, ^ {
        _modifiedAttributes.c_cc[VTIME] = time;
    } );
    [self finishModifyingSettings];
}


-(void)setRawMode
{
    [self startModifyingSettings];
    dispatch_async(self.sendQueue, ^ {
        cfmakeraw(&_modifiedAttributes);
    } );
    [self finishModifyingSettings];
}


-(void)flushIO
{
    [self startModifyingSettings];
    dispatch_async(self.sendQueue, ^ {
        if (tcflush([self fileDescriptor], TCIOFLUSH) == -1)
        {
            printf("Error waiting for drain - %s(%d).\n",
                   strerror(errno), errno);
        }
    } );
    [self finishModifyingSettings];
}


// [serialPort setStopBits:EIStopbitsOne];
-(EISerialStopBits)stopBits
{
    int returnCode;
    struct termios currentAttributes;
    
    returnCode = tcgetattr(self.fileDescriptor, &currentAttributes);
    if (returnCode == -1)
    {
        NSLog(@"Failed to read attributes for %@", self);
    }
    
    if (currentAttributes.c_cflag & CSTOPB) {
        return EIStopbitsTwo;
    } else {
        return EIStopbitsOne;
    }
}

-(void)setStopBits:(EISerialStopBits)stopBits
{
    if (stopBits == EIStopbitsOne) {
        [self setOneStopBit];
    } else if (stopBits == EIStopbitsTwo) {
        [self setTwoStopBits];
    } else {
        // Flag an error
    }
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:@(stopBits) forKey:[NSString stringWithFormat:@"%@-stopBits", self.name]];
}

-(void)setOneStopBit
{
    [self startModifyingSettings];
    dispatch_async(self.sendQueue, ^ {
        _modifiedAttributes.c_cflag &= ~CSTOPB;
    } );
    [self finishModifyingSettings];
}

-(void)setTwoStopBits
{
    [self startModifyingSettings];
    dispatch_async(self.sendQueue, ^ {
        _modifiedAttributes.c_cflag |= CSTOPB;
    } );
    [self finishModifyingSettings];
}


-(EISerialDataBits)dataBits
{
    int returnCode;
    struct termios currentAttributes;
    tcflag_t EI_c_cflag;
    
    returnCode = tcgetattr(self.fileDescriptor, &currentAttributes);
    if (returnCode == -1)
    {
        NSLog(@"Failed to read attributes for %@", self);
    }
    
    EI_c_cflag = currentAttributes.c_cflag & CSIZE;
    switch (EI_c_cflag) {
        case CS5:
            return EIDataBitsFive;
            break;
        case CS6:
            return EIDataBitsSix;
            break;
        case CS7:
            return EIDataBitsSeven;
            break;
        case CS8:
            return EIDataBitsEight;
            break;
        default:
            return EIDataBitsFive;
            break;
    }
}

-(void)setDataBits:(EISerialDataBits)dataBits
{
    [self startModifyingSettings];
    dispatch_async(self.sendQueue, ^ {
        _modifiedAttributes.c_cflag &= ~CSIZE;
        switch (dataBits) {
            case EIDataBitsFive:
                _modifiedAttributes.c_cflag |= CS5;
                break;
            case EIDataBitsSix:
                _modifiedAttributes.c_cflag |= CS6;
                break;
            case EIDataBitsSeven:
                _modifiedAttributes.c_cflag |= CS7;
                break;
            case EIDataBitsEight:
                _modifiedAttributes.c_cflag |= CS8;
                break;
            default:
                break;
        }
    } );
    [self finishModifyingSettings];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:@(dataBits) forKey:[NSString stringWithFormat:@"%@-dataBits", self.name]];
}

- (NSArray *)standardBaudRates
{
    return @[ @0L, @50L, @75L, @110L, @134L, @150L, @200L, @300L, @600L, @1200L, @1800L, @2400L, @4800L, @7200L, @9600L, @14400L, @19200L, @28800L, @38400L, @57600L, @76800L, @115200L, @230400L, @460800L];
}

- (NSArray *)baudRateLabels
{
    NSMutableArray *labels = [[NSMutableArray alloc] initWithCapacity:24];
    
    for (NSNumber *baudRate in self.standardBaudRates) {
        [labels addObject:baudRate.stringValue];
    }
    
    return labels;
}

- (NSArray *)parityLabels
{
    return @[ @"None", @"Odd", @"Even" ];
}

- (NSArray *)stopBitLabels
{
    return @[ @"1", @"2" ];
}

- (NSArray *)dataBitLabels
{
    return @[ @"5", @"6", @"7", @"8" ];
}

- (NSArray *)flowControlLabels
{
    return @[ @"None", @"XOFF", @"RTS" ];
}


- (void) printSerialPortAttributes:(struct termios)attributes
{
    //int returnCode;
    //struct termios attributes;
    
    //returnCode = tcgetattr(fileDescriptor, &attributes);
    
    NSLog(@"c_iflag:%lx, c_oflag:%lx, c_cflag:%lx, c_lflag:%lx", attributes.c_iflag, attributes.c_oflag, attributes.c_cflag, attributes.c_lflag);
    /* c_iflag
     IGNBRK    ignore BREAK condition
     BRKINT    map BREAK to SIGINTR
     IGNPAR    ignore (discard) parity errors
     PARMRK    mark parity and framing errors
     INPCK     enable checking of parity errors
     ISTRIP    strip 8th bit off chars
     INLCR     map NL into CR
     IGNCR     ignore CR
     ICRNL     map CR to NL (ala CRMOD)
     IXON      enable output flow control
     IXOFF     enable input flow control
     IXANY     any char will restart after stop
     IMAXBEL   ring bell on input queue full
     IUCLC     translate upper case to lower case
     */
    NSDictionary *c_iflagsDict = @{ @"IGNBRK " : @(IGNBRK), \
                                    @"BRKINT " : @(BRKINT), \
                                    @"IGNPAR " : @(IGNPAR), \
                                    @"PARMRK " : @(PARMRK), \
                                    @"INPCK  " : @(INPCK), \
                                    @"ISTRIP " : @(ISTRIP), \
                                    @"INLCR  " : @(INLCR), \
                                    @"IGNCR  " : @(IGNCR), \
                                    @"ICRNL  " : @(ICRNL), \
                                    @"IXON   " : @(IXON), \
                                    @"IXOFF  " : @(IXOFF), \
                                    @"IXANY  " : @(IXANY), \
                                    @"IMAXBEL" : @(IMAXBEL),};
    
    NSLog(@"\nc_iflag");
    NSString *key;
    for(key in c_iflagsDict){
        NSLog(@"%@:%@", key, (attributes.c_iflag & [c_iflagsDict[key] intValue]) ? @"TRUE" : @"FALSE");
    }
    
    /* c_oflag
     OPOST    enable following output processing
     ONLCR    map NL to CR-NL (ala CRMOD)
     OXTABS   expand tabs to spaces
     ONOEOT   discard EOT's `^D' on output)
     OCRNL    map CR to NL
     OLCUC    translate lower case to upper case
     ONOCR    No CR output at column 0
     ONLRET   NL performs CR function
     */
    NSDictionary *c_oflagsDict = @{ @"OPOST " : @(OPOST), \
                                    @"ONLCR " : @(ONLCR), \
                                    @"OXTABS" : @(OXTABS), \
                                    @"ONOEOT" : @(ONOEOT), \
                                    @"OCRNL " : @(OCRNL), \
                                    @"ONOCR " : @(ONOCR), \
                                    @"ONLRET" : @(ONLRET),};
    NSLog(@"\nc_oflag");
    for(key in c_oflagsDict){
        NSLog(@"%@:%@", key, (attributes.c_oflag & [c_oflagsDict[key] intValue]) ? @"TRUE" : @"FALSE");
    }
    
    /* c_cflag
     CSIZE       character size mask
     CS5          5 bits (pseudo)
     CS6          6 bits
     CS7          7 bits
     CS8          8 bits
     CSTOPB       send 2 stop bits
     CREAD        enable receiver
     PARENB       parity enable
     PARODD       odd parity, else even
     HUPCL        hang up on last close
     CLOCAL       ignore modem status lines
     CCTS_OFLOW   CTS flow control of output
     CRTSCTS     same as CCTS_OFLOW
     CRTS_IFLOW   RTS flow control of input
     MDMBUF       flow control output via Carrier
     
     
      Control flags - hardware control of terminal
     
        #if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
        #define	CIGNORE		0x00000001	 ignore control flags
        #endif
        #define CSIZE		0x00000300	 character size mask
        #define     CS5		    0x00000000	     5 bits (pseudo)
        #define     CS6		    0x00000100	     6 bits
        #define     CS7		    0x00000200	     7 bits
        #define     CS8		    0x00000300	     8 bits
        #define CSTOPB		0x00000400	 send 2 stop bits
        #define CREAD		0x00000800	 enable receiver
        #define PARENB		0x00001000	 parity enable
        #define PARODD		0x00002000	 odd parity, else even
        #define HUPCL		0x00004000	 hang up on last close
        #define CLOCAL		0x00008000	 ignore modem status lines
        #if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
        #define CCTS_OFLOW	0x00010000	 CTS flow control of output
        #define CRTSCTS		(CCTS_OFLOW | CRTS_IFLOW)
        #define CRTS_IFLOW	0x00020000	 RTS flow control of input
        #define	CDTR_IFLOW	0x00040000	 DTR flow control of input
        #define CDSR_OFLOW	0x00080000	 DSR flow control of output
        #define	CCAR_OFLOW	0x00100000	 DCD flow control of output
        #define	MDMBUF		0x00100000	 old name for CCAR_OFLOW
        #endif
     */
    NSDictionary *c_cflagDict = @{ @"CIGNORE       " : @(CIGNORE), \
                                   @"CS6           " : @(CS6), \
                                   @"CS7           " : @(CS7), \
                                   @"2STOPB        " : @(CSTOPB), \
                                   @"CREAD         " : @(CREAD), \
                                   @"PARENB        " : @(PARENB), \
                                   @"PARODD        " : @(PARODD), \
                                   @"HUPCL         " : @(HUPCL), \
                                   @"CLOCAL        " : @(CLOCAL), \
                                   @"CCTS_OFLOW    " : @(CCTS_OFLOW),
                                   @"CRTS_IFLOW    " : @(CRTS_IFLOW), \
                                   @"CDTR_IFLOW    " : @(CDTR_IFLOW), \
                                   @"CDSR_OFLOW    " : @(CDSR_OFLOW), \
                                   @"CCAR_OFLOW    " : @(CCAR_OFLOW), \
                                   @"MDMBUF        " : @(EXTPROC),  };
    NSLog(@"\nc_cflag");
    for(key in c_cflagDict){
        NSLog(@"%@:%@", key, (attributes.c_cflag & [c_cflagDict[key] intValue]) ? @"TRUE" : @"FALSE");
    }
    /* c_lflagrf
     ECHOKE       visual erase for line kill
     ECHOE        visually erase chars
     ECHO         enable echoing
     ECHONL       echo NL even if ECHO is off
     ECHOPRT      visual erase mode for hardcopy
     ECHOCTL     echo control chars as ^(Char)
     ISIG         enable signals INTR, QUIT, [D]SUSP
     ICANON       canonicalize input lines
     ALTWERASE    use alternate WERASE algorithm
     IEXTEN       enable DISCARD and LNEXT
     EXTPROC      external processing
     TOSTOP       stop background jobs from output
     FLUSHO       output being flushed (state)
     NOKERNINFO   no kernel output from VSTATUS
     PENDIN       XXX retype pending input (state)
     NOFLSH       don't flush after interrupt
     */
    NSDictionary *c_lflagDict = @{ @"ECHOKE    " : @(ECHOKE), \
                                   @"ECHOE     " : @(ECHOE), \
                                   @"ECHO      " : @(ECHO), \
                                   @"ECHONL    " : @(ECHONL), \
                                   @"ECHOPRT   " : @(ECHOPRT), \
                                   @"ECHOCTL   " : @(ECHOCTL), \
                                   @"ISIG      " : @(ISIG), \
                                   @"ICANON    " : @(ICANON),
                                   @"ALTWERASE " : @(ALTWERASE), \
                                   @"IEXTEN    " : @(IEXTEN), \
                                   @"EXTPROC   " : @(EXTPROC), \
                                   @"TOSTOP    " : @(TOSTOP), \
                                   @"FLUSHO    " : @(FLUSHO), \
                                   @"NOKERNINFO" : @(NOKERNINFO), \
                                   @"NOFLSH    " : @(NOFLSH), \
                                   @"PENDIN    " : @(PENDIN), };
    NSLog(@"\nc_lflag");
    for(key in c_lflagDict){
        NSLog(@"%@:%@", key, (attributes.c_lflag & [c_lflagDict[key] intValue]) ? @"TRUE" : @"FALSE");
    }
}

- (float) calculateDelayPerByte:(struct termios)attributes
{
    float delay;
    tcflag_t EI_c_cflag;
    NSNumber *baudRate;
    float delayPerBit;
    
    // What is the bad rate
    baudRate = @(cfgetispeed(&attributes));
    delayPerBit = (float)1/[baudRate intValue];
    
    // Start bit
    delay = delayPerBit;
    
    // Bits per byte
    EI_c_cflag = attributes.c_cflag & CSIZE; // The below is wrong
    switch (EI_c_cflag) {
        case CS5:
            delay = delay + (delayPerBit * 5);
            break;
        case CS6:
            delay = delay + (delayPerBit * 6);
            break;
        case CS7:
            delay = delay + (delayPerBit * 7);
            break;
        case CS8:
            delay = delay + (delayPerBit * 8);
            break;
        default:
            delay = delay + (delayPerBit * 5);
            break;
    }
    
    // Parity
    if (attributes.c_cflag & PARENB) {
        delay = delay + (1 * delayPerBit);
    }
    
    // Stop bits
    if (attributes.c_cflag & CSTOPB) {
        delay = delay + (2 * delayPerBit);
    } else {
        delay = delay + (1 * delayPerBit);
    }
    
    return delay;
}


#pragma mark Writing
- (void) sendString:(NSString *)aString
{
    NSData *dataToSend = [aString dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
    [self sendData:dataToSend];
}


- (void) sendString:(NSString *)aString inChunksSplitBy:(NSString *)delimiter
{
    [self sendString:aString inChunksSplitBy:delimiter replaceDelimiterWith:delimiter];
}


- (void) sendString:(NSString *)aString inChunksSplitBy:(NSString *)delimiter replaceDelimiterWith:(NSString *)lineEnding
{
    NSArray *chunks = [aString componentsSeparatedByString: delimiter];
    NSDate *startDate;
    
    if ([chunks count] < 2) {
        [self sendString:aString];
    } else {
        id activity = [[NSProcessInfo processInfo] beginActivityWithOptions:NSActivityUserInitiated reason:@"Sending a large String"];
        startDate = [NSDate date];
        for (NSString *chunk in chunks){
            NSString *line = [NSString stringWithFormat:@"%@%@", chunk, lineEnding];
            [self sendString:line];
        }
        dispatch_async(self.sendQueue, ^{
            [[NSProcessInfo processInfo] endActivity:activity];
            NSTimeInterval elapsedTimeInterval = [startDate timeIntervalSinceNow];
            NSLog(@"Download Time: %.2f", elapsedTimeInterval);
        });
    }
}


- (void) sendKeyCode:(unsigned short)keyCode
{
    NSData *dataToSend = [NSData dataWithBytes:&keyCode length:1];
    [self sendData:dataToSend];
}


- (void) sendData:(NSData *)dataToSend;
{
    void (^writeData)(void);
    writeData = ^(void) {
        ssize_t numBytes = 0;
        ssize_t bytesSent = 0;
        NSData *toBeSent;
        //NSData *sent;
        uint roomInBuffer, numberOfBytesToSend;
        
        while (![self isCancelled] && (bytesSent < [dataToSend length]) && self.isOpen) {
            
            uint ioctlBytestInBuffer;
            int returnCode = ioctl(self.fileDescriptor, TIOCOUTQ, &ioctlBytestInBuffer);
            if (returnCode == -1)
            {
                NSLog(@"Error setting TIOCOUTQ on %@ - %s(%d).\n", self.name, strerror(errno), errno);
            }
            //NSLog(@"ioct bytes in buffer %d",ioctlBytestInBuffer);
            roomInBuffer = self.idealBufferSize - ioctlBytestInBuffer;
            roomInBuffer = roomInBuffer > self.idealBufferSize ? self.idealBufferSize : roomInBuffer;
            
            numberOfBytesToSend = (uint)MIN(roomInBuffer, ((uint)[dataToSend length] - bytesSent));
            //NSLog(@"Number of Bytes in Buffer:%d Room in Buffer:%d Number of Bytes to send:%d",ioctlBytestInBuffer, roomInBuffer, numberOfBytesToSend);
            
            if (numberOfBytesToSend > 0) {
                toBeSent = [dataToSend subdataWithRange:NSMakeRange(bytesSent, numberOfBytesToSend)];
                numBytes = write(self.fileDescriptor, [toBeSent bytes], [toBeSent length]);
                if (numBytes == -1) {
                    NSLog(@"Write Error:%s", strerror( errno ));
                    NSLog(@"fileDescriptor: %d, toBeSentLength: %lu", self.fileDescriptor, (unsigned long)[toBeSent length]);
                    NSLog(@"toBeSent: %@", [[NSString alloc] initWithData:toBeSent encoding:NSASCIIStringEncoding]);
                    NSLog(@"toBeSent: %@", toBeSent);
                    
                    [self closeImmediately];
                    usleep(100000);
                } else {
                    bytesSent = bytesSent + numBytes;
                    usleep(1000); // 1ms delay per line
                }
            } else {
                usleep(5000);
            }
        }
        
        [self setCancelled:NO];
        
        for (id delegate in self.delegates) {
            if ([delegate respondsToSelector:@selector(serialPort:didSendData:)])
            {
                [delegate performSelector:@selector(serialPort:didSendData:) withObject:self withObject:dataToSend];
            }
        }
        
    };
    
    dispatch_async(self.sendQueue, writeData);
}


- (void) sendData:(NSData *)dataToSend inChunksOfSize:(NSNumber *)chunkSize
{
    
}


- (void) delayTransmissionForDuration:(NSTimeInterval)seconds
{
    dispatch_async(self.sendQueue, ^{ usleep((int)(1000000 * seconds)); });
}


-(void)sendBreak
{
    tcsendbreak(self.fileDescriptor, 0);
}

- (void) cancelCurrentTransmission
{
    [self setCancelled:YES];
    [self flushIO];
}




#pragma mark Reading

- (void) setupReceiveThread
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		
		int localPortFD = self.fileDescriptor;
		struct timeval timeout;
		int result=0;
		
		while (self.isOpen)
		{
			fd_set localReadFDSet;
			FD_ZERO(&localReadFDSet);
			FD_SET(self.fileDescriptor, &localReadFDSet);
            
			timeout.tv_sec = 0;
			timeout.tv_usec = 100000; // Check to see if port closed every 100ms
			
			result = select(localPortFD+1, &localReadFDSet, NULL, NULL, &timeout);
			if (result < 0)
			{
				//dispatch_queue_t mainQueue = dispatch_get_main_queue();
                //dispatch_sync(mainQueue, ^{[self notifyDelegateOfPosixError];});
				continue;
			}
			
			if (result == 0 || !FD_ISSET(localPortFD, &localReadFDSet)) continue;
			
			// Data is available
			char buf[1024];
			long lengthRead = read(localPortFD, buf, sizeof(buf));
			if (lengthRead > 0)
			{
				NSData *readData = [NSData dataWithBytes:buf length:lengthRead];
				//if (readData != nil) dispatch_async(dispatch_get_main_queue(), ^{
                if (readData != nil) {
                    for (id delegate in self.delegates) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if ([delegate respondsToSelector:@selector(serialPort:didReceiveData:)]) {
                                [delegate performSelector:@selector(serialPort:didReceiveData:) withObject:self withObject:readData];
                            }
                        });
                    }
                }
			}
		}
	});
}

/*
 - (void)sendBulkText:(NSString *)stringToSend
 {
 NSScanner *scanner = [NSScanner scannerWithString:stringToSend];
 [scanner setCharactersToBeSkipped:nil];
 NSString *line = nil;
 NSString *lineEndings = nil;
 NSMutableString *toSend = [[NSMutableString alloc] initWithCapacity:100];
 
 while (![scanner isAtEnd]) {
 
 line = nil;
 [scanner scanUpToCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:&line];
 if (line) {
 [toSend appendString:line];
 }
 
 lineEndings = nil;
 [scanner scanCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:&lineEndings];
 if (lineEndings) {
 [toSend appendString:@"\r\n"];
 }
 }
 if (toSend) {
 [serialPort sendString:toSend];
 [toSend setString:@""];
 }
 }
 */


@end
