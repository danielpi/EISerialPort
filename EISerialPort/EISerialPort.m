//
//  EISerialPortThread.m
//  Weetbix
//
//  Created by Daniel Pink on 3/04/13.
//  Copyright (c) 2013 Electronic Innovations. All rights reserved.
//

#import "EISerialPort.h"
// #import <Foundation/Foundation.h>
// #import <Cocoa/Cocoa.h>
// #include <CoreFoundation/CoreFoundation.h>

// #include <stdio.h>
// #include <string.h>
// #include <unistd.h>
// #include <fcntl.h>
// #include <errno.h>
// #include <paths.h>
// #include <termios.h>
// #include <sysexits.h>
// #include <sys/param.h>
// #include <sys/event.h>
#include <sys/ioctl.h>

#include <IOKit/IOKitLib.h>
#include <IOKit/serial/IOSerialKeys.h>
#include <IOKit/IOBSD.h>

#include <dispatch/dispatch.h>


@interface EISerialPort ()

@property (readwrite) int fileDescriptor;
@property (readwrite) io_object_t matchedMachPort;
@property (readwrite) struct __block termios modifiedAttributes;
@property (readwrite) struct __block termios originalAttributes;

@property (readwrite) dispatch_queue_t sendQueue;
@property (readwrite) dispatch_queue_t receiveQueue;
@property (atomic, retain, readwrite) NSTimer *timer;
@property (readonly) uint idealBufferSize;

- (void) startModifyingSettings;
- (void) finishModifyingSettings;

- (NSString *) byteToBinaryString:(uint16)aByte;
- (void) openByBlocking;

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
        _matchedMachPort = iOObject;
        CFTypeRef ioKitReturn;
        
        ioKitReturn = IORegistryEntryCreateCFProperty(_matchedMachPort, CFSTR(kIOTTYDeviceKey), kCFAllocatorDefault, 0);
        _name = [NSString stringWithString:(__bridge NSString *)ioKitReturn];
        
        ioKitReturn = IORegistryEntryCreateCFProperty(_matchedMachPort, CFSTR(kIOCalloutDeviceKey), kCFAllocatorDefault, 0);
        _path = [NSString stringWithString:(__bridge NSString *) ioKitReturn];
        
        CFRelease(ioKitReturn);
        _fileDescriptor = -1;
        
        _idealBufferSize = 400;
        
        _sendQueue = dispatch_queue_create("au.com.electronicinnovations.sendQueue", NULL);
        _receiveQueue = dispatch_queue_create("au.com.electronicinnovations.receiveQueue", NULL);
        _timer = [[NSTimer alloc] init];
    }
    return self;
}

#pragma mark Properties
- (BOOL)isOpen
{
    if (self.fileDescriptor == -1) {
        return FALSE;
    } else {
        return TRUE;
    }
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


#pragma mark OpenClose
- (void) open
{
    // Perform a normal non-blocking open operation
    //[self openAndNotifyObject:nil withSelector:nil];
    void (^openPort)(void);
    openPort = ^ { [self openByBlocking]; };
    
    dispatch_async([self sendQueue], openPort);
}


- (void) openByBlocking
{
    int returnCode;
    int connectAttempts = 2;
    //NSLog(@"Opening Port\n");
    
    if ([self isOpen]) {
        return;
    } else {
        while (connectAttempts > 0 & self.fileDescriptor == -1) {
            self.fileDescriptor = open([[self path] UTF8String], O_RDWR | O_NOCTTY | O_NDELAY);
            //NSLog(@"Try again");
            connectAttempts = connectAttempts - 1;
        }
        
        if (self.fileDescriptor == -1)
        {
            //NSLog(@"Error opening serial port %s(%d).\n", strerror(errno), errno);
            // Notify of failed attempt
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([self.delegate respondsToSelector:@selector(serialPortFailedToOpen)])
                {
                    [self.delegate serialPortFailedToOpen];
                }
            });
            return;
        } else {
            // Notify of successful opening
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([self.delegate respondsToSelector:@selector(serialPortDidOpen)])
                {
                    [self.delegate serialPortDidOpen];
                }
            });
            
            //Stop any further open calls by non-root processes eg no other program can open the port
            returnCode = ioctl(self.fileDescriptor, TIOCEXCL);
            if (returnCode == -1)
            {
                //NSLog(@"Error setting TIOCEXCL on %@ - %s(%d).\n", self.name, strerror(errno), errno);
            }
            
            returnCode = tcgetattr(self.fileDescriptor, &_originalAttributes);
            if (returnCode == -1)
            {
                //NSLog(@"Error getting original tty attributes in openByBlocking %s(%d).\n", strerror(errno), errno);
            }
            
            returnCode = tcgetattr(self.fileDescriptor, &_modifiedAttributes);
            if (returnCode == -1)
            {
                //NSLog(@"Error getting tty attributes in openByBlocking %s(%d).\n", strerror(errno), errno);
            }
            
            //Set the output options
            _modifiedAttributes.c_oflag |= OPOST;	// Postprocess output (not set = raw output)
            //modifiedAttributes.c_oflag |= ONLCR;	// Map NL to CR-NL
            
            //[self printSerialPortAttributes:modifiedAttributes];
            returnCode = tcsetattr(self.fileDescriptor, TCSANOW, &_modifiedAttributes);
            if (returnCode == -1)
            {
                //NSLog(@"Failed to modify attributes for %@", self);
                //NSLog(@"Error setting tty attributes in openByBlocking %s(%d).\n", strerror(errno), errno);
            }
            
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            [self startModifyingAttributes];
            [self setBaudRate:[defaults objectForKey:[NSString stringWithFormat:@"%@-baudRate", self.name]]];
            [self setDataBits:(EISerialDataBits)[[defaults objectForKey:[NSString stringWithFormat:@"%@-dataBits", self.name]] integerValue]];
            [self setParity:(EISerialParity)[[defaults objectForKey:[NSString stringWithFormat:@"%@-parity", self.name]] integerValue]];
            [self setStopBits:(EISerialStopBits)[[defaults objectForKey:[NSString stringWithFormat:@"%@-stopBits", self.name]] integerValue]];
            [self setFlowControl:(EISerialFlowControl)[[defaults objectForKey:[NSString stringWithFormat:@"%@-flowControl", self.name]] integerValue]];
            [self finishModifyingAttributes];
            
            [self setupReceiveThread];
        }
    }
}


