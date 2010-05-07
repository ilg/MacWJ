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

// MARK: tool type constants
NSUInteger const kTabletViewPenToolType = 0;
NSUInteger const kTabletViewEraserToolType = 1;
NSUInteger const kTabletViewRectangularMarqueeToolType = 2;


@interface tabletView (UndoAndRedo)

- (NSUndoManager *)undoManager;
- (void)undoableAddStrokes:(NSArray *)strokesToAdd
				 atIndexes:(NSIndexSet *)indexesToAdd;
- (void)undoableEraseStrokesAtIndexes:(NSIndexSet *)indexesToErase;
- (void)addStroke:(tabletInkStroke *)strokeToAdd;
- (void)eraseStrokesWithIndexes:(NSIndexSet *)indexesToErase;

@end


@implementation tabletView

static NSCursor *penCursor;
static NSCursor *eraserCursor;

@synthesize currentPenNib,toolType;

@synthesize selectedStrokeIndexes,selectionPath;

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
		[self setToolType:kTabletViewPenToolType];
		
		[self setSelectedStrokeIndexes:[NSIndexSet indexSet]];
		[self setSelectionPath:nil];
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect {
    // Drawing code here.
	const NSRect *dirtyRects;
    NSInteger dirtyRectsCount, i;
    [self getRectsBeingDrawn:&dirtyRects count:&dirtyRectsCount];
	
	NSArray *selectedStrokes = [strokes objectsAtIndexes:[self selectedStrokeIndexes]];
	
	// draw any selected (highlighted) strokes first
	for (tabletInkStroke *aStroke in selectedStrokes) {
        // First test against coalesced rect.
		if ([aStroke passesThroughRect:dirtyRect]) {
			// Then test per dirty rect
            for (i = 0; i < dirtyRectsCount; i++) {
				if ([aStroke passesThroughRect:dirtyRects[i]]) {
					[aStroke strokeWithHighlightInRect:dirtyRect
								withRects:dirtyRects
									count:dirtyRectsCount];
                    break;
                }
            }
        }
    }
	
	// draw the unselected strokes
	for (tabletInkStroke *aStroke in strokes) {
		if (![selectedStrokes containsObject:aStroke]) {
			// First test against coalesced rect.
			if ([aStroke passesThroughRect:dirtyRect]) {
				// Then test per dirty rect
				for (i = 0; i < dirtyRectsCount; i++) {
					if ([aStroke passesThroughRect:dirtyRects[i]]) {
						[aStroke strokeInRect:dirtyRect
									withRects:dirtyRects
										count:dirtyRectsCount];
						break;
					}
				}
			}
		}
    }
	
	if (NSIntersectsRect(dirtyRect, [[self selectionPath] bounds])) {
		[[NSColor blackColor] setStroke];
		[[self selectionPath] setLineWidth:1.0];
		[[self selectionPath] stroke];
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

- (void)undoableAddStrokes:(NSArray *)strokesToAdd
				 atIndexes:(NSIndexSet *)indexesToAdd
{
	[strokes insertObjects:strokesToAdd atIndexes:indexesToAdd];
	NSUndoManager *undoer = [self undoManager];
	[[undoer prepareWithInvocationTarget:self]
	 undoableEraseStrokesAtIndexes:indexesToAdd];
	[undoer setActionName:NSLocalizedString([undoer isUndoing] ? @"Erasing" : @"Inking",@"")];
	for (tabletInkStroke *aStroke in strokesToAdd) {
		[self setNeedsDisplayInRect:[aStroke bounds]];
	}
}

- (void)undoableEraseStrokesAtIndexes:(NSIndexSet *)indexesToErase 
{
	if ([indexesToErase count] > 0) {
		NSArray *strokesBeingErased = [strokes objectsAtIndexes:indexesToErase];
		[strokes removeObjectsAtIndexes:indexesToErase];
		NSUndoManager *undoer = [self undoManager];
		[[undoer prepareWithInvocationTarget:self]
		 undoableAddStrokes:strokesBeingErased
		 atIndexes:indexesToErase];
		[undoer setActionName:NSLocalizedString([undoer isUndoing] ? @"Inking" : @"Erasing",@"")];
		for (tabletInkStroke *aStroke in strokesBeingErased) {
			[self setNeedsDisplayInRect:[aStroke bounds]];
		}
	}
}

- (void)addStroke:(tabletInkStroke *)strokeToAdd {
	[self undoableAddStrokes:[NSArray arrayWithObject:strokeToAdd]
				   atIndexes:[NSIndexSet indexSetWithIndex:[strokes count]]];
}

- (void)eraseStrokesWithIndexes:(NSIndexSet *)indexesToErase {
	[self undoableEraseStrokesAtIndexes:indexesToErase];
}

#pragma mark -
#pragma mark for creating ink strokes

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

#pragma mark -
#pragma mark for erasing strokes

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
#pragma mark for rectangular marquee selection

- (NSRect)rectFromPoint:(NSPoint)aPoint
				toPoint:(NSPoint)bPoint
{
	return NSMakeRect(
					  MIN(aPoint.x,bPoint.x),
					  MIN(aPoint.y,bPoint.y),
					  ABS(aPoint.x - bPoint.x),
					  ABS(aPoint.y - bPoint.y)
					  );
}

- (void)continueRectangularSelection:(NSEvent *)theEvent {
	NSPoint endPoint = [self convertPoint:[theEvent locationInWindow]
								 fromView:nil];
	NSRect selectionRect = [self rectFromPoint:rectangularSelectionOrigin
									   toPoint:endPoint];
	[self setNeedsDisplayInRect:NSUnionRect(selectionRect, [[self selectionPath] boundsWithLines])];
	[self setSelectionPath:[NSBezierPath bezierPathWithRect:selectionRect]];
}

- (void)endRectangularSelection:(NSEvent *)theEvent {
	NSPoint endPoint = [self convertPoint:[theEvent locationInWindow]
								 fromView:nil];
	NSRect selectionRect = [self rectFromPoint:rectangularSelectionOrigin
									   toPoint:endPoint];
	NSRect needsDisplayRect = NSUnionRect(selectionRect, [[self selectionPath] boundsWithLines]);
	[self setSelectionPath:[NSBezierPath bezierPathWithRect:selectionRect]];
	
	NSMutableIndexSet *indexesToSelect = [[NSMutableIndexSet alloc] init];
	for (NSUInteger strokeIndex = 0; strokeIndex < [strokes count]; strokeIndex++) {
		if ([[strokes objectAtIndex:strokeIndex] passesThroughRect:selectionRect]) {
			[indexesToSelect addIndex:strokeIndex];
			needsDisplayRect = NSUnionRect(needsDisplayRect, [[strokes objectAtIndex:strokeIndex] bounds]);
		}
	}
	[self setSelectedStrokeIndexes:[[[NSIndexSet alloc] initWithIndexSet:indexesToSelect] autorelease]];
	[indexesToSelect release];
	
	[self setNeedsDisplayInRect:needsDisplayRect];
	[self setSelectionPath:nil];
}

- (void)startRectangularSelection:(NSEvent *)theEvent {
	rectangularSelectionOrigin = [self convertPoint:[theEvent locationInWindow]
										   fromView:nil];
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
	if ([[self selectedStrokeIndexes] count] > 0) {
		// if there's a selection, wipe it out and redraw everything
		[self setNeedsDisplay:YES];
		[self setSelectedStrokeIndexes:[NSIndexSet indexSet]];
	}
	
	if ([theEvent subtype] == NSTabletPointEventSubtype) {
		if (pointingDeviceType == NSPenPointingDevice) {
			if ([self toolType] == kTabletViewPenToolType) {
				[self startStroke:theEvent];
			} else if ([self toolType] == kTabletViewRectangularMarqueeToolType) {
				[self startRectangularSelection:theEvent];
			}
		}
		[self tabletPoint:theEvent];
	} else if ([theEvent subtype] == NSTabletProximityEventSubtype) {
		[self tabletProximity:theEvent];
	}
}

- (void)mouseDragged:(NSEvent *)theEvent {
	if ([theEvent subtype] == NSTabletPointEventSubtype) {
		if (pointingDeviceType == NSPenPointingDevice) {
			if ([self toolType] == kTabletViewPenToolType) {
				[self continueStroke:theEvent];
			} else if ([self toolType] == kTabletViewEraserToolType) {
				[self eraseEvent:theEvent];
			} else if ([self toolType] == kTabletViewRectangularMarqueeToolType) {
				[self continueRectangularSelection:theEvent];
			}
		} else if (pointingDeviceType == NSEraserPointingDevice) {
			[self eraseEvent:theEvent];
		}
		[self tabletPoint:theEvent];
	} else if ([theEvent subtype] == NSTabletProximityEventSubtype) {
		[self tabletProximity:theEvent];
	}
}

- (void)mouseUp:(NSEvent *)theEvent {
	if ([theEvent subtype] == NSTabletPointEventSubtype) {
		if (pointingDeviceType == NSPenPointingDevice) {
			if ([self toolType] == kTabletViewPenToolType) {
				[self endStroke:theEvent];
			} else if ([self toolType] == kTabletViewRectangularMarqueeToolType) {
				[self endRectangularSelection:theEvent];
			}
		}
		[self tabletPoint:theEvent];
	} else if ([theEvent subtype] == NSTabletProximityEventSubtype) {
		[self tabletProximity:theEvent];
	}
}



@end
