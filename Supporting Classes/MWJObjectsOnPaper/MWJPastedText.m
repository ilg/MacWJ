/*********************************************************************************
 
 © Copyright 2010, Isaac Greenspan
 
 Permission is hereby granted, free of charge, to any person
 obtaining a copy of this software and associated documentation
 files (the "Software"), to deal in the Software without
 restriction, including without limitation the rights to use,
 copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the
 Software is furnished to do so, subject to the following
 conditions:
 
 The above copyright notice and this permission notice shall be
 included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 OTHER DEALINGS IN THE SOFTWARE.
 
 *********************************************************************************/

//
//  MWJPastedText.m
//  MacWJ
//

#import "MWJPastedText.h"


@implementation MWJPastedText

- (id)initWithData:(NSData *)theData
		centeredOn:(NSPoint)centerPoint
{
	self = [super init];
	if (self) {
		NSMutableAttributedString *attributedString = nil;
		attributedString = [[NSMutableAttributedString alloc] initWithData:theData
																   options:nil
														documentAttributes:NULL
																	 error:NULL];
		[attributedString autorelease];
		
		if (attributedString) {
			// trim whitespace from the tail end of the string
			NSMutableString *mutableStringContents = [attributedString mutableString];
			NSUInteger firstCharToDelete = [mutableStringContents
											rangeOfCharacterFromSet:[[NSCharacterSet
																	  whitespaceAndNewlineCharacterSet]
																	 invertedSet]
											options:NSBackwardsSearch
											].location + 1;
			[mutableStringContents
			 deleteCharactersInRange:NSMakeRange(firstCharToDelete,
												 [mutableStringContents length] - firstCharToDelete)];
			
			// set up the text field
			theTextField = [[NSTextField alloc] init];
			[theTextField setAttributedStringValue:attributedString];
			[theTextField setBezeled:NO];
			[theTextField setBordered:NO];
			[theTextField setDrawsBackground:NO];
			[[theTextField cell] setWraps:YES];
			[theTextField sizeToFit];
			NSRect textFieldFrame = [theTextField frame];
			CGFloat maxWidth = centerPoint.x;
			if (textFieldFrame.size.width > maxWidth) {
				// probably too wide
				textFieldFrame.size.height = (textFieldFrame.size.height
											  * ceilf(textFieldFrame.size.width / maxWidth)
											  );
				textFieldFrame.size.width = maxWidth;
				textFieldFrame.size = [attributedString
									   boundingRectWithSize:textFieldFrame.size
									   options:NSStringDrawingUsesLineFragmentOrigin
									   ].size;
				[theTextField setFrame:textFieldFrame];
				[theTextField setAttributedStringValue:attributedString];
			}
			
			NSRect ourFrame;
			ourFrame.size = [theTextField bounds].size;
			ourFrame.origin.x = centerPoint.x - ourFrame.size.width / 2.0;
			ourFrame.origin.y = centerPoint.y - ourFrame.size.height / 2.0;
			[self setFrame:ourFrame];
		} else {
			[super dealloc];
			self = nil;
		}
	}
	return self;
}

#pragma mark -
#pragma mark MWJObjectOnPaper protocol implementation
// the rest of the protocol is implemented in MWJObjectOnPaperParentClass

- (void)drawInRect:(NSRect)dirtyRect
		 withRects:(const NSRect *)dirtyRects
			 count:(NSInteger)dirtyRectsCount
{
	NSRect textFieldFrame = [theTextField frame];
	textFieldFrame.size = [self frame].size;
	[theTextField setFrame:textFieldFrame];
	NSImage *imageOfTextField = [[NSImage alloc]
								 initWithData:[theTextField
											   dataWithPDFInsideRect:[theTextField frame]]];
	[imageOfTextField setFlipped:YES];
	[imageOfTextField drawInRect:[self frame]
						fromRect:NSZeroRect
					   operation:NSCompositeSourceOver
						fraction:1.0];
	[imageOfTextField release];
}

#pragma mark -
#pragma mark for archiving/unarchiving (for saving/loading documents)

// MARK: string keys for NSCoding
NSString * const kMWJPastedTextFieldKey = @"MWJPastedTextFieldKey";
NSString * const kMWJPastedTextFrameKey = @"MWJPastedTextFrameKey";

- (void)encodeWithCoder:(NSCoder *)coder {
	// NSObject does not conform to NSCoding
	//    [super encodeWithCoder:coder];
    [coder encodeObject:theTextField forKey:kMWJPastedTextFieldKey];
	[coder encodeRect:[self frame] forKey:kMWJPastedTextFrameKey];
}

- (id)initWithCoder:(NSCoder *)coder {
	// NSObject does not conform to NSCoding
	//    self = [super initWithCoder:coder];
	self = [super init];
	if (self) {
		theTextField = [[coder decodeObjectForKey:kMWJPastedTextFieldKey] retain];
		[self setFrame:[coder decodeRectForKey:kMWJPastedTextFrameKey]];
	}
    return self;
}


@end
