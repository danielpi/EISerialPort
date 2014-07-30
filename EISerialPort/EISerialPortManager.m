//
//  EISerialPortManager.m
//  SerialCocoaFive
//
//  Created by Daniel Pink on Fri Sep 12 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import "EISerialPort.h"
#import "EISerialPortManager.h"

#include <IOKit/IOBSD.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/serial/IOSerialKeys.h>


@interface EISerialPortManager ()

@property (readwrite, strong, nonatomic) NSMutableSet *availablePorts;

+(EISerialPortManager *)sharedManager;
- (EISerialPortManager *) init;

- (EISerialPort *)serialPortWithName:(NSString *)withName;

- (void)getAvailablePortsAndSetupNotifications;

- (NSUInteger)countOfAvailablePorts;
- (NSEnumerator *)enumeratorOfAvailablePorts;
- (EISerialPort *)memberOfAvailablePorts:(EISerialPort *)anObject;
- (void) addAvailablePortsObject:(EISerialPort *)port;
- (void) removeAvailablePortsObject:(EISerialPort *)port;

void EISerialPortAdded(id self, io_iterator_t iter);
void EISerialPortRemoved(id self, io_iterator_t iter);

@end





@implementation EISerialPortManager : NSObject

+(EISerialPortManager *)sharedManager
{
    static dispatch_once_t predicate;
    static EISerialPortManager *sharedPortManager = nil;
    
    dispatch_once(&predicate, ^{
        sharedPortManager = [[EISerialPortManager alloc] init];
    });
    return sharedPortManager;
}

#pragma mark - Object Lifecycle

- (EISerialPortManager *) init
{
    self = [super init]; // or call the designated initalizer
    if (self) {
        _availablePorts = [[NSMutableSet alloc] init];
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [self getAvailablePortsAndSetupNotifications];
        }];
        
    }
    
    return self;
}


- (EISerialPort *)serialPortWithName:(NSString *)withName
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name == %@", withName];
    NSSet *filteredSet = [self.availablePorts filteredSetUsingPredicate:predicate];
    return [filteredSet anyObject];
}

- (NSSet *)availablePorts
{
    NSSet *ports;
    ports = [_availablePorts copy];
    return ports;
}

// KVO Compliance
/*
+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)theKey {
    
    BOOL automatic = NO;
    if ([theKey isEqualToString:@"availablePorts"]) {
        automatic = NO;
    }
    else {
        automatic = [super automaticallyNotifiesObserversForKey:theKey];
    }
    return automatic;
}
*/
- (NSUInteger)countOfAvailablePorts
{
    return [_availablePorts count];
}


- (NSEnumerator *)enumeratorOfAvailablePorts
{
    return [_availablePorts objectEnumerator];
}


- (EISerialPort *)memberOfAvailablePorts:(EISerialPort *)anObject
{
    return [_availablePorts member:anObject];
}


- (void) addAvailablePortsObject:(EISerialPort *)port
{
    [_availablePorts addObject:port];
}

- (void) removeAvailablePortsObject:(EISerialPort *)port
{
    [_availablePorts removeObject:port];
}



//- (BOOL)getAvailablePortsError:(NSError **)anError
- (void)getAvailablePortsAndSetupNotifications
{
    //mach_port_t masterPort;
    kern_return_t kernResult;
    io_object_t serialService;
    io_iterator_t matchingServices;
    CFMutableDictionaryRef classesToMatch;
    
    
    // Establish a connection to I/O Kit
    //kernResult = IOMasterPort(MACH_PORT_NULL, &masterPort);
    //if (KERN_SUCCESS != kernResult) { printf("IOMasterPort returned %d\n", kernResult); }

    // Create a matching dictionary
    classesToMatch = IOServiceMatching(kIOSerialBSDServiceValue);
    if (classesToMatch == NULL) { 
        printf("IOServiceMatching returned a NULL dictionary.\n");
        // These really should produce NSError objects and break program flow
    } else {
        CFDictionarySetValue(classesToMatch,
                             CFSTR(kIOSerialBSDTypeKey),
                             CFSTR(kIOSerialBSDAllTypes));
    }
    
    // Obtain an iterator object
    kernResult = IOServiceGetMatchingServices(kIOMasterPortDefault, CFDictionaryCreateMutableCopy(NULL, 0, classesToMatch), &matchingServices);
    if (KERN_SUCCESS != kernResult) 
    { 
        printf("IOServiceGetMatchingServices returned %d\n", kernResult);
        // These really should produce NSError objects and break program flow
    }
    
    // Fill our array with EISerialPort Objects
    while ((serialService = IOIteratorNext(matchingServices)))
    {
        EISerialPort *serialObject;
        serialObject = [[EISerialPort alloc] initWithIOObject:serialService];
        [self addAvailablePortsObject:serialObject];
        IOObjectRelease(serialService);
    }
    
    // Setup the notification of serial ports being added to the system
    IONotificationPortRef notificationPort = IONotificationPortCreate(kIOMasterPortDefault);
    
    CFRunLoopAddSource(CFRunLoopGetCurrent(), IONotificationPortGetRunLoopSource(notificationPort), kCFRunLoopCommonModes);
    
    // Notification types
    // #define kIOPublishNotification		"IOServicePublish"
    // #define kIOFirstPublishNotification	"IOServiceFirstPublish"
    // #define kIOMatchedNotification		"IOServiceMatched"
    // #define kIOFirstMatchNotification	"IOServiceFirstMatch"
    // #define kIOTerminatedNotification	"IOServiceTerminate"
    
    // NOTE IOServiceAddMatchingNotification uses the dictionary, so we pass a copy
    IOServiceAddMatchingNotification(notificationPort,
                                     kIOPublishNotification,
                                     CFDictionaryCreateMutableCopy(NULL, 0, classesToMatch),
                                     (IOServiceMatchingCallback)EISerialPortAdded,
                                     (__bridge void *)(self), &matchingServices);
    while (IOIteratorNext(matchingServices)) {}; // could call serial_port_added(self, serialPortIterator) to notify of existing serial ports
    
    IOServiceAddMatchingNotification(notificationPort,
                                     kIOTerminatedNotification,
                                     CFDictionaryCreateMutableCopy(NULL, 0, classesToMatch),
                                     (IOServiceMatchingCallback)EISerialPortRemoved,
                                     (__bridge  void *)(self), &matchingServices);
    while (IOIteratorNext(matchingServices)) {};
    //CFRelease(classesToMatch);
}

/*
- (void)stopWatchingForSerialPorts 
{
    CFRunLoopRemoveSource(CFRunLoopGetMain(), IONotificationPortGetRunLoopSource(notificationPort), kCFRunLoopDefaultMode);
    IONotificationPortDestroy(notificationPort);
    IOObjectRelease(serialPortIterator);
}
 */

void EISerialPortAdded(id self, io_iterator_t iter)
{
    EISerialPort *serialObject;
    
    io_registry_entry_t serialPort;
    while ((serialPort = IOIteratorNext(iter))) {
        serialObject = [[EISerialPort alloc] initWithIOObject:serialPort];
        [self addAvailablePortsObject:serialObject];
    }
}

void EISerialPortRemoved(id self, io_iterator_t iter)
{
    EISerialPort *serialObject;
    
    io_registry_entry_t serialPort;
    while ((serialPort = IOIteratorNext(iter))) {
        serialObject = [[EISerialPort alloc] initWithIOObject:serialPort];
        [self removeAvailablePortsObject:serialObject];
        IOObjectRelease(serialPort);
    }
}


@end
