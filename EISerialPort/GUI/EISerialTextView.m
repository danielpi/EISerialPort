//
//  EISerialTextView.m
//  Weetbix
//
//  Created by Daniel Pink on 10/01/12.
//  Copyright (c) 2012 Electronic Innovations. All rights reserved.
//

#import "EISerialTextView.h"


@interface EISerialTextView ()

@property NSRange terminalInsertionPoint;


@end


@implementation EISerialTextView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
        
        // This doesn't get called if the object is in the NIB
    }
    
    return self;
}

-(void)awakeFromNib
{
    NSRange endRange;
    
    NSLog(@"Awake From Nib Serial Text View");
    
    [self setAllowsUndo:NO];
    [self setRichText:NO];
    
    // The following code implements some form of line wrap blocking. Needs to be a setable option
    //[[self textContainer] setContainerSize:NSMakeSize(FLT_MAX, FLT_MAX)];
    //[[self textContainer] setWidthTracksTextView:NO];
    //[self setHorizontallyResizable:YES];
    
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
    
    [[self textStorage] addAttribute:NSFontAttributeName value:defaultFont range:NSMakeRange(0, [[self textStorage] length])];
    
    [[self enclosingScrollView] setLineScroll:50.0];
    [[self enclosingScrollView] setPageScroll:100.0];
    
    [self setContinuousSpellCheckingEnabled:NO];
    
    _caretColor = [NSColor colorWithCalibratedHue:0.84 saturation:0.5 brightness:1.0 alpha:1.0 ];
    // caretColor = [NSColor colorWithCalibratedHue:0.0 saturation:0.0 brightness:0.0 alpha:0.3 ]; // Dulled out
    
    //[[self superview] addSubview:overlayView];
    //[self performSelector:@selector(shutterOverlay) withObject:nil afterDelay:0.2];
}

/*
-(void)shutterOverlay
{
    NSLog(@"shutter Overlay");
    [overlayView setHidden:NO];
}
 */

/* Caret Drawing
 The current caret is a big improvement on the default caret. It now stays in the right place. Things that could be improved though are, Should blink, Should animate in and out, Shouldn't be displayed if you are writing text.
 */
- (BOOL)shouldDrawInsertionPoint
{
    return NO;
}

- (void) drawRect: (NSRect)rect
{
    NSRect insertionGlyphRect;
    NSRect caretRect;
    
    [super drawRect:rect];
    insertionGlyphRect = [[self layoutManager] boundingRectForGlyphRange:self.terminalInsertionPoint
                                                         inTextContainer:[self textContainer]];
    caretRect = NSInsetRect(insertionGlyphRect, 1, 1);
    caretRect.size.width = 4.0;

    [self.caretColor set];
    NSRectFillUsingOperation(caretRect, NSCompositePlusDarker);
}


// Intercept the keyDown event so that we can send the character to the serial port instead.
- (void)keyDown:(NSEvent *)theEvent
{
    const unichar BS = 8;
    const unichar DEL = 127;
    
    NSString *input = [theEvent characters];
    switch ((int)[input characterAtIndex:0]) {
        case DEL:
            input = [NSString stringWithCharacters:&BS length:1];
            break;
        default:
            break;
    }
    
	if ([self.delegate respondsToSelector:@selector(receivedStringFromUser:)])
    {
        [self.delegate receivedStringFromUser:input];
    }
}


- (void)paste:(id)sender
{
	NSPasteboard *pasteBoard = [NSPasteboard generalPasteboard];
	
    //[serialPort setWritingCancelled:NO];
    
	if ([[pasteBoard types] containsObject:@"NSStringPboardType"])
	{
		NSString *pasted = [pasteBoard stringForType:@"NSStringPboardType"];
        
        if ([self.delegate respondsToSelector:@selector(receivedStringFromUser:)])
        {
            [self.delegate receivedStringFromUser:pasted];
        }
	}
}


- (void)appendCharacters:(NSData *)characters;
{
    NSString* sentString = [[NSString alloc] initWithData:characters encoding:NSASCIIStringEncoding];
    
    [self appendString:sentString];
}


- (void)appendString:(NSString *)aString
{
    NSString *remainder = [NSString stringWithString:aString];
    
    dispatch_async(dispatch_get_main_queue(), ^{ [self.textStorage beginEditing]; });
    
    do {
        remainder = [self processStringPortion:remainder];
    } while ([remainder length] > 0);
    
    dispatch_async(dispatch_get_main_queue(), ^{ [self.textStorage endEditing]; });
    dispatch_async(dispatch_get_main_queue(), ^{ [self scrollRangeToVisible:self.terminalInsertionPoint]; });
}


