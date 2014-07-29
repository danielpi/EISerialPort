//
//  EISerialPortSelectionController.h
//  EISerialPortExample
//
//  Created by Daniel Pink on 30/09/13.
//  Copyright (c) 2013 Electronic Innovations. All rights reserved.
//

#import <Foundation/Foundation.h>

@class EISerialPort;
@class EISerialPortSelectionController;


@protocol EISerialPortSelectionDelegate <NSObject>
@optional
- (void) availablePortsForSelectionControllerDidChange:(EISerialPortSelectionController *)controller;

- (BOOL) selectedPortForSelectionControllerShouldChange:(EISerialPortSelectionController *)controller;
- (void) selectedPortForSelectionControllerWillChange:(EISerialPortSelectionController *)controller;
- (void) selectedPortForSelectionControllerDidChange:(EISerialPortSelectionController *)controller;
@end



@interface EISerialPortSelectionController : NSObject

@property (readwrite, unsafe_unretained) id<EISerialPortSelectionDelegate> delegate;
@property (readonly, strong) NSString *label;   // Used to identify each instance in the defaults
@property (readonly, weak) EISerialPort *selectedPort;  // Defaults to the port that was selected when your app was last open. Nil if that port is no longer available.
@property (readonly, strong) NSIndexSet *selectedPortIndex;

- (id)initWithLabel:(NSString *)label; // Use a label that describes the section of your app that this port will be used for
- (id)initWithLabel:(NSString *)label delegate:(id<EISerialPortSelectionDelegate>) delegate;

- (BOOL)selectPortWithName:(NSString *)portName; // Return value indicates if the change was successful or not

- (NSArray *)availablePorts;    // Always sorted alphabetically
- (NSArray *)popUpButtonDetails;    // An array of dictionaries with keys of "name" and "enabled"

@end



extern NSString * const EISelectedSerialPortNameKey;