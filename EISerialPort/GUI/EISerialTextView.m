//
//  EISerialTextView.m
//  Weetbix
//
//  Created by Daniel Pink on 10/01/12.
//  Copyright (c) 2012 Electronic Innovations. All rights reserved.
//

#import "EISerialTextView.h"

NSString *EIDidPartialWriteData = @"EIDidPartialWriteData";

@implementation EISerialTextView

@synthesize serialPort;
@synthesize controlCharactersSet;
@synthesize terminalInsertionPoint;
@synthesize xoffTime;
@synthesize scrollCoalesenceTimer;
@synthesize pauseDisplay;

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
        
        //**** Does this code actually get called? ******
        //[self setAllowsUndo:NO];
        //[self setRichText:NO];
        
        //self.controlCharactersSet = [NSCharacterSet controlCharacterSet];
        //NSLog(@"Control Characters:%@",self.controlCharactersSet);
        //[portController setTextView:self];
        //overlayView = [[OverlayView alloc] initWithFrame:[self frame]];
        //[overlayView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        //[overlayView setHidden:YES];
        //[[self superview] addSubview:overlayView];
    }
    
    return self;
}

-(void)awakeFromNib
{
    NSRange endRange;
    
    NSLog(@"Awake From Nib Serial Text View");
    
    [self setAllowsUndo:NO];
    [self setRichText:NO];
    
    //NSRange controlCharacterRange;
    //controlCharacterRange.location = 0x00;
    //controlCharacterRange.length = 9;
    //NSMutableCharacterSet *customControlCharacterSet = [NSMutableCharacterSet characterSetWithRange:controlCharacterRange];
    //controlCharacterRange.location = 0x0B;
    //controlCharacterRange.length = 21;
    //[customControlCharacterSet formUnionWithCharacterSet:[NSCharacterSet characterSetWithRange:controlCharacterRange]];
    self.controlCharactersSet = [NSCharacterSet controlCharacterSet];
    //self.controlCharactersSet = customControlCharacterSet;
    //NSLog(@"Control Characters:%@",self.controlCharactersSet);
    
    // Stop the line wrap from happening
    [[self textContainer] setContainerSize:NSMakeSize(FLT_MAX, FLT_MAX)];
    [[self textContainer] setWidthTracksTextView:NO];
    [self setHorizontallyResizable:YES];

    
    endRange.location = [[self textStorage] length];
    endRange.length = 0;
    self.terminalInsertionPoint = endRange;
    
    [self insertText:@" "];
    
    NSFont *defaultFont = [NSFont fontWithName: @"Monaco" size: 18];
    [self setFont:defaultFont];
    [self.textStorage setFont:defaultFont];
    
    
    NSMutableParagraphStyle* paragraphStyle = [[self defaultParagraphStyle] mutableCopy];
    
    if (paragraphStyle == nil) {
        paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    }
    
    float charWidth = [[defaultFont screenFontWithRenderingMode:NSFontDefaultRenderingMode] advancementForGlyph:(NSGlyph) ' '].width;
    [paragraphStyle setDefaultTabInterval:(charWidth * 4)];
    [paragraphStyle setTabStops:[NSArray array]];
    
    [self setDefaultParagraphStyle:paragraphStyle];
    
    NSSize inset;
    inset.height = 5;
    inset.width = 0;
    
    //[self setTextContainerInset:inset];
    NSLog(@"Default Font Height:%f",[[self layoutManager] defaultLineHeightForFont:defaultFont]);
    [[self textStorage] addAttribute:NSFontAttributeName value:defaultFont range:NSMakeRange(0, [[self textStorage] length])];
    //[[self textContainer] setLineFragmentPadding:10.0];
    
    [[self enclosingScrollView] setLineScroll:50.0];
    [[self enclosingScrollView] setPageScroll:100.0];
    
    //[[self superview] addSubview:overlayView];
    //NSLog(@"Superview:%@",[self superview]);
    //[self performSelector:@selector(shutterOverlay) withObject:nil afterDelay:0.2];
    
    NSDateFormatter *formatter;
    NSString        *dateString;
    
    formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd HH'hr'mm'min'ss'sec'"];
    
    dateString = [formatter stringFromDate:[NSDate date]];
    
    NSString *path = @"~/Desktop/Weetbix Data/";
    path = [path stringByAppendingString:dateString];
    path = [path stringByAppendingFormat:@".txt"];
    NSString *standardizedPath = [path stringByStandardizingPath];
    NSString *content = [dateString stringByAppendingFormat:@"\n"];
    //save content to the documents directory
    [content writeToFile:standardizedPath
              atomically:NO
                encoding:NSStringEncodingConversionAllowLossy
                   error:nil];
    outputFile = [NSFileHandle fileHandleForWritingAtPath:standardizedPath];
    [outputFile seekToEndOfFile];
    
    [self setPauseDisplay:NO];
    //[outputFile writeData:[message dataUsingEncoding:NSUTF8StringEncoding]];
    
}

