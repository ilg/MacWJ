/*********************************************************************************
 
 © Copyright 2010-2011, Isaac Greenspan
 
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

#pragma mark -

- (id)initWithPoint:(NSPoint)startingPoint {
	self = [super init];
	if (self) {
		[self setColor:[NSColor blackColor]];
		currentPoint = startingPoint;
		paths = [[NSMutableArray alloc] init];
		pathBounds = [[NSMutableArray alloc] init];
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
	[pathBounds addObject:[NSValue valueWithRect:[newPath boundsWithLines]]];
}

- (NSRect)lastSegmentBounds {
	if ([pathBounds count] > 0) {
		return [[pathBounds lastObject] rectValue];
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

#pragma mark -
#pragma mark MWJObjectOnPaper protocol implementation
// the rest of the protocol is implemented in MWJObjectOnPaperParentClass

- (NSRect)bounds {
	if ([paths count] > 0) {
		NSRect result = [[paths objectAtIndex:0] boundsWithLines];
		for (NSValue *boundsValue in pathBounds) {
			result = NSUnionRect(result, [boundsValue rectValue]);
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
	for (NSValue *boundsValue in pathBounds) {
		CGRect pathRect = NSRectToCGRect([boundsValue rectValue]);
		// NOTE: CGRectIntersectsRect behaves better than NSIntersectsRect when width or height is zero
		if (CGRectIntersectsRect(pathRect,NSRectToCGRect(rect))) {
			passesThrough = YES;
			break;
        }
    }
	return passesThrough;
}

- (BOOL)passesThroughRegionEnclosedByPath:(NSBezierPath *)path {
	BOOL passesThrough = NO;
	for (NSValue *boundsValue in pathBounds) {
		NSRect bounds = [boundsValue rectValue];
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
	NSUInteger pathIndex = 0;
	for (NSBezierPath *aPath in paths) {
		[aPath transformUsingAffineTransform:aTransform];
		[pathBounds replaceObjectAtIndex:pathIndex
							  withObject:[NSValue valueWithRect:[aPath boundsWithLines]]];
		pathIndex++;
	}
}


#pragma mark -
#pragma mark for archiving/unarchiving (for saving/loading documents)

// MARK: string keys for NSCoding
NSString * const kMWJInkingStrokeColorKey = @"MWJInkingStrokeColorKey";
NSString * const kMWJInkingStrokePathsKey = @"MWJInkingStrokePathsKey";
NSString * const kMWJInkingStrokeCurrentPointKey = @"MWJInkingStrokeCurrentPointKey";
// legacy keys:
NSString * const kMWJInkingStrokeColorLegacyKey = @"tabletInkStrokeColorKey";
NSString * const kMWJInkingStrokePathsLegacyKey = @"tabletInkStrokePathsKey";
NSString * const kMWJInkingStrokeCurrentPointLegacyKey = @"tabletInkStrokeCurrentPointKey";

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
		if (![self color]) [self setColor:[coder decodeObjectForKey:kMWJInkingStrokeColorLegacyKey]];
		
		paths = [[coder decodeObjectForKey:kMWJInkingStrokePathsKey] retain];
		if (!paths) paths = [[coder decodeObjectForKey:kMWJInkingStrokePathsLegacyKey] retain];
		
		// recompute the pathBounds array because NSValue objects containing NSRects won't encode
		// and it's not worth the time-savings on opening a file to spend the time on saving the file
		pathBounds = [[NSMutableArray alloc] init];
		for (NSBezierPath *aPath in paths) {
			[pathBounds addObject:[NSValue valueWithRect:[aPath boundsWithLines]]];
		}
		
		if ([coder containsValueForKey:kMWJInkingStrokeCurrentPointKey]) {
			currentPoint = [coder decodePointForKey:kMWJInkingStrokeCurrentPointKey];
		} else if ([coder containsValueForKey:kMWJInkingStrokeCurrentPointLegacyKey]) {
			currentPoint = [coder decodePointForKey:kMWJInkingStrokeCurrentPointLegacyKey];
		} else {
			currentPoint = NSZeroPoint;
		}
	}
    return self;
}



@end
