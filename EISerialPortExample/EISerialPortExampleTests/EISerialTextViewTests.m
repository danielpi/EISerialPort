//
//  EISerialTextViewTests.m
//  EISerialPortExample
//
//  Created by Daniel Pink on 6/02/2014.
//  Copyright (c) 2014 Electronic Innovations. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "EISerialTextView.h"

@interface EISerialTextViewTests : XCTestCase

@property (readwrite, strong) EISerialTextView *textView;
@property (readwrite, strong) NSData *data;
@property (readwrite, strong) NSString *string;
@property BOOL sendBreakReceived;
@property (readwrite, strong) NSConditionLock * theLock;

@end

@implementation EISerialTextViewTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    
    _textView = [[EISerialTextView alloc] init];
    [_textView setDelegate:self];
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    //self.sendBreakReceived = NO;
    _data  = nil;
    //self.string = nil;
    [super tearDown];
}


#pragma mark EISerialTextViewDelegate
- (void)receivedDataFromUser:(NSData *)data
{
    self.data = data;
}
/*
- (void)receivedStringFromUser:(NSString *)string
{
    self.string = string;
}
*/
- (void)sendBreak
{
    self.sendBreakReceived = YES;
}


#pragma mark keyDown tests
- (NSEvent *)keyDownEventFromKeyCode:(UInt)byte
{
    char bytes[] = { byte };
    NSData *data = [[NSData alloc] initWithBytes:bytes length:sizeof(bytes)];
    NSString *string = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
    
    NSEvent *event = [NSEvent keyEventWithType:NSKeyDown
                                      location:NSPointFromString(@"")
                                 modifierFlags:0
                                     timestamp:0.0
                                  windowNumber:1
                                       context:[NSGraphicsContext currentContext]
                                    characters:string
                   charactersIgnoringModifiers:string
                                     isARepeat:NO
                                       keyCode:byte];
    return event;
}



- (void)testStraightThroughKeyDown
{
    // Test all of the Key Down characters that should go straight through un affected
    for (int i = 0; i < 127; i++) {
        NSEvent *event = [self keyDownEventFromKeyCode:i];
        
        [self.textView keyDown:event];
        
        UInt theInteger;
        [self.data getBytes:&theInteger length:sizeof(theInteger)];
        XCTAssertTrue(theInteger == i, @"Sent %d but received %d", i, theInteger);
    }
}

- (void)testDELKeyDown
{
    const unichar BS = 8;
    const unichar DEL = 127;
    
    NSEvent *event = [self keyDownEventFromKeyCode:DEL];
    
    [self.textView keyDown:event];
    
    UInt theInteger;
    [self.data getBytes:&theInteger length:sizeof(theInteger)];
    XCTAssertTrue(theInteger == BS, @"Sent DEL (%d), expecting BS (%d) but received %d", DEL, BS, theInteger);
}


#pragma mark appendString tests

- (void)testAppendString
{
    NSString *inputString = [NSString stringWithFormat:@"1234 1234 1234 \r\n1234 1234 1234 \r\n"];
    NSString *expectedOutput = [NSString stringWithFormat:@"1234 1234 1234 \n1234 1234 1234 \n"];
    
    [self.textView appendString:inputString];
    
    XCTAssertEqualObjects(expectedOutput, self.textView.textStorage.mutableString, @"");
}

- (void)testCarraigeReturnOverright
{
    NSString *inputString = [NSString stringWithFormat:@"1234 1234 1234\r1234 1234 1234"];
    NSString *expectedOutput = [NSString stringWithFormat:@"1234 1234 1234"];
    
    [self.textView appendString:inputString];
        
    XCTAssertEqualObjects(expectedOutput, self.textView.textStorage.mutableString, @"");
}

@end
