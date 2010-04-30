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
#import "NSBezierPath+boundsWithLines.h"


@implementation tabletInkStroke

@synthesize color, currentPoint;

// MARK: string keys for NSCoding
NSString * const kTabletInkStrokeColorKey = @"tabletInkStrokeColorKey";
NSString * const kTabletInkStrokePathsKey = @"tabletInkStrokePathsKey";
NSString * const kTabletInkStrokeCurrentPointKey = @"tabletInkStrokeCurrentPointKey";

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

- (NSRect)lastSegmentBounds {
	if ([paths count] > 0) {
		return [[paths lastObject] boundsWithLines];
	} else {
		return NSMakeRect(0.0, 0.0, 0.0, 0.0);
	}
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