/*
-(void)shutterOverlay
{
    NSLog(@"shutter Overlay");
    [overlayView setHidden:NO];
}
 */

/* Caret Drawing
 The current caret is a big improvement on the default caret. It now stays in the right place. Things that coule be improved though are, Should blink, Should animate in and out, Shouldn't be displayed if you are writing text.
 */

- (void) drawRect: (NSRect)rect
{
    NSRect insertionGlyphRect;
    NSRect caretRect;
    NSColor *caretColor;
    
    //NSLog(@"Drawing SerialTextView:%@", self);
    
    [super drawRect:rect];
    insertionGlyphRect = [[self layoutManager] boundingRectForGlyphRange:terminalInsertionPoint 
                                    inTextContainer:[self textContainer]];
    caretRect = NSInsetRect(insertionGlyphRect, 1, 1);
    caretRect.size.width = 4.0;
    
    if ([serialPort isOpen]) {
        caretColor = [NSColor colorWithCalibratedHue:0.84 saturation:0.5 brightness:1.0 alpha:1.0 ];
    } else {
        caretColor = [NSColor colorWithCalibratedHue:0.0 saturation:0.0 brightness:0.0 alpha:0.3 ];
    }
    
    [caretColor set];
    NSRectFillUsingOperation(caretRect, NSCompositePlusDarker);
}


- (void)keyDown:(NSEvent *)theEvent
{
    const unichar BS = 8;
    const unichar DEL = 127;
    
    //[serialPort setWritingCancelled:NO];
    
    // Intercept the keyDown event so that we can send the character to the serial port instead.
    NSString *input = [theEvent characters];
    NSLog(@"%@ %d",input,(int)[input characterAtIndex:0]);
    switch ((int)[input characterAtIndex:0]) {
        case DEL:
            input = [NSString stringWithCharacters:&BS length:1];
            break;
            
        default:
            break;
    }
	[serialPort sendString:input];
    
}

- (void)sendBulkText:(NSString *)stringToSend
{
    NSScanner *scanner = [NSScanner scannerWithString:stringToSend];
    [scanner setCharactersToBeSkipped:nil];
    NSString *line = nil;
    NSString *lineEndings = nil;
    NSMutableString *toSend = [[NSMutableString alloc] initWithCapacity:100];
    
    while (![scanner isAtEnd]) {
        
        line = nil;
        [scanner scanUpToCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:&line];
        if (line) {
            [toSend appendString:line];
        }
        
        lineEndings = nil;
        [scanner scanCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:&lineEndings];
        if (lineEndings) {
            [toSend appendString:@"\r\n"];
        }
    }
    if (toSend) {
        [serialPort sendString:toSend];
        [toSend setString:@""];
    }
}

- (void)paste:(id)sender
{
	NSPasteboard *pasteBoard = [NSPasteboard generalPasteboard];
	
    //[serialPort setWritingCancelled:NO];
    
	if ([[pasteBoard types] containsObject:@"NSStringPboardType"])
	{
		NSString *pasted = [pasteBoard stringForType:@"NSStringPboardType"];
        [self sendBulkText:pasted];
	}
}

- (void)sendFile:(NSURL *)fileLocation
{
    
}


- (void)scrollToBottom
{
    NSPoint     pt;
    id          scrollView;
    id          clipView;
    
    pt.x = 0;
    pt.y = 100000000000.0;
    
    scrollView = [self enclosingScrollView];
    clipView = [scrollView contentView];
    
    pt = [clipView constrainScrollPoint:pt];
    [clipView scrollToPoint:pt];
    [scrollView reflectScrolledClipView:clipView];
}


