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
//  MWJPastedImage.m
//  MacWJ
//

#import "MWJPastedImage.h"
#import "NSBezierPath+highlightedStroke.h"
#import "NSBezierPath+overlapsRect.h"


@implementation MWJPastedImage


- (id)initWithData:(NSData *)theData
		   inFrame:(NSRect)theFrame
{
	self = [super init];
	if (self) {
		theImage = [[NSImage alloc] initWithData:theData];
		[theImage setFlipped:YES];
		imageFrame.origin = theFrame.origin;
		if (NSEqualSizes(theFrame.size, NSZeroSize)) {
			imageFrame.size = [theImage size];
		} else {
			imageFrame.size = theFrame.size;
		}
	}
	return self;
}

- (id)initWithData:(NSData *)theData
		centeredOn:(NSPoint)centerPoint
{
	self = [super init];
	if (self) {
		theImage = [[NSImage alloc] initWithData:theData];
		[theImage setFlipped:YES];
		imageFrame.size = [theImage size];
		imageFrame.origin.x = centerPoint.x - imageFrame.size.width / 2.0;
		imageFrame.origin.y = centerPoint.y - imageFrame.size.height / 2.0;
	}
	return self;
}


#pragma mark -
#pragma mark MWJObjectOnPaper protocol implementation

- (NSRect)bounds {
	return imageFrame;
}

- (NSRect)highlightBounds {
	return [[NSBezierPath bezierPathWithRect:imageFrame] highlightedStrokeBounds];
}

- (void)drawInRect:(NSRect)dirtyRect
		 withRects:(const NSRect *)dirtyRects
			 count:(NSInteger)dirtyRectsCount
{
	[theImage drawInRect:imageFrame
				fromRect:NSZeroRect
			   operation:NSCompositeSourceOver
				fraction:1.0];
}

- (void)drawWithHighlightInRect:(NSRect)dirtyRect
					  withRects:(const NSRect *)dirtyRects
						  count:(NSInteger)dirtyRectsCount
{
	[[NSBezierPath bezierPathWithRect:imageFrame] highlightedStroke];
	[self drawInRect:dirtyRect
		   withRects:dirtyRects
			   count:dirtyRectsCount];
}

- (BOOL)passesThroughRect:(NSRect)rect {
	// NOTE: CGRectIntersectsRect behaves better than NSIntersectsRect when width or height is zero
	return CGRectIntersectsRect(NSRectToCGRect(rect), NSRectToCGRect(imageFrame));
}

- (BOOL)passesThroughRectValue:(NSValue *)rectValue {
	return [self passesThroughRect:[rectValue rectValue]];
}

- (BOOL)passesThroughRegionEnclosedByPath:(NSBezierPath *)path {
	return [path overlapsRect:imageFrame];
}

- (void)transformUsingAffineTransform:(NSAffineTransform *)aTransform {
	imageFrame.origin = [aTransform transformPoint:imageFrame.origin];
	imageFrame.size = [aTransform transformSize:imageFrame.size];
}

#pragma mark -
#pragma mark for archiving/unarchiving (for saving/loading documents)

// MARK: string keys for NSCoding
NSString * const kMWJPastedImageImageKey = @"MWJPastedImageImageKey";
NSString * const kMWJPastedImageFrameKey = @"MWJPastedImageFrameKey";

- (void)encodeWithCoder:(NSCoder *)coder {
	// NSObject does not conform to NSCoding
	//    [super encodeWithCoder:coder];
    [coder encodeObject:theImage forKey:kMWJPastedImageImageKey];
	[coder encodeRect:imageFrame forKey:kMWJPastedImageFrameKey];
}

- (id)initWithCoder:(NSCoder *)coder {
	// NSObject does not conform to NSCoding
	//    self = [super initWithCoder:coder];
	self = [super init];
	if (self) {
		theImage = [[coder decodeObjectForKey:kMWJPastedImageImageKey] retain];
		imageFrame = [coder decodeRectForKey:kMWJPastedImageFrameKey];
	}
    return self;
}


@end
