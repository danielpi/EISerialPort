# EISerialPort

A Cocoa serial port framework for rapidly developing apps that talk to micro-controllers.

Micro-controller based projects allow you to interact with the physical world, however their UI is usually terrible. Mac OS X apps have beautiful UI but have difficulty affecting the world outside of the computer. Marrying these two worlds gives a great opportunity to improve both areas. This should be simple to achieve.

## How to use this library

The main components of this library are

**EISerialPort** - For every available port on the computer there is an instance of EISerialPort. This object provides an Objective-C interface to the serial port. Opening, Closing, Changing settings, Reading and Writing all go through this object. You don't need to create the EISerialPort objects they are provided by the library. You simply need to choose the one you require from a list.

**EISerialPortSelectionManager** - For each section of your app that requires access to a serial port you should create an instance of EISerialPortSelectionManager. This object keeps track of which port is selected and is able to provide lists of the available ports that are suitable filling out GUI selection controls. It is expected that your controller object will be set as the delegate for the EISerialPortSelectionManager object so that it can respond to changes to the available ports and to the selection.

**EISerialPortManager** - This singleton class manages the creation and destruction of the EISerialPort objects in response to their addition or removal from the computer. You don't need to use this class as the EISerialPortSelectionManager provides the same functions with extra bells and whistles added.

###What you need to do

EISerialPort is meant to be used to build GUI applications that can make use of serial ports. It attempts to make it easy to present ports and the data that flows in and out of them to a user in a standard cocoa application. 

It is expected that your app will need to present some or all of the following to the user
- A list of ports to be selected from
- Controls to select the settings required of the port
- ASCII/binary view of the data that is being transferred via the port
- The state of the port (opened, closed, present or not, blocked)
- The state of data transfer (are characters being sent/received, how far through the download list are we)

You need to provide a controller object that can mediate between the EISerialPort library and the GUI controls. It will need to be set as the delegate to the EISerialPortSelectionManager as well as the selected EISerialPort. Details below.


## Finding and selecting serial ports
Serial ports have become a lot more dynamic in recent years. Instead of built in ports with fixed names we now have USB and Bluetooth ports which come and go. Any program that interacts with serial ports should
- Be able to identify the ports that are actually available
- Handle ports that are added or removed from the system during operation
- Identify which underlying comms method is backing the port (USB, Bluetooth)
- Remember which port was previously used the last time the app was open

Each section of your program that is going to require access to a port is assumed to have its own controller object (a view, window or app controller for instance). This controller object is in charge of creating an EISerialPortSelectionController object. It will also be the delegate for the EISerialPortSelectionController object. One way to do this would be the following

    - (void)applicationDidFinishLaunching:(NSNotification *)aNotification
    {
        // Insert code here to initialize your application
        _portSelectionController = [[EISerialPortSelectionController alloc] initWithLabel:@"window1"];
        [_portSelectionController setDelegate:self];
    }
    
Note that when you create an EISerialPortSelectionController object you specify a label. This is to identify what the selected port will do within your program. If for example you wrote an app that used two ports, one for bootstrap loading and one for telemetry you might use the labels "bootstrap" and "telemetry" for the two EISerialPortSelectionController objects. This way which port is used for each task can be remembered when your program restarts.

The _portSelectionController maintains a list of the available ports as well as a couple of other lists which make it easy to fill out GUI selection controls. To get an alphabetically sorted list of ports you could use the following

	NSArray *ports = [_portSelectionController availablePorts];

You can select a port by asking for it by name. You should then set its delegate. The previously selected port will have its delegate set to nil automatically.

	[[_portSelectionController selectedPort] setDelegate:nil]; // Disconnect from the port that was last used
	[_portSelectionController selectPortWithName:@"name_of_one_of_the_ports"];

The methods that must be implemented inorder to conform to the EISerialPortSelectionManagerDelegate protocol are

	- (void) availablePortsListDidChange;
	- (void) selectedSerialPortDidChange;
	
The *availablePortsListDidChange* method is called whenever a port is added or removed from the computer (for instance if a USB to serial adaptor is plugged or unplugged). Your controller should request the updated list of ports from the EISerialPortSelectionManager object and then update any of the GUI selection controls that are visible to the user.

One possible implementation of the availablePortsListDidChange method for a PopUpButton GUI is as follows

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

The *selectedSerialPortDidChange* method is called when the EISerialPortSelectionManager has changed the selected port. Here again your controller needs to consult the EISerialPortSelectionManager, find out which port is currently selected and update any selection controls. If there is no selection the selectedPort: method will return nil. When you implement this function you should set the serial ports delegate at this point.

As an example


    - (void) selectedSerialPortDidChange
    {
        if (_portSelectionController.selectedPort != nil) {
            [[_portSelectionController selectedPort] setDelegate:self];
        }
        [self updateSerialPortUI];
    }

When your controller decides to change the selected serial port there are a couple of tasks you should perform.
- If the previous port is open you should close it
- You should also set the previous ports delegate to nil if that is appropriate
- finally you need to call the selectPortWithName: function of the selection controller so that the new port is actually selected.

