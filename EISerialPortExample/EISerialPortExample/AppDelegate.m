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
    //_portManager = [EISerialPortManager sharedManager];
    _portSelectionController = [[EISerialPortSelectionController alloc] initWithLabel:@"window1"];
    [_portSelectionController setDelegate:self];
    //NSLog(@"Port Manager:%@", _portManager);
}


- (void) updateSerialPortUI
{
    EISerialPort *currentPort;
    
    currentPort = [_portSelectionController selectedPort];
    
    if (currentPort == nil) {
        [self.serialPortSelectionPopUp selectItemAtIndex:0];
        
        [self.openOrCloseButton setTitle:@"Open"];
        [self.openOrCloseButton setEnabled:NO];
        
        [self.baudRatePopUp selectItemAtIndex:0];
        [self.dataBitsPopUp selectItemAtIndex:0];
        [self.parityPopUp selectItemAtIndex:0];
        [self.stopBitsPopUp selectItemAtIndex:0];
        [self.flowControlPopUp selectItemAtIndex:0];
        
        [self.baudRatePopUp setEnabled:NO];
        [self.dataBitsPopUp setEnabled:NO];
        [self.parityPopUp setEnabled:NO];
        [self.stopBitsPopUp setEnabled:NO];
        [self.flowControlPopUp setEnabled:NO];
    } else {
        // Make sure the selection list is correct
        [self.serialPortSelectionPopUp selectItemWithTitle:currentPort.name];
        
        // Set the Open/Close button to have the right label
        [self.openOrCloseButton setEnabled:YES];
        if ([currentPort isOpen]) {
            [self.openOrCloseButton setTitle:@"Close"];
            
            [self.baudRatePopUp removeAllItems];
            [self.baudRatePopUp addItemWithTitle:@"Baud Rate"];
            [self.baudRatePopUp setEnabled:YES];
            [self.baudRatePopUp addItemsWithTitles:_portSelectionController.selectedPort.baudRateLabels];
            [self.baudRatePopUp selectItemWithTitle:_portSelectionController.selectedPort.baudRate.stringValue];
            
            [self.dataBitsPopUp removeAllItems];
            [self.dataBitsPopUp addItemWithTitle:@"Data Bits"];
            [self.dataBitsPopUp setEnabled:YES];
            [self.dataBitsPopUp addItemsWithTitles:_portSelectionController.selectedPort.dataBitLabels];
            [self.dataBitsPopUp selectItemAtIndex:(_portSelectionController.selectedPort.dataBits + 1)];
            
            [self.parityPopUp removeAllItems];
            [self.parityPopUp addItemWithTitle:@"Parity"];
            [self.parityPopUp setEnabled:YES];
            [self.parityPopUp addItemsWithTitles:_portSelectionController.selectedPort.parityLabels];
            [self.parityPopUp selectItemAtIndex:(_portSelectionController.selectedPort.parity + 1)];
            
            [self.stopBitsPopUp removeAllItems];
            [self.stopBitsPopUp addItemWithTitle:@"Stop Bits"];
            [self.stopBitsPopUp setEnabled:YES];
            [self.stopBitsPopUp addItemsWithTitles:_portSelectionController.selectedPort.stopBitLabels];
            [self.stopBitsPopUp selectItemAtIndex:(_portSelectionController.selectedPort.stopBits + 1)];
            
            [self.flowControlPopUp removeAllItems];
            [self.flowControlPopUp addItemWithTitle:@"Flow Control"];
            [self.flowControlPopUp setEnabled:YES];
            [self.flowControlPopUp addItemsWithTitles:_portSelectionController.selectedPort.flowControlLabels];
            [self.flowControlPopUp selectItemAtIndex:(_portSelectionController.selectedPort.flowControl + 1)];
        } else {
            [self.openOrCloseButton setTitle:@"Open"];
            
            [self.baudRatePopUp setEnabled:NO];
            [self.dataBitsPopUp setEnabled:NO];
            [self.parityPopUp setEnabled:NO];
            [self.stopBitsPopUp setEnabled:NO];
            [self.flowControlPopUp setEnabled:NO];
        }
    }
}


#pragma mark IBAction Methods

- (IBAction) changeSerialPortSelection:(id)sender
{
    EISerialPort *previouslySelectedPort = [_portSelectionController selectedPort];
    NSString *newlySelectedPortName = [[self.serialPortSelectionPopUp selectedItem] title];
    
    if ([previouslySelectedPort isOpen]) {
        [previouslySelectedPort close];
    }
    [previouslySelectedPort setDelegate:nil];
    [_portSelectionController selectPortWithName:newlySelectedPortName];
}

