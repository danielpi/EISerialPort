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


@protocol EISerialPortSelectionDelegate

- (void) availablePortsListDidChange;
- (void) selectedSerialPortDidChange;

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
