//
//  EISerialPortSelectionController.m
//  EISerialPortExample
//
//  Created by Daniel Pink on 30/09/13.
//  Copyright (c) 2013 Electronic Innovations. All rights reserved.
//

#import "EISerialPortSelectionController.h"
#import "EISerialPortManager.h"
#import "EISerialPort.h"

NSString * const EISelectedSerialPortNameKey = @"selectedSerialPortNameKey";

@interface EISerialPortSelectionController ()
@property (readonly, weak) EISerialPortManager *portManager;
@end



@implementation EISerialPortSelectionController

- (id) initWithLabel:(NSString *)label delegate:(id<EISerialPortSelectionDelegate>)delegate
{
    self = [super init];
    if (self) {
        _portManager = [EISerialPortManager sharedManager];
        _label = label;
        _selectedPort = nil;
        _delegate = delegate;
        
        [_portManager addObserver:self
                       forKeyPath:@"availablePorts"
                          options:NSKeyValueObservingOptionNew
                          context:NULL];
        [self performSelector:@selector(checkUserDefaultsForPreviousSelection) withObject:nil afterDelay:0.3];
    }
    return self;
}

- (id) initWithLabel:(NSString *)label
{
    self = [[EISerialPortSelectionController alloc] initWithLabel:label delegate:nil];
    return self;
}

- (id) init
{
    // Would be good if the auto generated label could be gauranteed to be unique but repeatable. 
    self = [[EISerialPortSelectionController alloc] initWithLabel:@"EISerialPort_defaultPortLabel"];
    return self;
}


- (void) checkUserDefaultsForPreviousSelection
{
    // Select the port used last if possible
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *selectedPortName = [defaults objectForKey:_label];
    EISerialPort *defaultPort = [_portManager serialPortWithName:selectedPortName];
    
    NSLog(@"Default port:%@", defaultPort);
    //NSLog(@"Available ports:%@", _portManager.availablePorts);
    
    if ([defaultPort isNotEqualTo:nil]) {
        [self selectPortWithName:selectedPortName];
    }
}


- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if ([keyPath isEqual:@"availablePorts"]) {
        // Check to see if the currently selected port has been removed
        if (![self.portManager.availablePorts containsObject:self.selectedPort] && (self.selectedPort != nil)) {
            [self selectPortWithName:nil];
        }
        if ([self.delegate respondsToSelector:@selector(availablePortsForSelectionControllerDidChange:)]) {
            [self.delegate availablePortsForSelectionControllerDidChange:self];
        }
    }
    /*
     Be sure to call the superclass's implementation *if it implements it*.
     NSObject does not implement the method.
     
    [super observeValueForKeyPath:keyPath
                         ofObject:object
                           change:change
                          context:context];
    */
}


- (NSIndexSet *)selectedPortIndex
{
    if (!self.selectedPort) {
        return nil;
    } else {
        return [[NSIndexSet alloc] initWithIndex: [self.availablePorts indexOfObject:self.selectedPort]];
    }
}


- (NSArray *)availablePorts
{
    NSArray *sortedPorts;
    NSSortDescriptor *sortDesc = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES];
    
    sortedPorts = [self.portManager.availablePorts sortedArrayUsingDescriptors:[NSArray arrayWithObject:sortDesc]];
    return sortedPorts;
}


- (NSArray *)popUpButtonDetails
{
    NSMutableArray *portTitles;
    
    portTitles = [[NSMutableArray alloc] initWithCapacity:10];
    [portTitles addObject:@{@"name":@"Select Port", @"enabled":@NO}];

    for (EISerialPort *port in self.availablePorts){
        [portTitles addObject:@{@"name":port.name, @"enabled":@YES}];
    }
    
    return portTitles;
}


- (BOOL) shouldChangeSelection
{
    if ([self.delegate respondsToSelector:@selector(selectedPortForSelectionControllerShouldChange:)]) {
        if ([self.delegate selectedPortForSelectionControllerShouldChange:self]) {
            return YES;
        } else {
            return NO;
        }
    } else {
        return YES;
    }
}


- (void) willChangeSelection
{
    if ([self.delegate respondsToSelector:@selector(selectedPortForSelectionControllerWillChange:)]) {
        [self.delegate selectedPortForSelectionControllerWillChange:self];
    }
}


- (void) didChangeSelection
{
    if ([self.delegate respondsToSelector:@selector(selectedPortForSelectionControllerDidChange:)]) {
        [self.delegate selectedPortForSelectionControllerDidChange:self];
    }
}


- (BOOL) selectPortWithName:(NSString *)portName
{
    if ([self shouldChangeSelection]) {
        [self willChangeSelection];
        if (portName != nil) {
            _selectedPort = [self.portManager serialPortWithName:portName];
            
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            [defaults setObject:portName forKey:self.label];
        } else {
            _selectedPort = nil;
        }
        [self didChangeSelection];
        
        return YES;
    } else {
        return NO;
    }
}

@end

/*
 Manual User Interface Tests
 
 Popup Button
 Wire up a popup button to an EISerialPortSelectionController. The following should be testable
 - Open the popup and see the complete list of available ports. Plus "Select Port" greyed out at the top
 - Plugin a USB port and it should appear in the list (when the list is open or closed)
 - Remove a USB port and it should be removed
 - "Select Port" should be greyed out all the time
 - Select a port and the little tick should become attached to it
 - Close the program and open it again. The previously selected port should be selected
 - Select a USB port, then remove it. The port name shold be replaced with a greyed out "Port Removed".
 - Close the program and restart with the USB plug back in and it should be selected
 
 */