- (void)serialPortReadData:(NSDictionary *)dataDictionary
{
    NSData *sentData;
    NSString* sentString;
    
    
    sentData = [dataDictionary objectForKey:@"data"];
	sentString = [[NSString alloc] initWithData:sentData encoding:NSASCIIStringEncoding];
    
    // Need to find backspace, new line, carraige return
    // Would also like to identify echoed characters
    // Probably the best place for syntax highlighting
    
    // Create a character set including backspace, newline and Carriage Return characters
    // Use rangeOfCharacterFromSet:options to identify the range of the first such character
    // Break the string up into characters to be sent, The control character and characters
    // yet to be searched.
    // Send the first batch of characters, figure out what the control character wants done,
    // Then send the remaining characters back into the function to look for more control
    // characters
    
    NSString *remainder = [NSString stringWithString:sentString];
    
    //NSClipView* cv = self.enclosingScrollView.contentView;
    //NSLog(@"Copies on Scroll:%d", [cv copiesOnScroll]);
    
    //if (!pauseDisplay) {
    if (true) {
        //NSTimeInterval _myStartTime = [NSDate timeIntervalSinceReferenceDate];
        //NSTimeInterval _currentTime;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            //NSLog(@"beginEditing");
            [self.textStorage beginEditing];});
        
        do {
            remainder = [self processStringPortion:remainder];
        } while ([remainder length] > 0);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            //NSLog(@"endEditing");
            [self.textStorage endEditing];});
        //dispatch_async(dispatch_get_main_queue(), ^{[self scheduleScrollRangeToVisible:terminalInsertionPoint];});
        
        dispatch_async(dispatch_get_main_queue(), ^{
            //NSLog(@"scrollRangeToVisible");
            [self scrollRangeToVisible:terminalInsertionPoint];});
        //dispatch_async(dispatch_get_main_queue(), ^{[self scrollToBottom];});
        
        
        //_currentTime = [NSDate timeIntervalSinceReferenceDate];
        //printf("The time it took: %f\n", _currentTime - _myStartTime);
    }
        
    NSString *setString = [[NSString alloc] initWithData:sentData encoding:NSASCIIStringEncoding];
    char bytes[] = { 0x11 };
    NSString *xonXoffString = [[NSString alloc] initWithBytes:bytes length:1 encoding:NSASCIIStringEncoding];
    NSString *trimmedReplacement = [setString stringByReplacingOccurrencesOfString:xonXoffString withString:@""];
    [outputFile writeData:[trimmedReplacement dataUsingEncoding:NSUTF8StringEncoding]];
}


