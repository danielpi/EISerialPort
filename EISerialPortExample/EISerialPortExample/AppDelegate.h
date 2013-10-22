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

@interface AppDelegate : NSObject <NSApplicationDelegate, EISerialPortSelectionDelegate, EISerialDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (readonly, strong) EISerialPortSelectionController *portSelectionController;

@property (weak) IBOutlet NSPopUpButton *serialPortSelectionPopUp;
@property (weak) IBOutlet NSButton *openOrCloseButton;
@property (weak) IBOutlet NSPopUpButton *baudRatePopUp;
@property (weak) IBOutlet NSPopUpButton *dataBitsPopUp;
@property (weak) IBOutlet NSPopUpButton *parityPopUp;
@property (weak) IBOutlet NSPopUpButton *stopBitsPopUp;
@property (weak) IBOutlet NSPopUpButton *flowControlPopUp;
@property (unsafe_unretained) IBOutlet NSTextView *terminalView;

- (IBAction)changeSerialPortSelection:(id)sender;
- (IBAction)openOrCloseSerialPort:(id)sender;
- (IBAction)changeBaudRate:(id)sender;
- (IBAction)changeDataBits:(id)sender;
- (IBAction)changeParity:(id)sender;
- (IBAction)changeStopBits:(id)sender;
- (IBAction)changeFlowControl:(id)sender;

- (void)availablePortsListDidChange;
- (void)selectedSerialPortDidChange;

@end