-(NSString *)processStringPortion:(NSString *)inputString
{
    NSRange controlCharacterRange;
    NSRange toBeSentRange;
    NSString *toBeSent;
    NSRange remainderRange;
    NSString *remainder;
    
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
    
    // Look through the text and find any control characters
    controlCharacterRange = [inputString rangeOfCharacterFromSet:[NSCharacterSet controlCharacterSet]];
    
    if ((controlCharacterRange.length > 0) && (controlCharacterRange.location < 1)) {
        // Deal with the first control character
        NSString *controlCharacter = [inputString substringWithRange:controlCharacterRange];
        
        if ([controlCharacter isEqualToString:@"\r"] && ([inputString length] > 1)) {
            NSString *peekAhead = [inputString substringWithRange:NSMakeRange(1, 1)];
            if ([peekAhead isEqualToString:@"\n"]) {
                controlCharacter = peekAhead;
                inputString = [inputString substringFromIndex:1];
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            //NSLog(@"parseCharacters");
            
            NSArray *originalSelectionArray;
            // Save the user selection prior to any changes being made.
            originalSelectionArray = [self selectedRanges];
            // Move the insertion point to the remembered terminal insertion point.
            [self setSelectedRange:self.terminalInsertionPoint];

            
            NSString *charToBeSent;
            NSRange startOfLine;
            
            switch ([controlCharacter characterAtIndex:0]) {
                case 0x0008: // Backspace
                    // Need protection to stop moving back up a line
                    _terminalInsertionPoint.location = self.terminalInsertionPoint.location - 1;
                    break;
                case 0x0009: // TAB
                    self.terminalInsertionPoint = [self selectedRange];
                    charToBeSent = [NSString stringWithFormat:@"\t"];
                    _terminalInsertionPoint.length = MIN([toBeSent length],
                                                    ([[self textStorage] length] - self.terminalInsertionPoint.location));
                    [self replaceCharactersInRange:self.terminalInsertionPoint withString:charToBeSent];
                    _terminalInsertionPoint.location = self.terminalInsertionPoint.location + [charToBeSent length];
                    _terminalInsertionPoint.length = 0;
                    break;
                case 0x000A: // New Line
                     _terminalInsertionPoint.location = [[self textStorage] length];
                    _terminalInsertionPoint.length = 0;
                    charToBeSent = [NSString stringWithFormat:@"\n"];
                    [self.textStorage replaceCharactersInRange:self.terminalInsertionPoint withString:charToBeSent]; // Can this be coalesed?
                    _terminalInsertionPoint.location = self.terminalInsertionPoint.location + [charToBeSent length];
                    _terminalInsertionPoint.length = 0;
                    break;
                case 0x000D: // Carriage Return
                    startOfLine = [self.textStorage.string rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\n"]
                                                             options:NSBackwardsSearch];
                    startOfLine.location = startOfLine.location + 1;
                    _terminalInsertionPoint.location = MAX(startOfLine.location, 0);
                    _terminalInsertionPoint.location = MIN(startOfLine.location, [self.textStorage length]);
                    _terminalInsertionPoint.length = 0;
                     break;
                default:
                    NSLog(@"Unhandled Control Character:%d", [controlCharacter characterAtIndex:0]);
                    break;
        
            }
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
            NSArray *originalSelectionArray;
            NSRange endRange;
            
            // Save the user selection prior to any changes being made.
            originalSelectionArray = [self selectedRanges];
            // Move the insertion point to the remembered terminal insertion point.
            [self setSelectedRange:self.terminalInsertionPoint];

            
            endRange.location = [[self textStorage] length];
            endRange.length = 0;
            
            // The insertion length must be either the length of the text being entered or the distance to the end of the text storage.
            _terminalInsertionPoint.length = MIN([toBeSent length],
                                            (endRange.location - self.terminalInsertionPoint.location));
            
            [self.textStorage replaceCharactersInRange:self.terminalInsertionPoint withString:toBeSent];
            
            // Set the global insertion point to the correct position.
            _terminalInsertionPoint.location = self.terminalInsertionPoint.location + [toBeSent length];
            _terminalInsertionPoint.length = 0;
            [self setSelectedRanges:originalSelectionArray];
        });
    }
    
    return remainder;
}


@end