- (void) close
{
    dispatch_async(self.sendQueue, ^{
        
        if ([self isOpen]) {
            
            //[self suspendReading];
            //dispatch_source_cancel(readSource);
            sleep(0.2);
            //[self suspendWriting];
            
            //NSLog(@"%@ is being closed",[self name]);
            // flush all input and output.
            // Note that this call is simply passed on to the serial device driver.
            // See tcsendbreak(3) ("man 3 tcsendbreak") for details.
            if (tcflush([self fileDescriptor], TCIOFLUSH) == -1)
            {
                //@throw serialException;
                //printf("Error waiting for drain - %s(%d).\n",
                //       strerror(errno), errno);
            }
            
            //Re-allow other processes access to the serial Port
            if (ioctl([self fileDescriptor], TIOCNXCL) == -1)
            {
                //@throw serialException;
                //NSLog(@"Error opening TIOCNXCL on %@ - %s(%d).\n", [self name], strerror(errno), errno);
            }
            
            // It is good practice to reset a serial port back to the state in
            // which you found it. This is why we saved the original termios struct
            // The constant TCSANOW (defined in termios.h) indicates that
            // the change should take effect immediately.
            if (tcsetattr([self fileDescriptor], TCSANOW, &_originalAttributes) == -1)
            {
                //@throw serialException;
                printf("Error resetting tty attributes - %s(%d).\n",
                       strerror(errno), errno);
            }
            
            
            close([self fileDescriptor]);
            self.fileDescriptor = -1;
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([self.delegate respondsToSelector:@selector(serialPortDidClose)])
                {
                    [self.delegate serialPortDidClose];
                }
            });
        }
        
    });
}


#pragma mark Settings
- (void)startModifyingAttributes
{
    dispatch_async(self.sendQueue, ^ {
        int returnCode;
        
        returnCode = tcgetattr(self.fileDescriptor, &_modifiedAttributes);
        if (returnCode == -1)
        {
            //NSLog(@"Failed to read attributes for %@", self);
            //NSLog(@"is Open %@",[self isOpen] ? @"YES" : @"NO");
        }
    } );
}


