//
//  EISerialPortManager.h
//  SerialCocoaFive
//
//  Created by Daniel Pink on Fri Sep 12 2003.
//  Copyright (c) 2003 Electronic Innovations Pty. Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
@class EISerialPort;

/** The EISerialPortManager class provides access to the serial ports that
 * are available on the system. It monitors the ports as the are added and
 * removed and maintains an array of EISerialPort objects which can be 
 * accessed by your code.
 *
 * EISerialPortManager follows the Singleton design pattern, enforcing that
 * there is only ever a single EISerialPortManager object present.
 */

@interface EISerialPortManager : NSObject

/** Returns the single instance of the serial port manager that is available to the system */
+ (EISerialPortManager *) sharedManager;

/** Accessor for the list of available serial ports*/
- (NSSet *) availablePorts;
//- (NSSet *) knownPorts;

/** Allows you to select a port if you know its name */
- (EISerialPort *) serialPortWithName:(NSString *)aName;

//extern NSString *EISerialPortAvailablePortsDidChange;

@end