Here is an example


    - (IBAction) changeSerialPortSelection:(id)sender
    {
        EISerialPort *previouslySelectedPort = [_portSelectionController selectedPort];
        NSString *newlySelectedPortName = [[self.serialSelectionPopUp selectedItem] title];
        
        if ([previouslySelectedPort isOpen]) {
            [previouslySelectedPort close];
        }
        [previouslySelectedPort setDelegate:nil];
        [_portSelectionController selectPortWithName:newlySelectedPortName];
    }

## Opening a port

A port can either be opened in a blocking or non-blocking manner

    BOOL successful = [port openByBlocking]; 
    \\ blocks execution until port is open, could take several seconds
    
    [port open];           
    \\ returns immediately, port will be opened shortly after
    
	BOOL isPortOpen = [port isOpen];

Your controller needs to implement the following delegate methods

    - (void) serialPortDidOpen;
    - (void) serialPortFailedToOpenWithError:(NSError *) anError; \\ Should this return an NSError???
   
Your UI should make it clear whether the selected port is open or not. If a port fails to open then a decent description of the failure should be presented to the user.


## Changing settings

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
 
Your controller should implement the following delegate method for dealing with settings changes.

	- (void) serialPortDidChangeSettings;


## Reading from a port

The simplest way to receive data from the serial port is to implement the 
EISerialPortDelegate Protocol.

	- (void) serialPortDidReceiveData:(NSData *)data

http://www.cocoawithlove.com/2008/06/five-approaches-to-listening-observing.html


## Sending data out of a port

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

#### Sending large amounts of data

