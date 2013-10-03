# EISerialPort

A Serial Port Framework for rapidly developing apps that talk to micro controllers.

Micro controller based projects are lots of fun and they allow you to interact with the physical world. But their UI is usually terrible. Mac OS X apps have beautiful UI but have difficulty affecting the world outside of the computer. Marrying these two worlds give a great opportunity to improve both areas. This should be simple to achieve.

Keywords for the framework
- Robust
- reliable
- efficient
- fast
- easy to use

## Programatic Interface
### Finding and selecting serial ports
Main features of serial port selection
- Easy to get a list of available ports
- Easy to get lists that are tailored to specific GUI controls
- Notifications are sent as the available ports are changed
- Previously selected ports are remembered across app restarts
- Can select multiple ports within an app (all are remembered across restarts)
- If the selected port is removed notifications are sent and GUI controls provide feedback to the user.


When you want to select a serial port it is best to use an EISerialPortSelectionController object. It maintains an EISerialPort property for the currently selected port. It also maintains a bunch of convenience methods for generating suitable lists of the available ports for use with various UI controls (NSPopUpButton, NSTableView, NSMenu).

First up here is an example of programatically selecting a port.

	EISerialPortSelectionController *portSelection = [[EISerialPortSelectionController alloc] initWithLabel:@"programatically"];
	NSArray *ports = [portSelection availablePorts];
	
	ports = [list of ports]
	
	[portSelection selectPortWithName:@"name of one of the ports"];
	NSLog(@"%@", [portSelection selectedPort]);
	
One of the advantages of using EISerialPortSelectionController is that it provides a bunch of notifications. KVO, Notification Center, Delegate methods.




Should be easy to find the serial ports that are actually available and to select one by name.

    portManager = [EISerialPortManager sharedManager];
    NSSet *ports = [portManager availablePorts];
    
	EISerialPort *port = [portManager portWithName:@"USBserialPort1"];

The port manager maintains a set of ports which is not the most convenient collection type for selecting a port. It is the most appropriate for the port manager as it is required to maintain an unordered, unique list of the ports that are on the system.

You can use Key-Value Observing for the EISerialPortManagers availablePorts set in order to be notified when ports are added or removed from the system.

More than this though we need a way to fill out GUI selectors easily and to handle the selected port. We need to be able to have multiple selection too. So if you have three open windows you can have three different serial ports selected.

This is where the EISerialPortSelectionController comes in. You create one instance of the selection controller for every serial port that you need to access. It keeps track of port that has been selected as well as providing convenience functions for filling out GUI elements that can be used for selecting the port. When you create a selection controller you give it a label. In the case of an app that used two serial ports, one for a programmer and one for telemetry feedback the two selection controllers would have different identifying labels. Which port is selected for which task is saved to user defaults automatically so that the selection is remembered from one app use to the next.

As a basic help the selection controller can provide an array of the available serial ports that is sorted alphabetically.

You can also access a list that is targeted at a popup button. So it contains a "Select Serial Port" top item and if the selected serial port is removed from the system the message is displayed in the popup button.

### Opening and closing a serial port

A port can either be opened in a blocking or non-blocking manner

    BOOL successful = [port openByBlocking]; 
    \\ blocks execution until port is open, could take several seconds
    
    [port open];           
    \\ returns immediately, port will be opened shortly after
    
	BOOL isPortOpen = [port isOpen];

The delegate method

    - (void) serialPortDidOpen;
    - (void) serialPortFailedToOpen;
   
Provides a callback to alert your program when the port had been opened.

To close a port

    [port close];
    
It is important that when a serial port is closed or removed that your code handles its own cleanup. This can be done in the delegate function

    - (void)serialPortDidClose:(EISerialPort *)serialPort;
    
If a serial port is removed from the system e.g. if a USB to serial converter is unplugged, then the EISerial port object will be deleted from the system. Before deallocating itself it will call the serialPortWillBeRemovedFromSystem delegate method so that 3rd party code can perform its own cleanup.

    - (void)serialPortWillBeRemovedFromSystem:(EISerialPort *)serialPort;

If you do accidentally try to use a port that has been removed (prior to it being released by the system) the framework will not crash. It will simply ignore your request. *** Not sure how to do this.

### Serial Port settings
The serial port settings can be modified using Objective-C code. The settings changes can be called individually or batched together. Batching settings changes using the startModifyingSettings and finishModifyingSettings method calls allows multiple settings to be modified without reaching into the kernel multiple times.

	// Individual setting change
	[port setBaudRate:@19200];
	// Baud rate is changed immediately

	// Batch settings changes
	[port startModifyingSettings];
		[port setRawMode];
		[port setMinBytesPerRead:1];
		[port setTimeout:10];
		[port setBaudRate:@19200];
		[port setFlowControl:EIFlowControlXonXoff];
		[port setOneStopBit];
		[port setDataBits:EIEightDataBits];
		[port setParity:EIParityNone];
	[port finishModifyingSettings];

