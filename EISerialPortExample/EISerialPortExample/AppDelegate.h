//
//  AppDelegate.h
//  EISerialPortExample
//
//  Created by Daniel Pink on 25/09/13.
//  Copyright (c) 2013 Electronic Innovations. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "EISerialPort.h"
#import "EISerialPortManager.h"
#import "EISerialPortSelectionController.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, EISerialPortSelectionDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (readonly) EISerialPortManager *portManager;
@property (readonly, strong) EISerialPortSelectionController *portSelectionController;

@property (weak) IBOutlet NSPopUpButton *serialPortSelectionPopUp;
@property (weak) IBOutlet NSTextField *selectedPortNameLabel;

- (IBAction) changeSerialPortSelection:(id)sender;

- (void) serialPortsListDidChange;
- (void) serialPortSelectionDidChange;

@end