Sending large amounts of data, such as transferring an entire file, can have additional requirements compared to just sending keystrokes or a line or two. These requirements and challenges include
- The data needs to be transfered as fast as possible
- The progress of transfer should be displayed to the user
- The user should be able to see that the transfer is continuing
- The ability to cancel the transfer if something goes wrong is important
- If something goes wrong you would like to know at which point in the transferred data the error occurred. (I can't do this at the moment)

This is all made difficult by the fact that there are multiple buffers between your sending code and the actual serial line (USB caches, Bluetooth packets etc). 

To cancel the current transmission

	[port cancelCurrentTransmission];
	
To see how much data is left to be transmitted

    [port numberOfBytesInBuffer];
    
To see when characters are passed into the serial port implement the following delegate method. This is at the interface between the application and the operating system. So still all of the USB buffering to go through before the characters are on the wire.

	- (void) serialPortDidSendData:(NSData *)sent;
	


## Closing a port

To close a port

    [port close];
    
It is important that when a serial port is closed or removed that your code handles its own cleanup. This can be done in the delegate function

    - (void) serialPortDidClose;
    
If a serial port is removed from the system e.g. if a USB to serial converter is unplugged, then the EISerial port object will be deleted from the system. Before deallocating itself it will call the serialPortWillBeRemovedFromSystem delegate method so that 3rd party code can perform its own cleanup.

    - (void)serialPortWillBeRemovedFromSystem:(EISerialPort *)serialPort;

If you do accidentally try to use a port that has been removed (prior to it being released by the system) the framework will not crash. It will simply ignore your request. *** Not sure how to do this.


## Adding a serial terminal to your app

It should be easy to add a serial terminal to an app. Every app that does any sort of serial comms could benefit from having a serial terminal that allowed you to see the communications. Therefore the port must broadcast the comms characters to multiple objects within the app.

It is also important to be able to control how the comms is displayed. Some options  are
- VT100 style parsing
- Raw bytes in and out
- Packets wrapped as tokens



-----------------------------

-----------------------------













### Programatically selecting a port
You use an EISerialPortSelectionController object to handle the selection of a port for a particular use. Below is a very simple example of selecting a port programatically.

	EISerialPortSelectionController *portSelection = [[EISerialPortSelectionController alloc] initWithLabel:@"aLabelOfYourChoice"];
	NSArray *ports = [portSelection availablePorts];
	
	[portSelection selectPortWithName:@"name of one of the ports"];
	NSLog(@"%@", [portSelection selectedPort]);

Things to note
- The EISerialPortSelectionController instance, portSelection, know which ports are available on the system. It maintains an array via the availablePorts property.
- You can ask the portSelection object to select a port by name. It will then keep a reference to that port via its selectedPort property
- When you create an EISerialPortSelectionController object you specify a label. This is to identify what the selected port will do within your program. If for example you wrote an app that used two ports, one for bootstrap loading and one for telemetry you might use the labels "bootstrap" and "telemetry" for the two EISerialPortSelectionController objects that you use. This way which port is used for each task can be remembered when your program restarts.

### Selecting a port from a GUI
More often than not you are going to want to have some way of graphically selecting a port. EISerialPort tries to make this as easy as possible by providing the required data for several standard selection methods.

####Using a Pop Up Button
![Example of a PopUp Button](/Users/danielpi/repos/EISerialPort/README_Images/PopUpButton_Screenshot.png)

PopUp buttons are a convenient method of providing a list of ports to be selected from. To use them you need to cover the following steps

- Add a NSPopUpButton to your UI from Interface Builder
- Create a EISerialPortSelectionController object within your own controller object and set its delegate to your controller object
- Make your controller object (a view, window or app controller) conform to the EISerialPortSelectionDelegate protocol.
- Implement the following methods
	- serialPortsListDidChange
	- serialPortSelectionDidChange
	- serialPortWillBeRemovedFromSystem:(EISerialPort *)serialPort



When your 

    - (void)applicationDidFinishLaunching:(NSNotification *)aNotification
    {
        // Insert code here to initialize your application
        _portSelectionController = [[EISerialPortSelectionController alloc] initWithLabel:@"window1"];
        [_portSelectionController setDelegate:self];
    }
	


## Programatic Interface
### Finding and selecting serial ports
Main features of serial port selection
- Easy to find out which ports are available
- Easy to fill GUI selection controls with the correct options
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

Would be good if ports that are already opened are greyed out in any other selection list. So if you have a second terminal open you can't select an open port from another window. Or should you be able to have multiple windows open to the same port. Broadcast received text to all controls within the same app and batch any sends. This is what I want to happen for multiple different views of the data.




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


### Receiving data from a Serial Port


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




## Overall Architecture

- EISerialPortManager is a singleton. It keeps a set of all available ports. When the operating system provides a notification that a port has been added or removed from the system the EISerialPortManager adds or removes the port from its set. It also initialises or destroys the port itself. Via KVO the EISerialPortSelectionController is also notified that the list of ports has changed.
- There is one EISerialPort for every available port. This is how you interact with the serial port. When a port is removed the EISerialPort dissappears.
- EISerialPortSelectionController stores the currently selected port. It has a delegate that is often the view controller for the app.
- NSPopupButton. Used to select a port. Gets controlled by the view controller above.
- Serial Text View. Intercepts keystrokes and serial comms. Needs to register with the serial port so that it can receive incoming character events as well as port removed events.


## Notifications

### Port added to the system
- The operating system provides a notification to the EISerialPortManager.
- EISerialPortManager initialises an EISerialPort object and adds it to its availablePorts set.
- Via KVO, all EISerialPortSelectionControllers are notified that the availablePorts set has changed.
- Each EISerialPortSelectionController notifies its delegate that the ports list has changed via the serialPortsListDidChange delgate method.
- Each of the view controllers needs to query the Selection Controller for an updated list of ports and then instigate UI updates in each of the controls that it overseas.

### Port removed from the system
- The operating system provides a notification to the EISerialPortManager.
- EISerialPortManager initialises an EISerialPort object and adds it to its availablePorts set.
- Via KVO, all EISerialPortSelectionControllers are notified that the availablePorts set has changed.
- Each EISerialPortSelectionController notifies its delegate that the ports list has changed via the serialPortsListDidChange delgate method.
- The view controller needs to query the Selection Controller for an updated list of ports and then instigate UI updates in each of the controls that it overseas.

### Serial port selected
- The UI element used for selection reports back to the view controller which port has been chosen.
- The window controller tells the EISerialPortSelectionController which port has been selected.
- The EISerialPortSelectionController sets it's selectedPort property to this port and calls the delegate method serialPortSelectionDidChange:
- The view controller queries the Selection Controller for an updated list of ports and then instigates any required UI updates in each of the controls that it overseas.

### Selected port removed from the system

### Selected port settings changed

### Selected port opened
- UI control messages the view controller to open the selected port
- View Controller asks the Selection controller for the selected port and then tells it to open.
- The port sends out an EISerialPortDidOpen notification

### Selected port closed

### Characters are received into an opened serial port
- The port sends out notifications…

### Serial port settings get changed


## Status Indicator
The overall status of the serial port needs to be easy to display to the end user. The states that I think are relevant are
- Open
- Closed
- Closing
- Error

A toolbar button is a likely place to display this information. It would contain an image indicating the current state as well as a word indicating the process that would be undertaken if the button were pressed. 

## GUI

### Selection
From a menu, popup, tableview

### Open/close button
Button used for opening, closing a serial port. 

Needs to be able to show
- should be greyed out if there is no port selected
- should allow you to open a port
- should show that it is attempting to open a port
- should allow you to cancel opening a port???
- should show if a port failed to open
- should give a popup explaining the fault that occurred


## Improvements

I'm planning on working my way through Matt Gemmell's advice on API design (http://mattgemmell.com/api-design/). His advice seems so obvious when I read it yet when I look at my code I see so many possible improvements. Therefore I think I should work through his advice and treat it as a checklist.

### EISerialPortSelectionController.h
- **What is the class?** The EISerialPortSelectionController is in charger of the selection of the serial port by the end user. It provides a list of available ports, keeps track of which port is selected, stores a record of which port was selected during the last running of the application.

- **What is the class like?** I'm not sure. It looks to me like the selection section of Cocoa bindings is exactly what I am trying to replicate. However I struggle to get my head around cocoa bindings and I want this class to be easier to understand.




