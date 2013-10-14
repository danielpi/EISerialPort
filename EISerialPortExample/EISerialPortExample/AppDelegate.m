//
//  AppDelegate.m
//  EISerialPortExample
//
//  Created by Daniel Pink on 25/09/13.
//  Copyright (c) 2013 Electronic Innovations. All rights reserved.
//

#import "AppDelegate.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    _portManager = [EISerialPortManager sharedManager];
    _portSelectionController = [[EISerialPortSelectionController alloc] initWithLabel:@"window1"];
    [_portSelectionController setDelegate:self];
    NSLog(@"Port Manager:%@", _portManager);
}


- (IBAction) changeSerialPortSelection:(id)sender
{
    NSString *selectedPortName = [[self.serialPortSelectionPopUp selectedItem] title];
    NSLog(@"Selected: %@", selectedPortName);
    [_portSelectionController changeSelectionToPortNamed:selectedPortName];
}


- (void) serialPortSelectionDidChange
{
    NSString *selectedPortName;
    
    if (_portSelectionController.selectedPort != nil) {
        selectedPortName = [_portSelectionController.selectedPort name];
        if ([[self.serialPortSelectionPopUp selectedItem] title] != selectedPortName) {
            [self.serialPortSelectionPopUp selectItemWithTitle:selectedPortName];
            // Update whatever else needs the current serial port
            
        }
        [self.selectedPortNameLabel setStringValue:selectedPortName];
    } else {
        [self.selectedPortNameLabel setStringValue:@"<none>"];
    }
}


- (void) serialPortsListDidChange
{
    [self.serialPortSelectionPopUp removeAllItems];
    
    for (NSDictionary *portDetails in _portSelectionController.popUpButtonDetails){
        NSString *portName = [portDetails valueForKey:@"name"];
        BOOL portEnabled = [[portDetails valueForKey:@"enabled"] boolValue];
        [self.serialPortSelectionPopUp addItemWithTitle:portName];
        [[self.serialPortSelectionPopUp itemWithTitle:portName] setEnabled:portEnabled];
        [self serialPortSelectionDidChange];
    }
}

- (void)serialPortWillBeRemovedFromSystem:(EISerialPort *)serialPort
{
    
}

@end
