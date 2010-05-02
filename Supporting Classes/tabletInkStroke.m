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
//  tabletInkStroke.m
//  MacWJ
//

#import "tabletInkStroke.h"
#import "tabletPenNib.h"
#import "NSBezierPath+boundsWithLines.h"


@interface tabletInkStroke (private)

- (NSImage *)imageFromStroke;

@end

@implementation tabletInkStroke

@synthesize color, currentPoint;

// MARK: string keys for NSCoding
NSString * const kTabletInkStrokeColorKey = @"tabletInkStrokeColorKey";
NSString * const kTabletInkStrokePathsKey = @"tabletInkStrokePathsKey";
NSString * const kTabletInkStrokeCurrentPointKey = @"tabletInkStrokeCurrentPointKey";

#pragma mark -

+ (NSImage *)sampleStrokeImageWithPenNib:(tabletPenNib *)nib {
	NSArray *thePoints = [NSArray arrayWithObjects:
						  // generated using Mathematica
						  [NSValue valueWithPoint:NSMakePoint(2.3, 1.3)],
						  [NSValue valueWithPoint:NSMakePoint(13.1, 6.9)],
						  [NSValue valueWithPoint:NSMakePoint(22.7, 14.1)],
						  [NSValue valueWithPoint:NSMakePoint(30.6, 22.5)],
						  [NSValue valueWithPoint:NSMakePoint(36.7, 31.7)],
						  [NSValue valueWithPoint:NSMakePoint(40.7, 41.2)],
						  [NSValue valueWithPoint:NSMakePoint(42.7, 50.5)],
						  [NSValue valueWithPoint:NSMakePoint(42.8, 58.9)],
						  [NSValue valueWithPoint:NSMakePoint(41.3, 66.1)],
						  [NSValue valueWithPoint:NSMakePoint(38.6, 71.7)],
						  [NSValue valueWithPoint:NSMakePoint(35., 75.4)],
						  [NSValue valueWithPoint:NSMakePoint(31.2, 77.1)],
						  [NSValue valueWithPoint:NSMakePoint(27.7, 76.7)],
						  [NSValue valueWithPoint:NSMakePoint(25., 74.5)],
						  [NSValue valueWithPoint:NSMakePoint(23.4, 70.6)],
						  [NSValue valueWithPoint:NSMakePoint(23.6, 65.5)],
						  [NSValue valueWithPoint:NSMakePoint(25.6, 59.6)],
						  [NSValue valueWithPoint:NSMakePoint(29.6, 53.5)],
						  [NSValue valueWithPoint:NSMakePoint(35.7, 47.6)],
						  [NSValue valueWithPoint:NSMakePoint(43.6, 42.4)],
						  [NSValue valueWithPoint:NSMakePoint(53.2, 38.6)],
						  [NSValue valueWithPoint:NSMakePoint(64., 36.3)],
						  [NSValue valueWithPoint:NSMakePoint(75.6, 36.)],
						  [NSValue valueWithPoint:NSMakePoint(87.4, 37.6)],
						  [NSValue valueWithPoint:NSMakePoint(99., 41.3)],
						  nil];
	tabletInkStroke *stroke = [[tabletInkStroke alloc] initWithPoint:[[thePoints objectAtIndex:0] pointValue]];
	[stroke setColor:[nib inkColor]];
	NSUInteger pointCount = [thePoints count];
	for (NSUInteger index = 1; index < pointCount; index++) {
		NSPoint aPoint = [[thePoints objectAtIndex:index] pointValue];
		[stroke lineToPoint:aPoint
			  withThickness:[nib lineWidthFrom:[stroke currentPoint]
								  withPressure:(1.0 * index / pointCount)
											to:aPoint
								  withPressure:(1.0 * (index + 1) / pointCount)]];
	}
	
	NSImage *resultingImage = [stroke imageFromStroke];
	[stroke release];
	return resultingImage;
}

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

- (void)strokeInRect:(NSRect)dirtyRect
		   withRects:(const NSRect *)dirtyRects
			   count:(NSInteger)dirtyRectsCount
{
	// Save the current graphics state first so we can restore it.
	[[NSGraphicsContext currentContext] saveGraphicsState];
	
	[[self color] setStroke];
    NSInteger i;
	for (NSBezierPath *aPath in paths) {
        // First test against coalesced rect.
		CGRect pathBounds = NSRectToCGRect([aPath boundsWithLines]);
		// NOTE: CGRectIntersectsRect behaves better than NSIntersectsRect when width or height is zero
		if (CGRectIntersectsRect(pathBounds,NSRectToCGRect(dirtyRect))) {
			// Then test per dirty rect
            for (i = 0; i < dirtyRectsCount; i++) {
				if (CGRectIntersectsRect(pathBounds,NSRectToCGRect(dirtyRects[i]))) {
					[aPath stroke];
                    break;
                }
            }
        }
    }
	
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


#pragma mark -
#pragma mark for archiving/unarchiving (for saving/loading documents)

- (void)encodeWithCoder:(NSCoder *)coder {
	// NSObject does not conform to NSCoding
//    [super encodeWithCoder:coder];
    [coder encodeObject:color forKey:kTabletInkStrokeColorKey];
    [coder encodeObject:paths forKey:kTabletInkStrokePathsKey];
	[coder encodePoint:currentPoint forKey:kTabletInkStrokeCurrentPointKey];
}

- (id)initWithCoder:(NSCoder *)coder {
	// NSObject does not conform to NSCoding
//    self = [super initWithCoder:coder];
	self = [super init];
	if (self) {
		[self setColor:[coder decodeObjectForKey:kTabletInkStrokeColorKey]];
		paths = [[coder decodeObjectForKey:kTabletInkStrokePathsKey] retain];
		currentPoint = [coder decodePointForKey:kTabletInkStrokeCurrentPointKey];
	}
    return self;
}



@end
