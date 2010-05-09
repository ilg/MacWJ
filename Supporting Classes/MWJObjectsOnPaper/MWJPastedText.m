//
//  MWJPastedText.m
//  MacWJ
//
//  Created by Isaac Greenspan on 5/9/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "MWJPastedText.h"
#import "NSBezierPath+highlightedStroke.h"
#import "NSBezierPath+overlapsRect.h"


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
			
			textFrame.size = [theTextField bounds].size;
			textFrame.origin.x = centerPoint.x - textFrame.size.width / 2.0;
			textFrame.origin.y = centerPoint.y - textFrame.size.height / 2.0;
		} else {
			[super dealloc];
			self = nil;
		}
	}
	return self;
}

#pragma mark -
#pragma mark MWJObjectOnPaper protocol implementation

- (NSRect)bounds {
	return textFrame;
}

- (NSRect)highlightBounds {
	return [[NSBezierPath bezierPathWithRect:textFrame] highlightedStrokeBounds];
}

- (void)drawInRect:(NSRect)dirtyRect
		 withRects:(const NSRect *)dirtyRects
			 count:(NSInteger)dirtyRectsCount
{
	NSRect textFieldFrame = [theTextField frame];
	textFieldFrame.size = textFrame.size;
	[theTextField setFrame:textFieldFrame];
	NSImage *imageOfTextField = [[NSImage alloc]
								 initWithData:[theTextField
											   dataWithPDFInsideRect:[theTextField frame]]];
	[imageOfTextField setFlipped:YES];
	[imageOfTextField drawInRect:textFrame
						fromRect:NSZeroRect
					   operation:NSCompositeSourceOver
						fraction:1.0];
	[imageOfTextField release];
}

- (void)drawWithHighlightInRect:(NSRect)dirtyRect
					  withRects:(const NSRect *)dirtyRects
						  count:(NSInteger)dirtyRectsCount
{
	[[NSBezierPath bezierPathWithRect:textFrame] highlightedStroke];
	[self drawInRect:dirtyRect
		   withRects:dirtyRects
			   count:dirtyRectsCount];
}

- (BOOL)passesThroughRect:(NSRect)rect {
	// NOTE: CGRectIntersectsRect behaves better than NSIntersectsRect when width or height is zero
	return CGRectIntersectsRect(NSRectToCGRect(rect), NSRectToCGRect(textFrame));
}

- (BOOL)passesThroughRectValue:(NSValue *)rectValue {
	return [self passesThroughRect:[rectValue rectValue]];
}

- (BOOL)passesThroughRegionEnclosedByPath:(NSBezierPath *)path {
	return [path overlapsRect:textFrame];
}

- (void)transformUsingAffineTransform:(NSAffineTransform *)aTransform {
	textFrame.origin = [aTransform transformPoint:textFrame.origin];
	textFrame.size = [aTransform transformSize:textFrame.size];
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
	[coder encodeRect:textFrame forKey:kMWJPastedTextFrameKey];
}

- (id)initWithCoder:(NSCoder *)coder {
	// NSObject does not conform to NSCoding
	//    self = [super initWithCoder:coder];
	self = [super init];
	if (self) {
		theTextField = [[coder decodeObjectForKey:kMWJPastedTextFieldKey] retain];
		textFrame = [coder decodeRectForKey:kMWJPastedTextFrameKey];
	}
    return self;
}


@end
