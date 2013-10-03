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

- (id) initWithLabel:(NSString *)label
{
    self = [super init];
    if (self) {
        _portManager = [EISerialPortManager sharedManager];
        _label = label;
        _selectedPort = nil;
        
        [_portManager addObserver:self
                       forKeyPath:@"availablePorts"
                          options:NSKeyValueObservingOptionNew
                          context:NULL];
        [self performSelector:@selector(checkUserDefaultsForPreviousSelection) withObject:nil afterDelay:0.1];
    }
    return self;
}

- (id) init
{
    self = [[EISerialPortSelectionController alloc] initWithLabel:@"default"];
    return self;
}

- (void) checkUserDefaultsForPreviousSelection
{
    // Select the port used last if possible
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *selectedPortName = [defaults objectForKey:_label];
    EISerialPort *defaultPort = [_portManager serialPortWithName:selectedPortName];
    
    NSLog(@"Default port:%@", defaultPort);
    NSLog(@"Available ports:%@", _portManager.availablePorts);
    
    //NSLog(@"valueForKey:%@",[_portManager valueForKey:@"availablePorts"]);
    
    if ([defaultPort isNotEqualTo:nil]) {
        [self changeSelectionToPortNamed:selectedPortName];
        NSLog(@"Default port:%@", selectedPortName);
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    
    NSLog(@"Object:%@ keyPath:%@ were observed", object, keyPath);
    
    if ([keyPath isEqual:@"availablePorts"]) {
        [self serialPortsListDidChange];
        if ( [_delegate respondsToSelector:@selector(serialPortsListDidChange)] ) {
            [_delegate serialPortsListDidChange];
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

- (void)serialPortsListDidChange
{
    // Check if the selected port was removed.
}

- (NSArray *)availablePortsAlphabetical
{
    NSArray *sortedPorts;
    NSSortDescriptor *sortDesc = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES];
    
    sortedPorts = [_portManager.availablePorts sortedArrayUsingDescriptors:[NSArray arrayWithObject:sortDesc]];
    return sortedPorts;
}

- (NSArray *)popUpButtonDetails
{
    NSMutableArray *portTitles;
    
    portTitles = [[NSMutableArray alloc] initWithCapacity:10];
    [portTitles addObject:@{@"name":@"Select Port", @"enabled":@NO}];
    /*
    if (![_portManager.availablePorts containsObject:previousSelection]) {
        [self changeSelectionToPortNamed:nil];
        [portTitles addObject:@{@"name":@"Port Removed!", @"enabled":@NO}];
    }
    */
    for (EISerialPort *port in self.availablePortsAlphabetical){
        [portTitles addObject:@{@"name":port.name, @"enabled":@YES}];
    }
    
    return portTitles;
}

- (void) changeSelectionToPortNamed:(NSString *)portName
{
    if (portName != nil) {
        _selectedPort = [_portManager serialPortWithName:portName];
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:portName forKey:_label];
    } else {
        _selectedPort = nil;
    }
    
    if ( [_delegate respondsToSelector:@selector(serialPortSelectionDidChange)] ) {
        [_delegate serialPortSelectionDidChange];
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
 - 
 
 
 
 */