- (void)finishModifyingAttributes
{
    dispatch_async(self.sendQueue, ^ {
        int returnCode;
        
        returnCode = tcsetattr(self.fileDescriptor, TCSANOW, &_modifiedAttributes);
        if (returnCode == -1)
        {
            //NSLog(@"Failed to modify attributes for %@", self);
            //NSLog(@"is Open %@",[self isOpen] ? @"YES" : @"NO");
            //NSLog(@"Error setting tty attributes in endModifyingAttributes %s(%d).\n", strerror(errno), errno);
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
            //NSLog(@"Failed to modify attributes for %@", self);
            //NSLog(@"is Open %@",[self isOpen] ? @"YES" : @"NO");
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
        //NSLog(@"Error getting tty attributes in getBaudRate");
        return [NSNumber numberWithInt:returnCode];
    }
    baudRate = [NSNumber numberWithLong:cfgetispeed(&currentAttributes)];
    
	return baudRate;
}


- (void) setBaudRate:(NSNumber *) baudRate;
{
    dispatch_async(self.sendQueue, ^ {
        cfsetispeed(&_modifiedAttributes, [baudRate longValue]);
        cfsetospeed(&_modifiedAttributes, [baudRate longValue]);
    } );
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:baudRate forKey:[NSString stringWithFormat:@"%@-baudRate", self.name]];
}




// [serialPort setFlowControl:EIFlowControlXonXoff];
-(EISerialFlowControl)flowControl
{
    int returnCode;
    struct termios currentAttributes;
    
    returnCode = tcgetattr(self.fileDescriptor, &currentAttributes);
    if (returnCode == -1)
    {
        //NSLog(@"Failed to read attributes for %@", self);
    }
    
    //
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
    dispatch_async(self.sendQueue, ^ {
        switch (method) {
            case EIFlowControlNone:
                _modifiedAttributes.c_iflag &= ~(IXON | IXOFF | IXANY);
                //modifiedAttributes.c_iflag &= ~(IXON | IXOFF);
                _modifiedAttributes.c_cflag &= ~CRTSCTS;
                break;
            case EIFlowControlXonXoff:
                _modifiedAttributes.c_iflag |= (IXON | IXOFF | IXANY);
                //modifiedAttributes.c_iflag |= (IXON | IXANY);
                //modifiedAttributes.c_iflag &= ~(IXOFF);
                //modifiedAttributes.c_iflag |= (IXON | IXOFF);
                _modifiedAttributes.c_cflag &= ~(CCTS_OFLOW | CRTS_IFLOW);
                break;
            case EIFlowControlHardware:
                _modifiedAttributes.c_iflag &= ~(IXON | IXOFF | IXANY);
                //modifiedAttributes.c_iflag &= ~(IXON | IXOFF);
                _modifiedAttributes.c_cflag |= (CCTS_OFLOW | CRTS_IFLOW);
                break;
            default:
                break;
        }
    } );
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[NSNumber numberWithInt:method] forKey:[NSString stringWithFormat:@"%@-flowControl", self.name]];
}



// [serialPort setParity:EIParityNone];
-(EISerialParity)parity
{
    int returnCode;
    struct termios currentAttributes;
    
    returnCode = tcgetattr(self.fileDescriptor, &currentAttributes);
    if (returnCode == -1)
    {
        //NSLog(@"Failed to read attributes for %@", self);
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
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[NSNumber numberWithInt:parity] forKey:[NSString stringWithFormat:@"%@-parity", self.name]];
}


-(uint)minBytesPerRead
{
    int returnCode;
    struct termios currentAttributes;
    
    returnCode = tcgetattr(self.fileDescriptor, &currentAttributes);
    if (returnCode == -1)
    {
        //NSLog(@"Failed to read attributes for %@", self);
    }
    
    return currentAttributes.c_cc[VMIN];
}


-(void)setMinBytesPerRead:(uint)min
{
    dispatch_async(self.sendQueue, ^ {
        _modifiedAttributes.c_cc[VMIN] = min;
    } );
}


-(uint)timeout
{
    int returnCode;
    struct termios currentAttributes;
    
    returnCode = tcgetattr(self.fileDescriptor, &currentAttributes);
    if (returnCode == -1)
    {
        //NSLog(@"Failed to read attributes for %@", self);
    }
    
    return currentAttributes.c_cc[VTIME];
}


-(void)setTimeout:(uint)time
{
    dispatch_async(self.sendQueue, ^ {
        _modifiedAttributes.c_cc[VTIME] = time;
    } );
}


-(void)setRawMode
{
    dispatch_async(self.sendQueue, ^ {
        cfmakeraw(&_modifiedAttributes);
    } );
}


-(void)flushIO
{
    dispatch_async(self.sendQueue, ^ {
        if (tcflush([self fileDescriptor], TCIOFLUSH) == -1)
        {
            printf("Error waiting for drain - %s(%d).\n",
                   strerror(errno), errno);
        }
    } );
}


