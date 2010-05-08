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
//  MWJInkingStroke.m
//  MacWJ
//

#import "MWJInkingStroke.h"
#import "MWJInkingPenNib.h"
#import "NSBezierPath+boundsWithLines.h"
#import "NSBezierPath+highlightedStroke.h"
#import "NSBezierPath+isInRect_withRects_count_.h"


@implementation MWJInkingStroke

@synthesize color, currentPoint;

// MARK: string keys for NSCoding
NSString * const kMWJInkingStrokeColorKey = @"MWJInkingStrokeColorKey";
NSString * const kMWJInkingStrokePathsKey = @"MWJInkingStrokePathsKey";
NSString * const kMWJInkingStrokeCurrentPointKey = @"MWJInkingStrokeCurrentPointKey";

#pragma mark -

- (id)initWithPoint:(NSPoint)startingPoint {
	self = [super init];
	if (self) {
		[self setColor:[NSColor blackColor]];
		currentPoint = startingPoint;
		paths = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void)lineToPoint:(NSPoint)endPoint
	  withThickness:(CGFloat)lineWidth
{
	NSBezierPath *newPath = [NSBezierPath bezierPath];
	[newPath moveToPoint:currentPoint];
	[newPath lineToPoint:endPoint];
	[newPath setLineWidth:lineWidth];
	[newPath setLineCapStyle:NSRoundLineCapStyle];
	currentPoint = endPoint;
	[paths addObject:newPath];
}

- (NSRect)bounds {
	if ([paths count] > 0) {
		NSRect result = [[paths objectAtIndex:0] boundsWithLines];
		for (NSBezierPath *path in paths) {
			result = NSUnionRect(result, [path boundsWithLines]);
		}
		return result;
	} else {
		return NSMakeRect(0.0, 0.0, 0.0, 0.0);
	}
}

- (NSRect)highlightBounds {
	if ([paths count] > 0) {
		NSRect result = [[paths objectAtIndex:0] highlightedStrokeBounds];
		for (NSBezierPath *path in paths) {
			result = NSUnionRect(result, [path highlightedStrokeBounds]);
		}
		return result;
	} else {
		return NSMakeRect(0.0, 0.0, 0.0, 0.0);
	}
}

- (NSRect)lastSegmentBounds {
	if ([paths count] > 0) {
		return [[paths lastObject] boundsWithLines];
	} else {
		return NSMakeRect(0.0, 0.0, 0.0, 0.0);
	}
}

- (NSImage *)imageFromStroke {
	NSImage *resultingImage = [[[NSImage alloc] initWithSize:[self bounds].size] autorelease];
	[resultingImage lockFocus];
	[[self color] setStroke];
	for (NSBezierPath *aPath in paths) {
		[aPath stroke];
    }
	[resultingImage unlockFocus];
	return resultingImage;
}

- (void)drawInRect:(NSRect)dirtyRect
		   withRects:(const NSRect *)dirtyRects
			   count:(NSInteger)dirtyRectsCount
{
	// Save the current graphics state first so we can restore it.
	[[NSGraphicsContext currentContext] saveGraphicsState];
	
	[[self color] setStroke];
	for (NSBezierPath *aPath in paths) {
		if ([aPath isInRect:dirtyRect
				  withRects:dirtyRects
					  count:dirtyRectsCount]) {
			[aPath stroke];
        }
    }
	
	// Restore the original graphics state.
	[[NSGraphicsContext currentContext] restoreGraphicsState];
}

- (void)drawWithHighlightInRect:(NSRect)dirtyRect
						withRects:(const NSRect *)dirtyRects
							count:(NSInteger)dirtyRectsCount
{
	// Save the current graphics state first so we can restore it.
	[[NSGraphicsContext currentContext] saveGraphicsState];
	
	// draw the highlight behind the stroke
	[[self color] setStroke];
	for (NSBezierPath *aPath in paths) {
		if ([aPath isInRect:dirtyRect
				  withRects:dirtyRects
					  count:dirtyRectsCount]) {
			[aPath highlightedStroke];
        }
    }
	// draw the stroke on top of the highlight
	[self drawInRect:dirtyRect
			 withRects:dirtyRects
				 count:dirtyRectsCount];
	
	// Restore the original graphics state.
	[[NSGraphicsContext currentContext] restoreGraphicsState];
}

- (BOOL)passesThroughRect:(NSRect)rect {
	BOOL passesThrough = NO;
	for (NSBezierPath *aPath in paths) {
		CGRect pathBounds = NSRectToCGRect([aPath boundsWithLines]);
		// NOTE: CGRectIntersectsRect behaves better than NSIntersectsRect when width or height is zero
		if (CGRectIntersectsRect(pathBounds,NSRectToCGRect(rect))) {
			passesThrough = YES;
			break;
        }
    }
	return passesThrough;
}

- (BOOL)passesThroughRectValue:(NSValue *)rectValue {
	return [self passesThroughRect:[rectValue rectValue]];
}

- (BOOL)passesThroughRegionEnclosedByPath:(NSBezierPath *)path {
	BOOL passesThrough = NO;
	for (NSBezierPath *aPath in paths) {
		NSRect bounds = [aPath bounds];
		// test the four corners of the bounds
		// (this isn't perfect, but since the individual path segments in a stroke
		//  should be relatively short, this should be good enough)
		if ([path containsPoint:bounds.origin]
			|| [path containsPoint:NSMakePoint(bounds.origin.x,
											   bounds.origin.y + bounds.size.height)]
			|| [path containsPoint:NSMakePoint(bounds.origin.x + bounds.size.width,
											   bounds.origin.y)]
			|| [path containsPoint:NSMakePoint(bounds.origin.x + bounds.size.width,
											   bounds.origin.y + bounds.size.height)]
			) {
			passesThrough = YES;
			break;
        }
    }
	return passesThrough;
}

- (void)transformUsingAffineTransform:(NSAffineTransform *)aTransform {
	for (NSBezierPath *aPath in paths) {
		[aPath transformUsingAffineTransform:aTransform];
	}
}


#pragma mark -
#pragma mark for archiving/unarchiving (for saving/loading documents)

- (void)encodeWithCoder:(NSCoder *)coder {
	// NSObject does not conform to NSCoding
//    [super encodeWithCoder:coder];
    [coder encodeObject:color forKey:kMWJInkingStrokeColorKey];
    [coder encodeObject:paths forKey:kMWJInkingStrokePathsKey];
	[coder encodePoint:currentPoint forKey:kMWJInkingStrokeCurrentPointKey];
}

- (id)initWithCoder:(NSCoder *)coder {
	// NSObject does not conform to NSCoding
//    self = [super initWithCoder:coder];
	self = [super init];
	if (self) {
		[self setColor:[coder decodeObjectForKey:kMWJInkingStrokeColorKey]];
		paths = [[coder decodeObjectForKey:kMWJInkingStrokePathsKey] retain];
		currentPoint = [coder decodePointForKey:kMWJInkingStrokeCurrentPointKey];
	}
    return self;
}



@end
