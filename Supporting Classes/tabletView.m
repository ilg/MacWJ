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
//  MacWJ
//

#import "tabletView.h"
#import "NSBezierPath+boundsWithLines.h"
#import "tabletInkStroke.h"
#import "tabletPenNib.h"

#define MIN_STROKE_WIDTH [[NSUserDefaults standardUserDefaults] floatForKey:@"minStrokeWidth"]
#define MAX_STROKE_WIDTH [[NSUserDefaults standardUserDefaults] floatForKey:@"maxStrokeWidth"]
#define ERASER_RADIUS [[NSUserDefaults standardUserDefaults] floatForKey:@"eraserRadius"]
#define COPY_AS_IMAGE_SCALE_FACTOR [[NSUserDefaults standardUserDefaults] floatForKey:@"copyAsImageScaleFactor"]

@implementation tabletView

static NSCursor *penCursor;
static NSCursor *eraserCursor;

@synthesize currentPenNib;

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
		strokes = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect {
    // Drawing code here.
	const NSRect *dirtyRects;
    NSInteger dirtyRectsCount, i;
    [self getRectsBeingDrawn:&dirtyRects count:&dirtyRectsCount];
	for (tabletInkStroke *aStroke in strokes) {
        // First test against coalesced rect.
		CGRect strokeBounds = NSRectToCGRect([aStroke bounds]);
		// NOTE: CGRectIntersectsRect behaves better than NSIntersectsRect when width or height is zero
		if (CGRectIntersectsRect(strokeBounds,NSRectToCGRect(dirtyRect))) {
			// Then test per dirty rect
            for (i = 0; i < dirtyRectsCount; i++) {
				if (CGRectIntersectsRect(strokeBounds,NSRectToCGRect(dirtyRects[i]))) {
					[aStroke strokeInRect:dirtyRect
								withRects:dirtyRects
									count:dirtyRectsCount];
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
#pragma mark for Undo/Redo

- (NSUndoManager *)undoManager {
	return [[[self window] delegate] undoManager];
}

- (void)addStrokes:(NSArray *)strokesToAdd {
	NSUInteger originalCount = [strokes count];
	NSUInteger addedCount = [strokesToAdd count];
	[strokes addObjectsFromArray:strokesToAdd];
	NSUndoManager *undoer = [self undoManager];
	[[undoer prepareWithInvocationTarget:self]
	 eraseStrokesWithIndexes:[NSIndexSet indexSetWithIndexesInRange:
							  NSMakeRange(originalCount, addedCount)]];
	[undoer setActionName:NSLocalizedString([undoer isUndoing] ? @"Erasing" : @"Inking",@"")];
	for (tabletInkStroke *aStroke in strokesToAdd) {
		[self setNeedsDisplayInRect:[aStroke bounds]];
	}
}

- (void)addStroke:(tabletInkStroke *)stroke {
	[self addStrokes:[NSArray arrayWithObject:stroke]];
}

- (void)eraseStrokesWithIndexes:(NSIndexSet *)indexesToErase {
	if ([indexesToErase count] > 0) {
		NSLog(@"eraseStrokesWithIdexes:%@", indexesToErase);
		NSArray *strokesBeingErased = [strokes objectsAtIndexes:indexesToErase];
		NSLog(@"[strokesBeingErased = %@", strokesBeingErased);
		[strokes removeObjectsAtIndexes:indexesToErase];
		NSUndoManager *undoer = [self undoManager];
		[[undoer prepareWithInvocationTarget:self]
		 addStrokes:strokesBeingErased];
		[undoer setActionName:NSLocalizedString([undoer isUndoing] ? @"Inking" : @"Erasing",@"")];
		for (tabletInkStroke *aStroke in strokesBeingErased) {
			[self setNeedsDisplayInRect:[aStroke bounds]];
		}
	}
}

#pragma mark -

- (CGFloat)lineWidthForPressure:(CGFloat)pressure
						  start:(NSPoint)start
							end:(NSPoint)end
{
	return [currentPenNib lineWidthFrom:start
						   withPressure:initialPressure
									 to:end
						   withPressure:pressure];
}

- (void)continueStroke:(NSEvent *)theEvent {
	NSPoint newPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	CGFloat width = [self lineWidthForPressure:[theEvent pressure]
										 start:[workingStroke currentPoint]
										   end:newPoint];
	if (workingStroke) {
		[workingStroke lineToPoint:newPoint
					 withThickness:width];
		[self setNeedsDisplayInRect:[workingStroke lastSegmentBounds]];
	} else {
		NSLog(@"continueStroke: with no workingStroke");
	}
}

- (void)endStroke:(NSEvent *)theEvent {
	[self continueStroke:theEvent];
	[workingStroke release];
	workingStroke = nil;
}

- (void)startStroke:(NSEvent *)theEvent {
	if (!strokes) {
		strokes = [[NSMutableArray alloc] init];
	}
	if (!currentPenNib) {
		currentPenNib = [[tabletPenNib tabletPenNibWithMinimumWidth:MIN_STROKE_WIDTH
													   maximumWidth:MAX_STROKE_WIDTH
												   isAngleDependent:YES
												   angleForMaxWidth:(-pi/4.0)
															  color:[NSColor blackColor]]
						 retain];
	}		
	if (workingStroke) {
		[self continueStroke:theEvent];
	} else {
		workingStroke = [[tabletInkStroke alloc]
						 initWithPoint:[self convertPoint:[theEvent locationInWindow]
												 fromView:nil]];
		[workingStroke setColor:[currentPenNib inkColor]];
		[self addStroke:workingStroke];
	}
	initialPressure = [theEvent pressure];
}

- (void)eraseEvent:(NSEvent *)theEvent {
	NSMutableIndexSet *indexesToDelete = [NSMutableIndexSet indexSet];
	NSPoint erasePoint = [self convertPoint:[theEvent locationInWindow]
								   fromView:nil];
	NSRect eraseArea = NSMakeRect(erasePoint.x - ERASER_RADIUS, erasePoint.y - ERASER_RADIUS,
								  2.0 * ERASER_RADIUS, 2.0 * ERASER_RADIUS);
	for (NSUInteger strokeIndex = 0; strokeIndex < [strokes count]; strokeIndex++) {
		if ([[strokes objectAtIndex:strokeIndex] passesThroughRect:eraseArea]) {
			[indexesToDelete addIndex:strokeIndex];
		}
	}
	[self eraseStrokesWithIndexes:indexesToDelete];
}

#pragma mark -

- (NSRect)pathBounds {
	if ([strokes count] > 0) {
		NSRect result = [[strokes objectAtIndex:0] bounds];
		for (tabletInkStroke *aStroke in strokes) {
			result = NSUnionRect(result, [aStroke bounds]);
		}
		return result;
	} else {
		return NSMakeRect(0.0, 0.0, 0.0, 0.0);
	}
}

#pragma mark -
#pragma mark for saving and loading

- (NSData *)data {
	return [NSKeyedArchiver archivedDataWithRootObject:[NSArray arrayWithArray:strokes]];
}

- (void)loadFromData:(NSData *)data {
	[strokes release];
	NSArray *loadedArray = [NSKeyedUnarchiver unarchiveObjectWithData:data];
	strokes = [[NSMutableArray alloc] initWithArray:loadedArray];
}

- (NSData *)PNGData {
	NSImage *image = [[NSImage alloc] initWithData:[self dataWithPDFInsideRect:[self pathBounds]]];
	NSSize imageSize = [image size];
	imageSize.width = imageSize.width * COPY_AS_IMAGE_SCALE_FACTOR;
	imageSize.height = imageSize.height * COPY_AS_IMAGE_SCALE_FACTOR;
	[image setSize:imageSize];
	NSBitmapImageRep* bm = [NSBitmapImageRep
							imageRepWithData:[image TIFFRepresentation]];
	[image release];
	return [bm representationUsingType:NSPNGFileType properties:nil];
}

- (NSData *)PDFData {
	return [self dataWithPDFInsideRect:[self pathBounds]];
}


#pragma mark -
#pragma mark copying to externalize

- (IBAction)copy:(id)sender
{
	NSPasteboard *pb = [NSPasteboard generalPasteboard];
	[pb declareTypes:[NSArray arrayWithObjects:NSPDFPboardType, nil] owner:nil];
	[pb setData:[self PDFData] forType:NSPDFPboardType];
}

- (IBAction)copyAsImage:(id)sender
{
	NSPasteboard *pb = [NSPasteboard generalPasteboard];
	[pb declareTypes:[NSArray arrayWithObjects:NSTIFFPboardType, nil] owner:nil];
	NSImage *image = [[NSImage alloc] initWithData:[self dataWithPDFInsideRect:[self pathBounds]]];
	NSSize imageSize = [image size];
	imageSize.width = imageSize.width * COPY_AS_IMAGE_SCALE_FACTOR;
	imageSize.height = imageSize.height * COPY_AS_IMAGE_SCALE_FACTOR;
	[image setSize:imageSize];
	[pb setData:[image TIFFRepresentation] forType:NSTIFFPboardType];
	[image release];
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
		if (pointingDeviceType == NSPenPointingDevice) [self startStroke:theEvent];
		[self tabletPoint:theEvent];
	} else if ([theEvent subtype] == NSTabletProximityEventSubtype) {
		[self tabletProximity:theEvent];
	}
}

- (void)mouseDragged:(NSEvent *)theEvent {
	if ([theEvent subtype] == NSTabletPointEventSubtype) {
		if (pointingDeviceType == NSPenPointingDevice) [self continueStroke:theEvent];
		if (pointingDeviceType == NSEraserPointingDevice) [self eraseEvent:theEvent];
		[self tabletPoint:theEvent];
	} else if ([theEvent subtype] == NSTabletProximityEventSubtype) {
		[self tabletProximity:theEvent];
	}
}

- (void)mouseUp:(NSEvent *)theEvent {
	if ([theEvent subtype] == NSTabletPointEventSubtype) {
		if (pointingDeviceType == NSPenPointingDevice) [self endStroke:theEvent];
		[self tabletPoint:theEvent];
	} else if ([theEvent subtype] == NSTabletProximityEventSubtype) {
		[self tabletProximity:theEvent];
	}
}



@end