-(NSString *)processStringPortion:(NSString *)inputString
{
    //NSRange endRange;
    NSRange controlCharacterRange;
    NSRange toBeSentRange;
    NSString *toBeSent;
    NSRange remainderRange;
    NSString *remainder;
    //NSArray *originalSelectionArray;
    //NSDate *xonTime;
    //float xoffDelay;
    
    
    // Look through the text and find any control characters
    //NSLog(@"Control Character Set:%@", self.controlCharactersSet);
    controlCharacterRange = [inputString rangeOfCharacterFromSet:self.controlCharactersSet];
    //controlCharacterRange = NSMakeRange(0, 0);
    
    if ((controlCharacterRange.length > 0) && (controlCharacterRange.location < 1)) {
        // Deal with the first control character
        NSString *controlCharacter = [inputString substringWithRange:controlCharacterRange];
        //NSLog(@"length:%ld", (unsigned long)controlCharacterRange.length);
        
        if ([controlCharacter isEqualToString:@"\r"] && ([inputString length] > 1)) {
            NSString *peekAhead = [inputString substringWithRange:NSMakeRange(1, 1)];
            if ([peekAhead isEqualToString:@"\n"]) {
                controlCharacter = peekAhead;
                inputString = [inputString substringFromIndex:1];
                //NSLog(@"peek Ahead Worked");
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            //NSLog(@"parseCharacters");
            
            NSArray *originalSelectionArray;
            // Save the user selection prior to any changes being made.
            originalSelectionArray = [self selectedRanges];
            // Move the insertion point to the remembered terminal insertion point.
            [self setSelectedRange:terminalInsertionPoint];

            
            NSString *charToBeSent;
            NSRange startOfLine;
            
            switch ([controlCharacter characterAtIndex:0]) {
                case 0x0008:
                    //NSLog(@"BackSpace");
                    // Need protection to stop moving back up a line
                    terminalInsertionPoint.location = terminalInsertionPoint.location - 1;
                    break;
                case 0x0009:
                    //NSLog(@"Tab");
                    self.terminalInsertionPoint = [self selectedRange];
                    charToBeSent = [NSString stringWithFormat:@"\t"];
                    //toBeSent = [NSString stringWithFormat:@"  "];
                    terminalInsertionPoint.length = MIN([toBeSent length],
                                                    ([[self textStorage] length] - terminalInsertionPoint.location));
                    [self replaceCharactersInRange:self.terminalInsertionPoint withString:charToBeSent];
                    terminalInsertionPoint.location = terminalInsertionPoint.location + [charToBeSent length];
                    terminalInsertionPoint.length = 0;
                    //[self scheduleScrollRangeToVisible:terminalInsertionPoint];
                    break;
                case 0x000A:
                    //NSLog(@"New Line");
                    //[self moveToEndOfLine:self]; //***
                    //[self.textStorage rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\n"]];
                    terminalInsertionPoint.location = [[self textStorage] length];
                    terminalInsertionPoint.length = 0;
                    //self.terminalInsertionPoint = [self selectedRange];
                    charToBeSent = [NSString stringWithFormat:@"\n"];
                    [self.textStorage replaceCharactersInRange:terminalInsertionPoint withString:charToBeSent]; // Can this be coalesed?
                    terminalInsertionPoint.location = terminalInsertionPoint.location + [charToBeSent length];
                    terminalInsertionPoint.length = 0;
                    //[self scheduleScrollRangeToVisible:terminalInsertionPoint];
                    break;
                case 0x000D:
                    //NSLog(@"Carriage Return");
                    //[self moveToLeftEndOfLine:self]; //***
                    
                    startOfLine = [self.textStorage.string rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\n"]
                                                             options:NSBackwardsSearch];
                    startOfLine.location = startOfLine.location + 1;
                    terminalInsertionPoint.location = MAX(startOfLine.location, 0);
                    terminalInsertionPoint.location = MIN(startOfLine.location, [self.textStorage length]);
                    terminalInsertionPoint.length = 0;
                    //NSString *blahblah = [[self textStorage] string];
                    //NSRange *blah = [self.textStorage.string rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\n"]];
                                    
                                    //rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\n"]
                                                                            //options:NSBackwardsSearch];
                    //self.terminalInsertionPoint = [self selectedRange];
                    //[[NSRunLoop currentRunLoop] runUntilDate:[NSDate distantPast]];
                    //[self scrollRangeToVisible: NSMakeRange(self.string.length, 0)];
                    //[self scrollRangeToVisible:terminalInsertionPoint];
                    break;
                case 0x0013:
                    //NSLog(@"XOFF");
                    //[serialPort delay];
                    xoffTime = [NSDate date];
                    break;
                case 0x0011:
                    //NSLog(@"XON");
                    //xonTime = [NSDate date];
                    //if ([xoffTime isNotEqualTo:nil]) {
                    //    xoffDelay = [xonTime timeIntervalSinceDate:xoffTime];
                    //    //NSLog(@"XON delay:%fsec", xoffDelay);
                    //    xoffTime = nil;
                    //}
                    break;
                default:
                    NSLog(@"Unhandled Control Character:%d", [controlCharacter characterAtIndex:0]);
                    break;
        
            }
            //[self scheduleScrollRangeToVisible:terminalInsertionPoint];
            [self setSelectedRanges:originalSelectionArray];
        });
        remainderRange.location = controlCharacterRange.location + 1;
        remainderRange.length = [inputString length] - 1;
        remainder = [inputString substringWithRange:remainderRange];
    } else {
        if (controlCharacterRange.length > 0) {
            // There is a chunk of text before the control character
            toBeSentRange.location = 0;
            toBeSentRange.length = MIN(controlCharacterRange.location,[inputString length]);
            toBeSent = [inputString substringWithRange:toBeSentRange];
            
            remainderRange.location = toBeSentRange.length;
            remainderRange.length = [inputString length] - remainderRange.location;
            remainder = [inputString substringWithRange:remainderRange];
        } else {
            // There was no control character
            toBeSent = inputString;
            
            remainder = [NSString stringWithFormat:@""];
        }
        
        
        
        dispatch_async(dispatch_get_main_queue(), ^{
            //NSLog(@"replaceCharactersInRange");
            
            NSArray *originalSelectionArray;
            NSRange endRange;
            
            
            // Save the user selection prior to any changes being made.
            originalSelectionArray = [self selectedRanges];
            // Move the insertion point to the remembered terminal insertion point.
            [self setSelectedRange:terminalInsertionPoint];

            
            endRange.location = [[self textStorage] length];
            endRange.length = 0;
            
            // The insertion length must be either the length of the text being entered or the distance to the end of the text storage.
            terminalInsertionPoint.length = MIN([toBeSent length],
                                            (endRange.location - terminalInsertionPoint.location));
            
            //NSLog(@"ToBeSent Lenght:%ld Insertion Length:%ld", (unsigned long)[toBeSent length], (unsigned long)terminalInsertionPoint.length);
            //[self replaceCharactersInRange:terminalInsertionPoint withString:toBeSent];
            //[self.textStorage beginEditing];
            [self.textStorage replaceCharactersInRange:terminalInsertionPoint withString:toBeSent];
            //[self.textStorage endEditing];
            
            //NSPoint newScrollOrigin;
            //NSScrollView *scrollView = (NSScrollView *)self.superview.superview;
            //newScrollOrigin=NSMakePoint(0.0,NSMaxY([[scrollView documentView] frame])
            //                            -NSHeight([[scrollView contentView] bounds]));
            //[[scrollView documentView] scrollPoint:newScrollOrigin];
            //NSAttributedString *attributedToBeSent = [[NSAttributedString alloc] initWithString:toBeSent attributes:[self typingAttributes]];
            //[self.textStorage replaceCharactersInRange:terminalInsertionPoint withAttributedString:attributedToBeSent];
            //[self scrollRangeToVisible: NSMakeRange(self.string.length, 0)];
            //if (![[NSApplication sharedApplication] isActive]) {
            //    [self scrollRangeToVisible:terminalInsertionPoint];
            //}
        
            // Set the global insertion point to the correct position.
            terminalInsertionPoint.location = terminalInsertionPoint.location + [toBeSent length];
            terminalInsertionPoint.length = 0;
            //[self scheduleScrollRangeToVisible:terminalInsertionPoint];
            [self setSelectedRanges:originalSelectionArray];
        });
    }
    
    //self.terminalInsertionPoint = [[currentSelectionArray objectAtIndex:0] rangeValue];
    //[self setSelectedRanges:originalSelectionArray];
    
    return remainder;
}

