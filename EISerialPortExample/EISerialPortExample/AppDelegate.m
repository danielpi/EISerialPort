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
    //self.portManager = [EISerialPortManager sharedManager];
    _portSelectionController = [[EISerialPortSelectionController alloc] initWithLabel:@"window1"];
    [_portSelectionController setDelegate:self];
    [_terminalView setDelegate:self];
    //NSLog(@"Port Manager:%@", _portManager);
}


- (void) updateSerialPortUI
{
    EISerialPort *currentPort;
    
    currentPort = [self.portSelectionController selectedPort];
    
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
            [self.baudRatePopUp addItemsWithTitles:self.portSelectionController.selectedPort.baudRateLabels];
            [self.baudRatePopUp selectItemWithTitle:self.portSelectionController.selectedPort.baudRate.stringValue];
            
            [self.dataBitsPopUp removeAllItems];
            [self.dataBitsPopUp addItemWithTitle:@"Data Bits"];
            [self.dataBitsPopUp setEnabled:YES];
            [self.dataBitsPopUp addItemsWithTitles:self.portSelectionController.selectedPort.dataBitLabels];
            [self.dataBitsPopUp selectItemAtIndex:(self.portSelectionController.selectedPort.dataBits + 1)];
            
            [self.parityPopUp removeAllItems];
            [self.parityPopUp addItemWithTitle:@"Parity"];
            [self.parityPopUp setEnabled:YES];
            [self.parityPopUp addItemsWithTitles:self.portSelectionController.selectedPort.parityLabels];
            [self.parityPopUp selectItemAtIndex:(self.portSelectionController.selectedPort.parity + 1)];
            
            [self.stopBitsPopUp removeAllItems];
            [self.stopBitsPopUp addItemWithTitle:@"Stop Bits"];
            [self.stopBitsPopUp setEnabled:YES];
            [self.stopBitsPopUp addItemsWithTitles:self.portSelectionController.selectedPort.stopBitLabels];
            [self.stopBitsPopUp selectItemAtIndex:(self.portSelectionController.selectedPort.stopBits + 1)];
            
            [self.flowControlPopUp removeAllItems];
            [self.flowControlPopUp addItemWithTitle:@"Flow Control"];
            [self.flowControlPopUp setEnabled:YES];
            [self.flowControlPopUp addItemsWithTitles:self.portSelectionController.selectedPort.flowControlLabels];
            [self.flowControlPopUp selectItemAtIndex:(self.portSelectionController.selectedPort.flowControl + 1)];
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
    EISerialPort *previouslySelectedPort = [self.portSelectionController selectedPort];
    NSString *newlySelectedPortName = [[self.serialPortSelectionPopUp selectedItem] title];
    
    if ([previouslySelectedPort isOpen]) {
        [previouslySelectedPort close];
    }
    [previouslySelectedPort setDelegate:nil];
    [self.portSelectionController selectPortWithName:newlySelectedPortName];
}

- (IBAction) openOrCloseSerialPort:(id)sender
{
    NSLog(@"Open Or Close");
    if ([self.portSelectionController.selectedPort isOpen]) {
        [self.portSelectionController.selectedPort close];
    } else {
        [self.portSelectionController.selectedPort open];
    }
}

- (IBAction)changeBaudRate:(id)sender
{
    NSString *baudRateString;
    NSNumber *baudRateNumber;
    EISerialPort *currentPort;
    NSNumberFormatter *baudRateNumberFormatter;
    
    baudRateString = [[self.baudRatePopUp selectedItem] title];
    currentPort = self.portSelectionController.selectedPort;
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
    currentPort = self.portSelectionController.selectedPort;
    dataBitsIndex = [currentPort.dataBitLabels indexOfObject:dataBitsString];
    
    [currentPort setDataBits:(EISerialDataBits)dataBitsIndex];
}

- (IBAction)changeParity:(id)sender
{
    NSString *parityString;
    EISerialPort *currentPort;
    NSUInteger parityIndex;
    
    parityString = [[self.parityPopUp selectedItem] title];
    currentPort = self.portSelectionController.selectedPort;
    parityIndex = [currentPort.parityLabels indexOfObject:parityString];
    
    [currentPort setParity:(EISerialParity)parityIndex];
}

- (IBAction)changeStopBits:(id)sender
{
    NSString *stopBitsString;
    EISerialPort *currentPort;
    NSUInteger stopBitsIndex;
    
    stopBitsString = [[self.stopBitsPopUp selectedItem] title];
    currentPort = self.portSelectionController.selectedPort;
    stopBitsIndex = [currentPort.stopBitLabels indexOfObject:stopBitsString];
    
    [currentPort setStopBits:(EISerialStopBits)stopBitsIndex];
}

- (IBAction)changeFlowControl:(id)sender
{
    NSString *flowControlString;
    EISerialPort *currentPort;
    NSUInteger flowControlIndex;
    
    flowControlString = [[self.flowControlPopUp selectedItem] title];
    currentPort = self.portSelectionController.selectedPort;
    flowControlIndex = [currentPort.flowControlLabels indexOfObject:flowControlString];
    
    [currentPort setFlowControl:(EISerialFlowControl)flowControlIndex];
}



#pragma mark EISerialPortSelectionDelegate
- (void) availablePortsForSelectionControllerDidChange:(EISerialPortSelectionController *)controller
{
    [self.serialPortSelectionPopUp removeAllItems];
    
    for (NSDictionary *portDetails in controller.popUpButtonDetails){
        NSString *portName = [portDetails valueForKey:@"name"];
        BOOL portEnabled = [[portDetails valueForKey:@"enabled"] boolValue];
        [self.serialPortSelectionPopUp addItemWithTitle:portName];
        [[self.serialPortSelectionPopUp itemWithTitle:portName] setEnabled:portEnabled];
    }
}

- (BOOL) selectedPortForSelectionControllerShouldChange:(EISerialPortSelectionController *)controller
{
    return YES;
}

- (void) selectedPortForSelectionControllerWillChange:(EISerialPortSelectionController *)controller
{
    [controller.selectedPort setDelegate:nil];
}

- (void) selectedPortForSelectionControllerDidChange:(EISerialPortSelectionController *)controller
{
    if (controller.selectedPort != nil) {
        [controller.selectedPort setDelegate:self];
    }
    [self updateSerialPortUI];
}


#pragma mark EISerialDelegate

- (void) serialPortDidOpen:(EISerialPort *)port
{
    [self updateSerialPortUI];
    NSLog(@"Port Opened: %@", [self.portSelectionController selectedPort]);
}

- (void) serialPortDidClose:(EISerialPort *)port
{
    [self updateSerialPortUI];
    NSLog(@"Port Closed: %@", [self.portSelectionController selectedPort]);
}

- (void) serialPort:(EISerialPort *)port didReceiveData:(NSData *)data
{
    [self.terminalView appendCharacters:data];
}

- (void) serialPort:(EISerialPort *)port experiencedAnError:(NSError *)anError
{
    [[self window] presentError:anError];
}


#pragma mark EISerialTextViewDelegate

- (void)receivedDataFromUser:(NSData *)data
{
    [self.portSelectionController.selectedPort sendData:data];
}

- (void)receivedStringFromUser:(NSString *)string
{
    [self.portSelectionController.selectedPort sendString:string];
}

@end