// [serialPort setStopBits:EIStopbitsOne];
-(EISerialStopBits)stopBits
{
    int returnCode;
    struct termios currentAttributes;
    
    returnCode = tcgetattr(self.fileDescriptor, &currentAttributes);
    if (returnCode == -1)
    {
        //NSLog(@"Failed to read attributes for %@", self);
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
    [defaults setObject:[NSNumber numberWithInt:stopBits] forKey:[NSString stringWithFormat:@"%@-stopBits", self.name]];
}

-(void)setOneStopBit
{
    dispatch_async(self.sendQueue, ^ {
        _modifiedAttributes.c_cflag &= ~CSTOPB;
    } );
}

-(void)setTwoStopBits
{
    dispatch_async(self.sendQueue, ^ {
        _modifiedAttributes.c_cflag |= CSTOPB;
    } );
}


-(EISerialDataBits)dataBits
{
    int returnCode;
    struct termios currentAttributes;
    tcflag_t EI_c_cflag;
    
    returnCode = tcgetattr(self.fileDescriptor, &currentAttributes);
    if (returnCode == -1)
    {
        //NSLog(@"Failed to read attributes for %@", self);
    }
    
    EI_c_cflag = currentAttributes.c_cflag & CSIZE;
    switch (EI_c_cflag) {
        case CS5:
            return EIFiveDataBits;
            break;
        case CS6:
            return EISixDataBits;
            break;
        case CS7:
            return EISevenDataBits;
            break;
        case CS8:
            return EIEightDataBits;
            break;
        default:
            return EIFiveDataBits;
            break;
    }
}

-(void)setDataBits:(EISerialDataBits)dataBits
{
    dispatch_async(self.sendQueue, ^ {
        _modifiedAttributes.c_cflag &= ~CSIZE;
        switch (dataBits) {
            case EIFiveDataBits:
                _modifiedAttributes.c_cflag |= CS5;
                break;
            case EISixDataBits:
                _modifiedAttributes.c_cflag |= CS6;
                break;
            case EISevenDataBits:
                _modifiedAttributes.c_cflag |= CS7;
                break;
            case EIEightDataBits:
                _modifiedAttributes.c_cflag |= CS8;
                break;
            default:
                break;
        }
    } );
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[NSNumber numberWithInt:dataBits] forKey:[NSString stringWithFormat:@"%@-dataBits", self.name]];
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
    NSDictionary *c_iflagsDict = @{ @"IGNBRK " : [NSNumber numberWithInt:IGNBRK], \
                                    @"BRKINT " : [NSNumber numberWithInt:BRKINT], \
                                    @"IGNPAR " : [NSNumber numberWithInt:IGNPAR], \
                                    @"PARMRK " : [NSNumber numberWithInt:PARMRK], \
                                    @"INPCK  " : [NSNumber numberWithInt:INPCK], \
                                    @"ISTRIP " : [NSNumber numberWithInt:ISTRIP], \
                                    @"INLCR  " : [NSNumber numberWithInt:INLCR], \
                                    @"IGNCR  " : [NSNumber numberWithInt:IGNCR], \
                                    @"ICRNL  " : [NSNumber numberWithInt:ICRNL], \
                                    @"IXON   " : [NSNumber numberWithInt:IXON], \
                                    @"IXOFF  " : [NSNumber numberWithInt:IXOFF], \
                                    @"IXANY  " : [NSNumber numberWithInt:IXANY], \
                                    @"IMAXBEL" : [NSNumber numberWithInt:IMAXBEL],};
    
    NSLog(@"c_iflag");
    NSString *key;
    for(key in c_iflagsDict){
        NSLog(@"%@:%@", key, (attributes.c_iflag & [[c_iflagsDict objectForKey: key] intValue]) ? @"TRUE" : @"FALSE");
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
    NSDictionary *c_oflagsDict = @{ @"OPOST " : [NSNumber numberWithInt:OPOST], \
                                    @"ONLCR " : [NSNumber numberWithInt:ONLCR], \
                                    @"OXTABS" : [NSNumber numberWithInt:OXTABS], \
                                    @"ONOEOT" : [NSNumber numberWithInt:ONOEOT], \
                                    @"OCRNL " : [NSNumber numberWithInt:OCRNL], \
                                    @"ONOCR " : [NSNumber numberWithInt:ONOCR], \
                                    @"ONLRET" : [NSNumber numberWithInt:ONLRET],};
    NSLog(@"c_oflag");
    for(key in c_oflagsDict){
        NSLog(@"%@:%@", key, (attributes.c_oflag & [[c_oflagsDict objectForKey: key] intValue]) ? @"TRUE" : @"FALSE");
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
     */
    
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
    NSDictionary *c_lflagDict = @{ @"ECHOKE     " : [NSNumber numberWithInt:ECHOKE], \
                                   @"ECHOE     " : [NSNumber numberWithInt:ECHOE], \
                                   @"ECHO      " : [NSNumber numberWithInt:ECHO], \
                                   @"ECHONL    " : [NSNumber numberWithInt:ECHONL], \
                                   @"ECHOPRT   " : [NSNumber numberWithInt:ECHOPRT], \
                                   @"ECHOCTL   " : [NSNumber numberWithInt:ECHOCTL], \
                                   @"ISIG      " : [NSNumber numberWithInt:ISIG], \
                                   @"ICANON    " : [NSNumber numberWithInt:ICANON],
                                   @"ALTWERASE " : [NSNumber numberWithInt:ALTWERASE], \
                                   @"IEXTEN    " : [NSNumber numberWithInt:IEXTEN], \
                                   @"EXTPROC   " : [NSNumber numberWithInt:EXTPROC], \
                                   @"TOSTOP    " : [NSNumber numberWithInt:TOSTOP], \
                                   @"FLUSHO    " : [NSNumber numberWithInt:FLUSHO], \
                                   @"NOKERNINFO" : [NSNumber numberWithInt:NOKERNINFO], \
                                   @"NOFLSH    " : [NSNumber numberWithInt:NOFLSH], \
                                   @"PENDIN    " : [NSNumber numberWithInt:PENDIN], };
    NSLog(@"c_lflag");
    for(key in c_lflagDict){
        NSLog(@"%@:%@", key, (attributes.c_lflag & [[c_lflagDict objectForKey: key] intValue]) ? @"TRUE" : @"FALSE");
    }
}

- (float) calculateDelayPerByte:(struct termios)attributes
{
    float delay;
    //struct termios copiedAttributes;
    tcflag_t EI_c_cflag;
    NSNumber *baudRate;
    float delayPerBit;
    
    // What is the bad rate
    baudRate = [NSNumber numberWithLong:cfgetispeed(&attributes)];
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
- (void) writeString:(NSString *)aString
{
    NSData *dataToSend = [aString dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
    [self writeData:dataToSend];
}


- (void) writeData:(NSData *)dataToSend
{
    void (^writeData)(void);
    writeData = ^(void) {
        ssize_t numBytes = 0;
        ssize_t bytesSent = 0;
        NSData *toBeSent, *sent;
        uint roomInBuffer, numberOfBytesToSend;
        
        while (bytesSent < [dataToSend length]) {
            
            uint ioctlBytestInBuffer;
            int returnCode = ioctl(self.fileDescriptor, TIOCOUTQ, &ioctlBytestInBuffer);
            if (returnCode == -1)
            {
                //NSLog(@"Error setting TIOCOUTQ on %@ - %s(%d).\n", self.name, strerror(errno), errno);
            }
            
            roomInBuffer = self.idealBufferSize - ioctlBytestInBuffer;
            roomInBuffer = roomInBuffer > self.idealBufferSize ? self.idealBufferSize : roomInBuffer;
            
            numberOfBytesToSend = (uint)MIN(roomInBuffer, ((uint)[dataToSend length] - bytesSent));
            //NSLog(@"Number of Bytes in Buffer:%d Room in Buffer:%d Number of Bytes to send:%d",ioctlBytestInBuffer, roomInBuffer, numberOfBytesToSend);
            
            if (numberOfBytesToSend > 0) {
                toBeSent = [dataToSend subdataWithRange:NSMakeRange(bytesSent, numberOfBytesToSend)];
                numBytes = write(self.fileDescriptor, [toBeSent bytes], [toBeSent length]);
                if (numBytes == -1) {
                    //NSLog(@"Write Error:%s", strerror( errno ));
                    usleep(10000000);
                } else {
                    bytesSent = bytesSent + numBytes;
                    sent = [toBeSent subdataWithRange:NSMakeRange(0, numBytes)];
                    
                }
            } else {
                usleep(5000);
            }
        }
    };
    
    dispatch_async(self.sendQueue, writeData);
}


- (void) writeDelay:(uint)uSleep
{
    dispatch_async(self.sendQueue, ^{ usleep(uSleep); });
}


-(void)sendBreak
{
    //BOOL result = (tcsendbreak(fileDescriptor, 0) != -1);
    tcsendbreak(self.fileDescriptor, 0);
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
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate performSelector:@selector(serialPortDidReceiveData:) withObject:readData];
                    });
                }
			}
		}
	});
}



@end