-(void)scheduleScrollRangeToVisible:(NSRange)insertionPoint
{
    if (!scrollCoalesenceTimer) {
        //NSLog(@"SCROLL");
        [self scrollRangeToVisible:insertionPoint];
        //NSString *range = NSStringFromRange(insertionPoint);
        scrollCoalesenceTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                                 target:self
                                                               selector:@selector(invalidateScrollTimer:)
                                                               userInfo:nil
                                                                repeats:NO];
    } else {
        //NSLog(@"Don't SCROLL");
        NSDate *dateToFire = [scrollCoalesenceTimer fireDate];
        [scrollCoalesenceTimer invalidate];
        NSString *range = NSStringFromRange(insertionPoint);
        scrollCoalesenceTimer = [[NSTimer alloc] initWithFireDate:dateToFire
                                                         interval:0.0
                                                           target:self
                                                         selector:@selector(actualScrollRangeToVisible:)
                                                         userInfo:[NSDictionary dictionaryWithObject:range forKey:@"range"]
                                                          repeats:NO];
        [[NSRunLoop currentRunLoop] addTimer:scrollCoalesenceTimer forMode:NSDefaultRunLoopMode];
        
        [self setPauseDisplay:YES];
    }
    // NSStringFromRange() and NSRangeFromString()
    
}

-(void)actualScrollRangeToVisible:(NSTimer *)timer
{
    NSLog(@"SCROLL again");
    NSDictionary *userInfo = [timer userInfo];
    
    [self setPauseDisplay:NO];
    NSString *rangeString = [userInfo objectForKey:@"range"];
    NSRange range = NSRangeFromString(rangeString);
    [self scrollRangeToVisible:range];
    scrollCoalesenceTimer = nil;
}

-(void)invalidateScrollTimer:(NSTimer *)timer
{
    scrollCoalesenceTimer = nil;
}


