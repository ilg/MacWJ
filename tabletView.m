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
//  tabletView.m
//  tablet experiment
//

#import "tabletView.h"
#import "NSBezierPath+boundsWithLines.h"

#define MIN_STROKE_WIDTH [[NSUserDefaults standardUserDefaults] floatForKey:@"minStrokeWidth"]
#define MAX_STROKE_WIDTH [[NSUserDefaults standardUserDefaults] floatForKey:@"maxStrokeWidth"]
#define ERASER_RADIUS [[NSUserDefaults standardUserDefaults] floatForKey:@"eraserRadius"]

@implementation tabletView

static NSCursor *penCursor;
static NSCursor *eraserCursor;

+ (void)initialize {
	penCursor = [[NSCursor alloc] initWithImage:[NSImage imageNamed:@"single-dot"]
										hotSpot:NSMakePoint(0.0, 0.0)];
	eraserCursor = [[NSCursor alloc] initWithImage:[NSImage imageNamed:@"single-dot"]
										   hotSpot:NSMakePoint(0.0, 0.0)];
}

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
		paths = [[NSMutableArray alloc] initWithCapacity:100];
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect {
    // Drawing code here.
	[[NSColor blackColor] setStroke];
	const NSRect *dirtyRects;
    NSInteger dirtyRectsCount, i;
    [self getRectsBeingDrawn:&dirtyRects count:&dirtyRectsCount];
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
}

- (BOOL)isFlipped {
	return YES;
}

- (BOOL)acceptsFirstResponder
{
	return YES;
}

#pragma mark -

- (CGFloat)lineWidthForPressure:(CGFloat)pressure
						  start:(NSPoint)start
							end:(NSPoint)end
{
	CGFloat halfPi = 2.0 * atanf(1.0);
	CGFloat angle =  - (start.x - end.x)!=0.0 ? atanf((start.y - end.y) / (start.x - end.x)) : halfPi;
	CGFloat angleWidthMultiplier = (ABS(angle + halfPi / 2) + halfPi / 2) / (2 * halfPi);
	CGFloat adjustedPressure = (initialPressure + pressure)/2.0;
	return MAX(MIN_STROKE_WIDTH,adjustedPressure * angleWidthMultiplier * MAX_STROKE_WIDTH);
}

- (void)endPath:(NSEvent *)theEvent {
	NSPoint newPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	CGFloat width = [self lineWidthForPressure:[theEvent pressure]
										 start:[workingPath currentPoint]
										   end:newPoint];
	if (workingPath) {
		[workingPath setLineWidth:width];
		[workingPath setLineCapStyle:NSRoundLineCapStyle];
		[workingPath lineToPoint:newPoint];
		[self setNeedsDisplayInRect:[workingPath boundsWithLines]];
		[workingPath release];
		workingPath = nil;
	} else {
		NSLog(@"endPath: with no workingPath");
	}
}

- (void)startPath:(NSEvent *)theEvent {
	if (!paths) {
		paths = [[NSMutableArray alloc] init];
	}
	if (workingPath) {
		[self endPath:theEvent];
	}
	workingPath = [[NSBezierPath alloc] init];
	[paths addObject:workingPath];
	[workingPath moveToPoint:[self convertPoint:[theEvent locationInWindow] fromView:nil]];
	initialPressure = [theEvent pressure];
}

- (void)eraseEvent:(NSEvent *)theEvent {
	NSMutableIndexSet *indexesToDelete = [NSMutableIndexSet indexSet];
	for (NSUInteger pathIndex = 0; pathIndex < [paths count]; pathIndex++) {
		NSRect pathBounds = [[paths objectAtIndex:pathIndex] boundsWithLines];
		NSPoint erasePoint = [self convertPoint:[theEvent locationInWindow]
									   fromView:nil];
		CGRect eraseArea = CGRectMake(erasePoint.x - ERASER_RADIUS, erasePoint.y - ERASER_RADIUS,
									  2.0 * ERASER_RADIUS, 2.0 * ERASER_RADIUS);
		if (CGRectIntersectsRect(NSRectToCGRect(pathBounds),eraseArea)) {
			[indexesToDelete addIndex:pathIndex];
			[self setNeedsDisplayInRect:pathBounds];
		}
	}
	[paths removeObjectsAtIndexes:indexesToDelete];
}

- (NSRect)pathBounds {
	NSRect result = [[paths objectAtIndex:0] boundsWithLines];
	for (NSBezierPath *path in paths) {
		result = NSUnionRect(result, [path boundsWithLines]);
	}
	return result;
}

- (IBAction)copy:(id)sender
{
	NSPasteboard *pb = [NSPasteboard generalPasteboard];
	[pb declareTypes:[NSArray arrayWithObjects:NSPDFPboardType, nil] owner:nil];
	[pb setData:[self dataWithPDFInsideRect:[self pathBounds]] forType:NSPDFPboardType];
}

#pragma mark -
#pragma mark tablet/mouse event handling

- (void)tabletProximity:(NSEvent *)theEvent {
	pointingDeviceType = [theEvent pointingDeviceType];
	if (pointingDeviceType == NSUnknownPointingDevice) {
	} else if (pointingDeviceType == NSPenPointingDevice) {
		if ([theEvent isEnteringProximity]) {
			[penCursor push];
		} else {
			[NSCursor pop];
		}
	} else if (pointingDeviceType == NSCursorPointingDevice) {
	} else if (pointingDeviceType == NSEraserPointingDevice) {
		if ([theEvent isEnteringProximity]) {
			[eraserCursor push];
		} else {
			[NSCursor pop];
		}
	} else {
//		NSLog(@"pointing device type is not a recognized constant");
	}
}

- (void)tabletPoint:(NSEvent *)theEvent {
}

- (void)mouseDown:(NSEvent *)theEvent {
	if ([theEvent subtype] == NSTabletPointEventSubtype) {
		if (pointingDeviceType == NSPenPointingDevice) [self startPath:theEvent];
		[self tabletPoint:theEvent];
	} else if ([theEvent subtype] == NSTabletProximityEventSubtype) {
		[self tabletProximity:theEvent];
	}
}

- (void)mouseDragged:(NSEvent *)theEvent {
	if ([theEvent subtype] == NSTabletPointEventSubtype) {
		if (pointingDeviceType == NSPenPointingDevice) [self startPath:theEvent];
		if (pointingDeviceType == NSEraserPointingDevice) [self eraseEvent:theEvent];
		[self tabletPoint:theEvent];
	} else if ([theEvent subtype] == NSTabletProximityEventSubtype) {
		[self tabletProximity:theEvent];
	}
}

- (void)mouseUp:(NSEvent *)theEvent {
	if ([theEvent subtype] == NSTabletPointEventSubtype) {
		if (pointingDeviceType == NSPenPointingDevice) [self endPath:theEvent];
		[self tabletPoint:theEvent];
	} else if ([theEvent subtype] == NSTabletProximityEventSubtype) {
		[self tabletProximity:theEvent];
	}
}



@end
