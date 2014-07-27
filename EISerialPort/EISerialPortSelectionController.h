//
//  EISerialPortSelectionController.h
//  EISerialPortExample
//
//  Created by Daniel Pink on 30/09/13.
//  Copyright (c) 2013 Electronic Innovations. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EISerialPortManager.h"

@class EISerialPort;
@class EISerialPortSelectionController;

@protocol EISerialPortSelectionDelegate

- (void) availablePortsListDidChange;
- (void) availablePortsListDidChangeForSelectionController:(EISerialPortSelectionController *)controller;
//- (void) availablePortsListDidChangeForSelectionControllerLabelled:(NSString *)controllerLabel;

- (void) selectedSerialPortDidChange;
- (void) selectedSerialPortDidChangeForSelectionController:(EISerialPortSelectionController *)controller;
//- (void) selectedSerialPortDidChangeForSelectionControllerLabelled:(NSString *)controllerLabel;
@end


extern NSString * const EISelectedSerialPortNameKey;


@interface EISerialPortSelectionController : NSObject

@property (readwrite, unsafe_unretained) id delegate;
@property (readonly, strong) NSString *label;   // Used to identify each instance in the defaults
@property (readonly, weak) EISerialPort *selectedPort;  // Defaults to the port that was selected when your app was last open. Nil if that port is no longer available.
@property (readonly, strong) NSIndexSet *selectedPortIndex;

- (id)initWithLabel:(NSString *)label; // Use a label that describes the section of your app that this port will be used for
- (void)selectPortWithName:(NSString *)portName;

- (NSArray *)availablePorts;    // Always sorted alphabetically
- (NSArray *)popUpButtonDetails;    // An array of dictionaries with keys of "name" and "enabled"

@end