Settings changes are synchronised with write operations. This means that even though port opening, port settings and port IO commands happen asynchronously they never happen out of order (If you change the board rate and then send some text it will definitely be transmitted at the requested baud rate).

    [port open];
    
    [port startModifyingSettings];
    [port setBaudRate:@19200];
    [port finishModifyingSettings];
    
    [port writeString:@"blah blah blah"]; \\ 19200 baud guaranteed
    
    [port startModifyingSettings];
    [port setBaudRate:@2400];
    [port finishModifyingSettings];
    
    [port writeString:@"do do do"];       \\ 2400 baud guaranteed
 
You can also receive notification about settings changes via the delegate methods

    - (void) serialPortSettingsWillChange;
	- (void) serialPortSettingsDidChange;
	
The settings are also Key-Value Observer compliant so that they can be used with cocoa bindings.

### Sending data to a Serial Port

There are a couple of ways to send characters out of the serial port to a micro.

If you simply want to send a string of characters you can use the following method. This will do an asynchronous send, returning immediately.

    [port sendString:@"blah blah blah"];
    
NSData objects can also be sent

	char bytes[] = { 0x80 };
    NSData *data = [[NSData alloc] initWithBytes:bytes length:sizeof(bytes)];
    [port sendData:data];
    

Large bodies of characters can be sent with the kernel handling the caching. However there is little feedback or options for modifications to the text once they have been sent to the kernel. As such it is recommended that the sent data is spit into smaller chunks.

    [port sendString:aLargeString inChunksSplitBy:@"\n"];
    [port sendString:aLargeString inChunksOfSize:240];

The functions that are used for sending data out of the serial port are asynchronous and return immediately after they are called. The serial port itself though requires a certain amount of time in which to pass each of the characters out to the wire. The EISerial framework provides a delegate call back when it thinks the message has been sent (there is no direct feedback from within the kernel). 

	// Both of these delegate functions are called when we estimate that the
	// data has been sent out of the serial port.
	- (void) serialPortDidSendData:(NSData *)sentData ofLength:(uint)len;
	- (void) serialPortDidSendString:(NSString *)sentString;

This is not the whole story unfortunately. An attached device can also pause transmission via the various flow control mechanisms. The EISerial framework is unable to get feedback on these delays which would then make the feedback from the delegate methods above in accurate. As a result they are disabled unless the flow control setting is set to off.

Sometimes it is required to have a delay between the sending of two chunks of data. Due to the asynchronous behaviour of the framework a special delay function is needed that inserts the delay in the correct spot in the transmit queue.

    [port delayTransmissionForDuration:0.1];
    
You can also send a break command for a specified duration

	[port sendBreak];
	[port sendBreakForDuration:0.1];
	
Note: Delays should be specified as doubles of seconds using the NSTimeInterval type.

#### Pausing Transmission

At times it may be desirable to stop the output of characters from the serial port. EISerial allows you to pause and resume transmission. The other common operation is to flush the transmit buffer.

In order to pause and resume transmission you can call the following functions

	[port pause];
	BOOL isPaused = [port isPaused];
	[port flushTransmit];
	[port resume];
	


### Receiving data from a Serial Port

The simplest way to receive data from the serial port is to implement the 
EISerialPortDelegate Protocol.

	- (void)serialPort:(EISerialPort *)serialPort didReceiveData:(NSData *)data


EISerialPort objects can also broadcast the output from a serial port. You will need to have an object that complies to the EISerialPortDelegate Protocol. Instead of setting it as the delegate though you can register it as an observer. This allows you to also set a different queue in which the callback will be run.

    [port registerObserver:myCustomObject1];
    [port registerObserver:myCustomObject2 usingQueue:myCustomObjectQueue];

Here is a pseudo code explanation of what EISerialPort does when it receives data from the serial port.

	dispatch_async the following on the provided queue
		Check if the receiving object is still valid
		Check that it has the right function
		Call the function with the data


Implementation details for me

    dispatch_async(myCustomObjectQueue, ^{
    	if ([(id)myCustomObject2 respondsToSelector:@selector(serialPort:didReceiveData:)]){
				[myCustomObject2 serialPort:self didReceiveData:data];
			}
    	});

http://www.cocoawithlove.com/2008/06/five-approaches-to-listening-observing.html

## User Interface Controls

### Displaying Serial Port Communications in a TextView
A Serial Terminal View control is provided to make it easy to display and interact with the communications on the serial port. In order to use it simply drag an NSTextView onto your window in IB and change the custom class to EISerialTextView.

The EISerialTextView has a built in settings bar which is hidden by default. You can set it to be displayed with the following

    [serialTextView setSettingsControlsHidden:NO];
    
### Selecting a Serial Port

Not sure where to go from here. I would like to have a set of UI components that handle serial port selection for you. It seems crazy to have to reimplement these each time for each different application. Controls that I think could be interesting

- Popup button
- Table View (several variations)
- Menu items
- Pop up Menu

All selection controls need to be able to handle the following

- Display all of the ports by name (and type???)
- Allow new ports to be added and removed at any time
- Display the currently selected port
- Allow the selection to be changed
- Show that some ports are unavailable for selection
- Show that a selected port has been removed

Some selection controls also need to be able to handle the following

- Display of port status and settings
- modification of port status and settings

I'm not sure whether EISerial should own the selection task entirely or hand it off to a delegate. How is multiple selection handled? Should the control or the EISerialPortManager maintain knowledge of the selection? Lots of questions.








