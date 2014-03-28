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
@property (readonly, strong) NSString *label;
@property (readonly, weak) EISerialPort *selectedPort;
@property (readonly, strong) NSIndexSet *selectedPortIndex;

- (id)initWithLabel:(NSString *)label;
- (void)selectPortWithName:(NSString *)portName;

- (NSArray *)availablePorts;
- (NSArray *)popUpButtonDetails;

@end
