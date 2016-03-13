//
//  AppDelegate.swift
//  EISerialPortSwiftExample
//
//  Created by Daniel Pink on 26/08/2014.
//  Copyright (c) 2014 Electronic Innovations. All rights reserved.
//

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate, EISerialPortSelectionDelegate, EISerialPortDelegate, EISerialTextViewDelegate {
                            
    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var openCloseButton: NSButton!
    @IBOutlet weak var serialPortSelectionPopUp: NSPopUpButton!
    @IBOutlet var terminalView: EISerialTextView!
    var portSelectionController: EISerialPortSelectionController = EISerialPortSelectionController(label: "Main")
    

    func applicationDidFinishLaunching(aNotification: NSNotification?) {
        // Insert code here to initialize your application
        portSelectionController.delegate = self
        terminalView.delegate = self
    }

    func applicationWillTerminate(aNotification: NSNotification?) {
        // Insert code here to tear down your application
    }

    @IBAction func openOrClose(sender: AnyObject) {
        if let currentPort = portSelectionController.selectedPort {
            if (currentPort.open) {
                currentPort.close()
            } else {
                currentPort.open()
            }
        }
    }
    
    @IBAction func changePortSelection(sender: AnyObject) {
        if let previouslySelectedPort = portSelectionController.selectedPort {
            if previouslySelectedPort.open {
                previouslySelectedPort.close()
            }
            previouslySelectedPort.delegate = nil
        }
        
        if let newlySelectedPortName = serialPortSelectionPopUp.selectedItem.title {
            portSelectionController.selectPortWithName(newlySelectedPortName)
        }
    }

    func updateSerialPortUI() {
        
        if let currentPort = portSelectionController.selectedPort {
            serialPortSelectionPopUp.selectItemWithTitle(currentPort.name)
            openCloseButton.enabled = true
            if (currentPort.open) {
                openCloseButton.title = "Close"
            } else {
                openCloseButton.title = "Open"
            }
        } else {
            serialPortSelectionPopUp.selectItemAtIndex(0)
            openCloseButton.title = "Open"
            openCloseButton.enabled = false
        }
    }

    // MARK: EISerialPortSelectionDelegate
    func availablePortsForSelectionControllerDidChange(controller: EISerialPortSelectionController!) {

        serialPortSelectionPopUp.removeAllItems()

        for portDetails in controller.popUpButtonDetails() {
            let portName = portDetails["name"] as! String
            let portEnabled = portDetails["enabled"] as! Bool
            serialPortSelectionPopUp.addItemWithTitle(portName)
            serialPortSelectionPopUp.itemWithTitle(portName).enabled = true
        }
    }

    func selectedPortForSelectionControllerWillChange(controller: EISerialPortSelectionController!) {
        if let portDelegate: AnyObject = controller.selectedPort?.delegate {
            controller.selectedPort.delegate = nil
        }
    }

    func selectedPortForSelectionControllerDidChange(controller: EISerialPortSelectionController!) {
        if (controller.selectedPort != nil) {
            controller.selectedPort.delegate = self
        }
        self.updateSerialPortUI()
    }

    
    // MARK: EISerialPortDelegate
    func serialPortDidOpen(port: EISerialPort!) {
        updateSerialPortUI()
        port.baudRate = 57600
        port.dataBits = EIDataBitsEight
        port.parity = EIParityNone
        port.stopBits = EIStopbitsOne
    }
    
    func serialPortDidClose(port: EISerialPort!) {
        updateSerialPortUI()
    }
    
    func serialPort(port: EISerialPort!, didReceiveData data: NSData!) {
        terminalView.appendCharacters(data)
    }
    
    func serialPort(port: EISerialPort!, experiencedAnError anError: NSError!) {
        window.presentError(anError)
    }
    
    // MARK: EISerialTextViewDelegate
    func receivedDataFromUser(data: NSData!) {
        if let selectedPort = portSelectionController.selectedPort {
            selectedPort.sendData(data)
        }
    }
    
    func receivedStringFromUser(string: String!) {
        if let selectedPort = portSelectionController.selectedPort {
            selectedPort.sendString(string)
        }
    }

}

