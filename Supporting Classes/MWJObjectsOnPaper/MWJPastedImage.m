//
//  MWJPastedImage.m
//  MacWJ
//
//  Created by Isaac Greenspan on 5/8/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "MWJPastedImage.h"
#import "NSBezierPath+highlightedStroke.h"


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
	// test the four corners of the imageFrame
	// TODO: this isn't good at all for an image, but I don't have anything better just yet
	return ([path containsPoint:imageFrame.origin]
			|| [path containsPoint:NSMakePoint(imageFrame.origin.x,
											   imageFrame.origin.y + imageFrame.size.height)]
			|| [path containsPoint:NSMakePoint(imageFrame.origin.x + imageFrame.size.width,
											   imageFrame.origin.y)]
			|| [path containsPoint:NSMakePoint(imageFrame.origin.x + imageFrame.size.width,
											   imageFrame.origin.y + imageFrame.size.height)]
			);
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