- (void)serialPortReadDataPREV:(NSDictionary *)dataDictionary
{
    NSData *sentData;
    NSString* sentString;

        
    sentData = [dataDictionary objectForKey:@"data"];
	sentString = [[NSString alloc] initWithData:sentData encoding:NSASCIIStringEncoding];
    
    // Need to find backspace, new line, carraige return
    // Would also like to identify echoed characters
    // Probably the best place for syntax highlighting
    
    // Create a character set including backspace, newline and Carriage Return characters
    // Use rangeOfCharacterFromSet:options to identify the range of the first such character
    // Break the string up into characters to be sent, The control character and characters
    // yet to be searched. 
    // Send the first batch of characters, figure out what the control character wants done,
    // Then send the remaining characters back into the function to look for more control 
    // characters
    
    NSString *remainder = [NSString stringWithString:sentString];
    
    do {
        remainder = [self processStringPortionPREV:remainder];
    } while ([remainder length] > 0);
    
}


-(NSString *)processStringPortionPREV:(NSString *)inputString
{
    NSRange endRange;
    NSRange controlCharacterRange;
    NSRange toBeSentRange;
    NSString *toBeSent;
    NSRange remainderRange;
    NSString *remainder;
    NSArray *originalSelectionArray;
    NSDate *xonTime;
    float xoffDelay;
    
    // Save the user selection prior to any changes being made.
    originalSelectionArray = [self selectedRanges];
    // Move the insertion point to the remembered terminal insertion point.
    [self setSelectedRange:terminalInsertionPoint];
    
    // Look through the text and find any control characters
    //NSLog(@"Control Character Set:%@", self.controlCharactersSet);
    controlCharacterRange = [inputString rangeOfCharacterFromSet:self.controlCharactersSet];
    //controlCharacterRange = NSMakeRange(0, 0);
    
    if ((controlCharacterRange.length > 0) && (controlCharacterRange.location < 1)) {
        // Deal with the first control character
        NSString *controlCharacter = [inputString substringWithRange:controlCharacterRange];
        switch ([controlCharacter characterAtIndex:0]) {
            case 0x0008:
                //NSLog(@"BackSpace");
                // Need protection to stop moving back up a line
                terminalInsertionPoint.location = terminalInsertionPoint.location - 1;
                break;
            case 0x0009:
                //NSLog(@"Tab");
                self.terminalInsertionPoint = [self selectedRange];
                toBeSent = [NSString stringWithFormat:@"\t"];
                //toBeSent = [NSString stringWithFormat:@"  "];
                terminalInsertionPoint.length = MIN([toBeSent length],
                                                    ([[self textStorage] length] - terminalInsertionPoint.location));
                [self replaceCharactersInRange:self.terminalInsertionPoint withString:toBeSent];
                terminalInsertionPoint.location = terminalInsertionPoint.location + [toBeSent length];
                terminalInsertionPoint.length = 0;
                [self scrollRangeToVisible:terminalInsertionPoint];
                break;
            case 0x000A:
                //NSLog(@"New Line");
                [self moveToEndOfLine:self];
                self.terminalInsertionPoint = [self selectedRange];
                toBeSent = [NSString stringWithFormat:@"\n"];
                [self replaceCharactersInRange:self.terminalInsertionPoint withString:toBeSent];
                terminalInsertionPoint.location = terminalInsertionPoint.location + [toBeSent length];
                terminalInsertionPoint.length = 0;
                [self scrollRangeToVisible:terminalInsertionPoint];
                break;
            case 0x000D:
                //NSLog(@"Carriage Return");
                [self moveToLeftEndOfLine:self];
                self.terminalInsertionPoint = [self selectedRange];
                break;
            case 0x0013:
                //NSLog(@"XOFF");
                //[serialPort delay];
                xoffTime = [NSDate date];
                break;
            case 0x0011:
                //NSLog(@"XON");
                xonTime = [NSDate date];
                if ([xoffTime isNotEqualTo:nil]) {
                    xoffDelay = [xonTime timeIntervalSinceDate:xoffTime];
                    //NSLog(@"XON delay:%fsec", xoffDelay);
                    xoffTime = nil;
                }
                
                break;
            default:
                NSLog(@"Unhandled Control Character:%d", [controlCharacter characterAtIndex:0]);
                break;
        }
        
        remainderRange.location = controlCharacterRange.location + 1;
        remainderRange.length = [inputString length] - 1;
        remainder = [inputString substringWithRange:remainderRange];
    } else {
        if (controlCharacterRange.length > 0) {
            // There is a chunk of text before the control character
            toBeSentRange.location = 0;
            toBeSentRange.length = MIN(controlCharacterRange.location,[inputString length]);
            toBeSent = [inputString substringWithRange:toBeSentRange];
            
            remainderRange.location = toBeSentRange.length;
            remainderRange.length = [inputString length] - remainderRange.location;
            remainder = [inputString substringWithRange:remainderRange];
        } else {
            // There was no control character
            toBeSent = inputString;
            
            remainder = [NSString stringWithFormat:@""];
        }
        
        endRange.location = [[self textStorage] length];
        endRange.length = 0;
        
        // The insertion length must be either the length of the text being entered or the distance to the end of the text storage.
        terminalInsertionPoint.length = MIN([toBeSent length],
                                            (endRange.location - terminalInsertionPoint.location));
        
        [self replaceCharactersInRange:terminalInsertionPoint withString:toBeSent];
        
        // Set the global insertion point to the correct position.
        terminalInsertionPoint.location = terminalInsertionPoint.location + [toBeSent length];
        terminalInsertionPoint.length = 0;
        [self scrollRangeToVisible:terminalInsertionPoint];
    }
    
    //self.terminalInsertionPoint = [[currentSelectionArray objectAtIndex:0] rangeValue];
    [self setSelectedRanges:originalSelectionArray];
    
    return remainder;
}