- (IBAction) openOrCloseSerialPort:(id)sender
{
    if ([_portSelectionController.selectedPort isOpen]) {
        [_portSelectionController.selectedPort close];
    } else {
        [_portSelectionController.selectedPort open];
    }
}

- (IBAction)changeBaudRate:(id)sender
{
    NSString *baudRateString;
    NSNumber *baudRateNumber;
    EISerialPort *currentPort;
    NSNumberFormatter *baudRateNumberFormatter;
    
    baudRateString = [[self.baudRatePopUp selectedItem] title];
    currentPort = _portSelectionController.selectedPort;
    baudRateNumberFormatter = [[NSNumberFormatter alloc] init];
    [baudRateNumberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
    
    baudRateNumber = [baudRateNumberFormatter numberFromString:baudRateString];
    
    [currentPort setBaudRate:baudRateNumber];
}

- (IBAction)changeDataBits:(id)sender
{
    NSString *dataBitsString;
    EISerialPort *currentPort;
    NSUInteger dataBitsIndex;
    
    dataBitsString = [[self.dataBitsPopUp selectedItem] title];
    currentPort = _portSelectionController.selectedPort;
    dataBitsIndex = [currentPort.dataBitLabels indexOfObject:dataBitsString];
    
    [currentPort setDataBits:(EISerialDataBits)dataBitsIndex];
}

- (IBAction)changeParity:(id)sender
{
    NSString *parityString;
    EISerialPort *currentPort;
    NSUInteger parityIndex;
    
    parityString = [[self.parityPopUp selectedItem] title];
    currentPort = _portSelectionController.selectedPort;
    parityIndex = [currentPort.parityLabels indexOfObject:parityString];
    
    [currentPort setParity:(EISerialParity)parityIndex];
}

- (IBAction)changeStopBits:(id)sender
{
    NSString *stopBitsString;
    EISerialPort *currentPort;
    NSUInteger stopBitsIndex;
    
    stopBitsString = [[self.stopBitsPopUp selectedItem] title];
    currentPort = _portSelectionController.selectedPort;
    stopBitsIndex = [currentPort.stopBitLabels indexOfObject:stopBitsString];
    
    [currentPort setStopBits:(EISerialStopBits)stopBitsIndex];
}

- (IBAction)changeFlowControl:(id)sender
{
    NSString *flowControlString;
    EISerialPort *currentPort;
    NSUInteger flowControlIndex;
    
    flowControlString = [[self.flowControlPopUp selectedItem] title];
    currentPort = _portSelectionController.selectedPort;
    flowControlIndex = [currentPort.flowControlLabels indexOfObject:flowControlString];
    
    [currentPort setFlowControl:(EISerialFlowControl)flowControlIndex];
}



#pragma mark EISerialPortSelectionDelegate

- (void) selectedSerialPortDidChange
{
    if (_portSelectionController.selectedPort != nil) {
        [[_portSelectionController selectedPort] setDelegate:self];
    }
    [self updateSerialPortUI];
}

- (void) availablePortsListDidChange
{
    [self.serialPortSelectionPopUp removeAllItems];
    
    for (NSDictionary *portDetails in _portSelectionController.popUpButtonDetails){
        NSString *portName = [portDetails valueForKey:@"name"];
        BOOL portEnabled = [[portDetails valueForKey:@"enabled"] boolValue];
        [self.serialPortSelectionPopUp addItemWithTitle:portName];
        [[self.serialPortSelectionPopUp itemWithTitle:portName] setEnabled:portEnabled];
    }
}


#pragma mark EISerialDelegate

- (void) serialPortDidOpen
{
    [self updateSerialPortUI];
    NSLog(@"Port Opened: %@", [_portSelectionController selectedPort]);
}

- (void) serialPortFailedToOpen
{
    [self updateSerialPortUI];
    NSLog(@"Port Failed to Open: %@", [_portSelectionController selectedPort]);
}

- (void) serialPortDidClose
{
    [self updateSerialPortUI];
    NSLog(@"Port Closed: %@", [_portSelectionController selectedPort]);
}

- (void) serialPortDidReceiveData:(NSData *)data
{
    NSString *receivedString = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
    
    [self.terminalView insertText:receivedString];
}


@end