- (void) willWriteData:(NSData *)data ofLength:(uint)len
{
    numBytesToSend = numBytesToSend + len;
    numBytesRemaining = numBytesRemaining + len;
}


- (void) didPartialWriteData:(NSData *)sentData ofLength:(uint)len
{
    numBytesRemaining = numBytesRemaining - len;
    float percentage = (float)numBytesRemaining / numBytesToSend;
    NSLog(@"Remaining:%.2f %%", percentage*100);
    NSDictionary *notificationDict = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithFloat:numBytesToSend], @"numBytesToSend", 
                                                                                [NSNumber numberWithFloat:numBytesRemaining], @"numBytesRemaining", nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:EIDidPartialWriteData
                                                        object:self
                                                      userInfo:notificationDict];
    if (numBytesRemaining <= 0) {
        numBytesToSend = 0;
    }
}


- (void) didWriteData:(NSData *)sentData ofLength:(uint)len
{
    
}


- (void) didCancelWriteDataWithoutSendingRemainingData:(NSData *)unsentData
{
    numBytesToSend = 0;
    numBytesRemaining = 0;
    float percentage = 0.00;
    NSLog(@"Remaining:%.2f %%", percentage*100);
    NSDictionary *notificationDict = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithFloat:numBytesToSend], @"numBytesToSend", 
                                      [NSNumber numberWithFloat:numBytesRemaining], @"numBytesRemaining", nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:EIDidPartialWriteData
                                                        object:self
                                                      userInfo:notificationDict];
}
/*
- (void)drawInsertionPointInRect:(NSRect)rect 
                           color:(NSColor *)color 
                        turnedOn:(BOOL)flag
{
    //Block Cursor
    if( flag )
    {
        NSPoint aPoint=NSMakePoint( rect.origin.x,rect.origin.y+rect.size.height/2);
        int glyphIndex = (int)[[self layoutManager] glyphIndexForPoint:aPoint 
                                                       inTextContainer:[self textContainer]];
        NSRect glyphRect = [[self layoutManager] 
                            boundingRectForGlyphRange:NSMakeRange(glyphIndex, 1)  
                            inTextContainer:[self textContainer]];
        
        [color set];
        rect.size.width = rect.size.height/8;
        if(glyphRect.size.width > 0 && glyphRect.size.width < rect.size.width) {
            rect.size.width=glyphRect.size.width;
        }
        NSRectFillUsingOperation(rect, NSCompositePlusDarker);
    } else {
        [self setNeedsDisplayInRect:[self visibleRect] avoidAdditionalLayout:NO];
    }
}
*/

- (BOOL)shouldDrawInsertionPoint
{
    return NO;
}

/*
 Interesting code snippets from NSTextView.m
 
 + (NSMenu *) defaultMenu
 {
 if (!textViewMenu)
 {
 textViewMenu = [[NSMenu alloc] initWithTitle: @""];
 [textViewMenu insertItemWithTitle: _(@"Cut") action:@selector(cut:) keyEquivalent:@"x" atIndex:0];
 [textViewMenu insertItemWithTitle: _(@"Copy") action:@selector(copy:) keyEquivalent:@"c" atIndex:1];
 [textViewMenu insertItemWithTitle: _(@"Paste") action:@selector(paste:) keyEquivalent:@"v" atIndex:2];
 }
 return textViewMenu;
 }
 */

@end
