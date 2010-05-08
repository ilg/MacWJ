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
//  MWJPaperView.m
//  MacWJ
//

#import "MWJPaperView.h"
#import "MWJObjectOnPaper.h"
#import "NSBezierPath+boundsWithLines.h"
#import "MWJInkingStroke.h"
#import "MWJInkingPenNib.h"
#import "MWJPastedImage.h"

#define ERASER_RADIUS [[NSUserDefaults standardUserDefaults] floatForKey:@"eraserRadius"]
#define ATOP_SELECTION_RADIUS 1.0
#define COPY_AS_IMAGE_SCALE_FACTOR [[NSUserDefaults standardUserDefaults] floatForKey:@"copyAsImageScaleFactor"]
#define TABLET_MOUSE_TIME_MARGIN 0.5

// MARK: tool type constants
NSUInteger const kMWJPaperViewPenToolType = 0;
NSUInteger const kMWJPaperViewEraserToolType = 1;
NSUInteger const kMWJPaperViewRectangularMarqueeToolType = 2;
NSUInteger const kMWJPaperViewLassoToolType = 3;

// MARK: pasteboard type constant
NSString * const kMWJPaperViewObjectsOnPaperPboardType = @"kMWJPaperViewObjectsOnPaperPboardType";


@interface MWJPaperView (UndoAndRedo)

- (NSUndoManager *)undoManager;
- (void)undoableAddObjects:(NSArray *)objectsOnPaperToAdd
				 atIndexes:(NSIndexSet *)indexesToAdd
			withActionName:(NSString *)actionName;
- (void)undoableEraseObjectsAtIndexes:(NSIndexSet *)indexesToErase
					   withActionName:(NSString *)actionName;
- (void)undoableAddObjectOnPaper:(id<MWJObjectOnPaper>)objectToAdd
				  withActionName:(NSString *)actionName;
- (void)eraseObjectsWithIndexes:(NSIndexSet *)indexesToErase;
- (void)undoableApplyTransform:(NSAffineTransform *)theTransform
		  toObjectsWithIndexes:(NSIndexSet *)indexesToTransform
				withActionName:(NSString *)actionName;

@end

@interface MWJPaperView (startContinueEndMethods)

- (void)startStroke:(NSEvent *)theEvent;
- (void)continueStroke:(NSEvent *)theEvent;
- (void)endStroke:(NSEvent *)theEvent;

- (void)startRectangularSelection:(NSEvent *)theEvent;
- (void)continueRectangularSelection:(NSEvent *)theEvent;
- (void)endRectangularSelection:(NSEvent *)theEvent;

- (void)startLasso:(NSEvent *)theEvent;
- (void)continueLasso:(NSEvent *)theEvent;
- (void)endLasso:(NSEvent *)theEvent;

- (void)startMovingSelection:(NSEvent *)theEvent;
- (void)continueMovingSelection:(NSEvent *)theEvent;
- (void)endMovingSelection:(NSEvent *)theEvent;

@end

@interface MWJPaperView (selectionHandling)

- (NSArray *)selectedObjects;

@end


#pragma mark -

@implementation MWJPaperView

static NSCursor *penCursor;
static NSCursor *eraserCursor;

@synthesize currentPenNib,toolType;

@synthesize selectedObjectIndexes,selectionPath;

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
		objectsOnPaper = [[NSMutableArray alloc] init];
		[self setToolType:kMWJPaperViewPenToolType];
		
		[self setSelectedObjectIndexes:[NSIndexSet indexSet]];
		[self setSelectionPath:nil];
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect {
    // Drawing code here.
	const NSRect *dirtyRects;
    NSInteger dirtyRectsCount, i;
    [self getRectsBeingDrawn:&dirtyRects count:&dirtyRectsCount];
	
	// draw the objectsOnPaper
	NSUInteger objectIndex = 0;
	for (id<MWJObjectOnPaper> anObjectOnPaper in objectsOnPaper) {
		// First test against coalesced rect.
		if ([anObjectOnPaper passesThroughRect:dirtyRect]) {
			// Then test per dirty rect
			for (i = 0; i < dirtyRectsCount; i++) {
				if ([anObjectOnPaper passesThroughRect:dirtyRects[i]]) {
					if ([[self selectedObjectIndexes] containsIndex:objectIndex]) {
						// object is selected, so draw it with its highlight
						[anObjectOnPaper drawWithHighlightInRect:dirtyRect
													   withRects:dirtyRects
														   count:dirtyRectsCount];
					} else {
						[anObjectOnPaper drawInRect:dirtyRect
										  withRects:dirtyRects
											  count:dirtyRectsCount];
					}
					break;
				}
			}
		}
		objectIndex++;
    }
	
	if ([self selectionPath] && NSIntersectsRect(dirtyRect, [[self selectionPath] bounds])) {
		[[NSColor blackColor] setStroke];
		NSBezierPath *marquee = [self selectionPath];
		[marquee setLineWidth:1.0];
		CGFloat dashing[] = { 3.0, 3.0 };
		[marquee setLineDash:dashing
					   count:2
					   phase:0.0];
		[marquee stroke];
	}
}

- (BOOL)isFlipped {
	return YES;
}

- (BOOL)acceptsFirstResponder {
	return YES;
}

#pragma mark -
#pragma mark selection handling

- (NSArray *)selectedObjects {
	return [objectsOnPaper objectsAtIndexes:[self selectedObjectIndexes]];
}

- (void)selectNone {
	if ([[self selectedObjectIndexes] count] > 0) {
		[self setNeedsDisplay:YES];
		[self setSelectedObjectIndexes:[NSIndexSet indexSet]];
	}
	[self setSelectionPath:nil];
}

- (IBAction)selectAll:(id)sender {
	[self setSelectedObjectIndexes:[NSIndexSet
									indexSetWithIndexesInRange:
									NSMakeRange(0, [objectsOnPaper count])]];
	[self setNeedsDisplay:YES];
}

- (void)setSelectionByTestingWithSelector:(SEL)testingSelector
					  withObjectParameter:(id)testingArgument
{
	NSRect needsDisplayRect = [[self selectionPath] boundsWithLines];
	
	NSMutableIndexSet *indexesToSelect = [[NSMutableIndexSet alloc] init];
	NSUInteger objectIndex = 0;
	for (id<MWJObjectOnPaper> anObjectOnPaper in objectsOnPaper) {
		if ([anObjectOnPaper performSelector:testingSelector
								  withObject:testingArgument]) {
			[indexesToSelect addIndex:objectIndex];
			needsDisplayRect = NSUnionRect(needsDisplayRect,
										   [anObjectOnPaper highlightBounds]);
		}
		objectIndex++;
	}
	[self setSelectedObjectIndexes:[[[NSIndexSet alloc] initWithIndexSet:indexesToSelect] autorelease]];
	[indexesToSelect release];
	
	[self setNeedsDisplayInRect:needsDisplayRect];
	[self setSelectionPath:nil];
}

- (BOOL)isOverSelectedObject:(NSEvent *)theEvent {
	NSPoint currentPoint = [self convertPoint:[theEvent locationInWindow]
									 fromView:nil];
	NSRect cursorRect = NSMakeRect(currentPoint.x - ATOP_SELECTION_RADIUS,
								   currentPoint.y - ATOP_SELECTION_RADIUS,
								   2.0 * ATOP_SELECTION_RADIUS,
								   2.0 * ATOP_SELECTION_RADIUS);
	BOOL result = NO;
	for (id<MWJObjectOnPaper> anObjectOnPaper in [self selectedObjects]) {
		if ([anObjectOnPaper passesThroughRect:cursorRect]) {
			result = YES;
			break;
		}
	}
	return result;
}

- (void)startMovingSelection:(NSEvent *)theEvent {
	[[NSCursor closedHandCursor] push];
	[[self undoManager] beginUndoGrouping];
	previousPoint = [self convertPoint:[theEvent locationInWindow]
							  fromView:nil];
}

- (void)continueMovingSelection:(NSEvent *)theEvent {
	NSPoint newPoint = [self convertPoint:[theEvent locationInWindow]
								 fromView:nil];
	NSAffineTransform *movement = [NSAffineTransform transform];
	[movement translateXBy:(newPoint.x - previousPoint.x)
					   yBy:(newPoint.y - previousPoint.y)];
	previousPoint = newPoint;
	[self undoableApplyTransform:movement
			toObjectsWithIndexes:selectedObjectIndexes
				  withActionName:NSLocalizedString(@"Move",@"")];
}

- (void)endMovingSelection:(NSEvent *)theEvent {
	[[self undoManager] endUndoGrouping];
	[NSCursor pop];
}

#pragma mark -
#pragma mark for Undo/Redo

- (NSUndoManager *)undoManager {
	return [[[self window] delegate] undoManager];
}

- (void)undoableAddObjects:(NSArray *)objectsOnPaperToAdd
				 atIndexes:(NSIndexSet *)indexesToAdd
			withActionName:(NSString *)actionName
{
	[self selectNone];
	if (!objectsOnPaper) {
		objectsOnPaper = [[NSMutableArray alloc] init];
	}
	[objectsOnPaper insertObjects:objectsOnPaperToAdd atIndexes:indexesToAdd];
	NSUndoManager *undoer = [self undoManager];
	[[undoer prepareWithInvocationTarget:self]
	 undoableEraseObjectsAtIndexes:indexesToAdd
	 withActionName:actionName];
	[undoer setActionName:actionName];
	for (id<MWJObjectOnPaper> anObjectOnPaper in objectsOnPaperToAdd) {
		[self setNeedsDisplayInRect:[anObjectOnPaper bounds]];
	}
}

- (void)undoableEraseObjectsAtIndexes:(NSIndexSet *)indexesToErase 
					   withActionName:(NSString *)actionName
{
	[self selectNone];
	if ([indexesToErase count] > 0) {
		NSArray *objectsOnPaperBeingErased = [objectsOnPaper objectsAtIndexes:indexesToErase];
		[objectsOnPaper removeObjectsAtIndexes:indexesToErase];
		NSUndoManager *undoer = [self undoManager];
		[[undoer prepareWithInvocationTarget:self]
		 undoableAddObjects:objectsOnPaperBeingErased
		 atIndexes:indexesToErase
		 withActionName:actionName];
		[undoer setActionName:actionName];
		for (id<MWJObjectOnPaper> anObjectOnPaper in objectsOnPaperBeingErased) {
			[self setNeedsDisplayInRect:[anObjectOnPaper bounds]];
		}
	}
}

- (void)undoableAddObjectOnPaper:(id<MWJObjectOnPaper>)objectToAdd
				  withActionName:(NSString *)actionName
{
	[self undoableAddObjects:[NSArray arrayWithObject:objectToAdd]
				   atIndexes:[NSIndexSet indexSetWithIndex:[objectsOnPaper count]]
			  withActionName:actionName];
}

- (void)eraseObjectsWithIndexes:(NSIndexSet *)indexesToErase {
	[self undoableEraseObjectsAtIndexes:indexesToErase
						 withActionName:NSLocalizedString(@"Erasing",@"")];
}

- (void)undoableApplyTransform:(NSAffineTransform *)theTransform
		  toObjectsWithIndexes:(NSIndexSet *)indexesToTransform
				withActionName:(NSString *)actionName
{
	NSUndoManager *undoer = [self undoManager];
	NSAffineTransform *inverseTransform = [theTransform copy];
	[inverseTransform invert];
	[[undoer prepareWithInvocationTarget:self]
	 undoableApplyTransform:inverseTransform
	 toObjectsWithIndexes:indexesToTransform
	 withActionName:actionName];
	[inverseTransform release];
	[undoer setActionName:actionName];
	NSRect needsDisplayRect = [[objectsOnPaper objectAtIndex:[indexesToTransform firstIndex]] highlightBounds];
	for (id<MWJObjectOnPaper> anObjectOnPaper in [objectsOnPaper objectsAtIndexes:indexesToTransform]) {
		needsDisplayRect = NSUnionRect(needsDisplayRect, [anObjectOnPaper highlightBounds]);
		[anObjectOnPaper transformUsingAffineTransform:theTransform];
		needsDisplayRect = NSUnionRect(needsDisplayRect, [anObjectOnPaper highlightBounds]);
	}
	[self setNeedsDisplayInRect:needsDisplayRect];
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
	if (!workingStroke) {
		[self startStroke:theEvent];
	} else {
		NSPoint newPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
		CGFloat width = [self lineWidthForPressure:[theEvent pressure]
											 start:[workingStroke currentPoint]
											   end:newPoint];
		[workingStroke lineToPoint:newPoint
					 withThickness:width];
		[self setNeedsDisplayInRect:[workingStroke lastSegmentBounds]];
	}
}

- (void)endStroke:(NSEvent *)theEvent {
	[self continueStroke:theEvent];
	[workingStroke release];
	workingStroke = nil;
}

- (void)startStroke:(NSEvent *)theEvent {
	if (!currentPenNib) {
		currentPenNib = [[MWJInkingPenNib defaultTabletPenNib] retain];
	}		
	if (workingStroke) {
		[self continueStroke:theEvent];
	} else {
		workingStroke = [[MWJInkingStroke alloc]
						 initWithPoint:[self convertPoint:[theEvent locationInWindow]
												 fromView:nil]];
		[workingStroke setColor:[currentPenNib inkColor]];
		[self undoableAddObjectOnPaper:workingStroke
						withActionName:NSLocalizedString(@"Inking",@"")];
	}
	initialPressure = [theEvent pressure];
}

#pragma mark -
#pragma mark for erasing objectsOnPaper

- (void)eraseEvent:(NSEvent *)theEvent {
	NSMutableIndexSet *indexesToDelete = [NSMutableIndexSet indexSet];
	NSPoint erasePoint = [self convertPoint:[theEvent locationInWindow]
								   fromView:nil];
	NSRect eraseArea = NSMakeRect(erasePoint.x - ERASER_RADIUS, erasePoint.y - ERASER_RADIUS,
								  2.0 * ERASER_RADIUS, 2.0 * ERASER_RADIUS);
	for (NSUInteger objectIndex = 0; objectIndex < [objectsOnPaper count]; objectIndex++) {
		if ([[objectsOnPaper objectAtIndex:objectIndex] passesThroughRect:eraseArea]) {
			[indexesToDelete addIndex:objectIndex];
		}
	}
	[self eraseObjectsWithIndexes:indexesToDelete];
}

- (IBAction)delete:(id)sender {
	[self undoableEraseObjectsAtIndexes:[self selectedObjectIndexes]
						 withActionName:NSLocalizedString(@"Delete",@"")];
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
	[self setSelectionPath:[NSBezierPath bezierPathWithRect:selectionRect]];
	[self setSelectionByTestingWithSelector:@selector(passesThroughRectValue:)
						withObjectParameter:[NSValue valueWithRect:selectionRect]];
}

- (void)startRectangularSelection:(NSEvent *)theEvent {
	rectangularSelectionOrigin = [self convertPoint:[theEvent locationInWindow]
										   fromView:nil];
}

#pragma mark -
#pragma mark for lasso selection

- (void)continueLasso:(NSEvent *)theEvent {
	if (![self selectionPath]) {
		[self startLasso:theEvent];
	} else {
		[[self selectionPath] lineToPoint:[self convertPoint:[theEvent locationInWindow]
													fromView:nil]];
		[self setNeedsDisplayInRect:[[self selectionPath] boundsWithLines]];
	}
}

- (void)endLasso:(NSEvent *)theEvent {
	[[self selectionPath] lineToPoint:[self convertPoint:[theEvent locationInWindow]
												fromView:nil]];
	[[self selectionPath] closePath];
	[self setSelectionByTestingWithSelector:@selector(passesThroughRegionEnclosedByPath:)
						withObjectParameter:[self selectionPath]];
}

- (void)startLasso:(NSEvent *)theEvent {
	if ([self selectionPath]) {
		[self continueLasso:theEvent];
	} else {
		[self setSelectionPath:[NSBezierPath bezierPath]];
		[[self selectionPath] moveToPoint:[self convertPoint:[theEvent locationInWindow]
													fromView:nil]];
	}
}

#pragma mark -

- (NSRect)pathBounds {
	if ([objectsOnPaper count] > 0) {
		NSRect result = [[objectsOnPaper objectAtIndex:0] bounds];
		for (id<MWJObjectOnPaper> anObjectOnPaper in objectsOnPaper) {
			result = NSUnionRect(result, [anObjectOnPaper bounds]);
		}
		return result;
	} else {
		return NSMakeRect(0.0, 0.0, 0.0, 0.0);
	}
}

#pragma mark -
#pragma mark for saving and loading

- (NSData *)data {
	return [NSKeyedArchiver archivedDataWithRootObject:[NSArray arrayWithArray:objectsOnPaper]];
}

- (void)loadFromData:(NSData *)data {
	[objectsOnPaper release];
	NSArray *loadedArray = [NSKeyedUnarchiver unarchiveObjectWithData:data];
	objectsOnPaper = [[NSMutableArray alloc] initWithArray:loadedArray];
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

- (NSData *)selectedPDFData {
	NSArray *selectedObjects = [self selectedObjects];
	MWJPaperView *temporaryView = [[MWJPaperView alloc] initWithFrame:[self frame]];
	[temporaryView undoableAddObjects:selectedObjects
							atIndexes:[NSIndexSet indexSetWithIndexesInRange:
									   NSMakeRange(0, [selectedObjects count])]
					   withActionName:@""];
	NSData *thePDFData = [temporaryView dataWithPDFInsideRect:[temporaryView pathBounds]];
	[temporaryView release];
	return thePDFData;
}


#pragma mark -
#pragma mark cut/copy/paste

- (IBAction)cut:(id)sender {
	[self copy:sender];
	[self undoableEraseObjectsAtIndexes:[self selectedObjectIndexes]
						 withActionName:NSLocalizedString(@"Cut",@"")];
}

- (IBAction)copy:(id)sender {
	NSPasteboard *pb = [NSPasteboard generalPasteboard];
	[pb declareTypes:[NSArray arrayWithObjects:
					  kMWJPaperViewObjectsOnPaperPboardType,
					  NSPDFPboardType, NSTIFFPboardType,
					  nil] owner:nil];
	
	// add internal format (kMWJPaperViewObjectsOnPaperPboardType)
	[pb setData:[NSKeyedArchiver archivedDataWithRootObject:[self selectedObjects]]
		forType:kMWJPaperViewObjectsOnPaperPboardType];
	
	// add PDF
	NSData *PDFData = [self selectedPDFData];
	[pb setData:PDFData
		forType:NSPDFPboardType];
	
	// add TIFF
	NSImage *image = [[NSImage alloc] initWithData:PDFData];
	NSSize imageSize = [image size];
	imageSize.width = imageSize.width * COPY_AS_IMAGE_SCALE_FACTOR;
	imageSize.height = imageSize.height * COPY_AS_IMAGE_SCALE_FACTOR;
	[image setSize:imageSize];
	[pb setData:[image TIFFRepresentation]
		forType:NSTIFFPboardType];
	[image release];
}

- (IBAction)paste:(id)sender {
	NSPasteboard *pb = [NSPasteboard generalPasteboard];
	if ([[pb types] containsObject:kMWJPaperViewObjectsOnPaperPboardType]) {
		NSArray *pastedObjects = [NSKeyedUnarchiver unarchiveObjectWithData:
								  [pb dataForType:kMWJPaperViewObjectsOnPaperPboardType]];
		NSIndexSet *pastedIndexes = [NSIndexSet indexSetWithIndexesInRange:
									 NSMakeRange([objectsOnPaper count], [pastedObjects count])];
		[self undoableAddObjects:pastedObjects
					   atIndexes:pastedIndexes
				  withActionName:NSLocalizedString(@"Paste",@"")];
		[self setSelectedObjectIndexes:pastedIndexes];
		[self setNeedsDisplay:YES];
	} else {
		NSString *imageType = [pb availableTypeFromArray:[NSArray arrayWithObjects:
														  NSPDFPboardType,
														  NSPostScriptPboardType,
														  NSTIFFPboardType,
														  NSPICTPboardType,
														  nil]];
		if (imageType) {
			MWJPastedImage *pastedImage = [[MWJPastedImage alloc]
										   initWithData:[pb dataForType:imageType]
										   inFrame:NSZeroRect];
			[self undoableAddObjectOnPaper:pastedImage
							withActionName:NSLocalizedString(@"Paste",@"")];
			[self setSelectedObjectIndexes:[NSIndexSet indexSetWithIndex:([objectsOnPaper count] - 1)]];
			[self setNeedsDisplay:YES];
		}
	}
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
	timeOfLastTabletEvent = [theEvent timestamp];
}

- (void)tabletPoint:(NSEvent *)theEvent {
	timeOfLastTabletEvent = [theEvent timestamp];
}

- (void)mouseDown:(NSEvent *)theEvent {
	if ([NSCursor currentCursor] == [NSCursor openHandCursor]) {
		[self startMovingSelection:theEvent];
	} else {
		if ([[self selectedObjectIndexes] count] > 0) {
			// if there's a selection, wipe it out and redraw everything
			[self selectNone];
		}
		
		if ([theEvent subtype] == NSTabletPointEventSubtype) {
			if (pointingDeviceType == NSPenPointingDevice) {
				if ([self toolType] == kMWJPaperViewPenToolType) {
					[self startStroke:theEvent];
				} else if ([self toolType] == kMWJPaperViewRectangularMarqueeToolType) {
					[self startRectangularSelection:theEvent];
				} else if ([self toolType] == kMWJPaperViewLassoToolType) {
					[self startLasso:theEvent];
				}
			}
			[self tabletPoint:theEvent];
		} else if ([theEvent subtype] == NSTabletProximityEventSubtype) {
			[self tabletProximity:theEvent];
		} else if ([theEvent subtype] == NSMouseEventSubtype) {
			if ([theEvent timestamp] - timeOfLastTabletEvent > TABLET_MOUSE_TIME_MARGIN) {
				[self startRectangularSelection:theEvent];
			}
		}
	}
}

- (void)mouseDragged:(NSEvent *)theEvent {
	if ([NSCursor currentCursor] == [NSCursor closedHandCursor]) {
		[self continueMovingSelection:theEvent];
	} else if ([theEvent subtype] == NSTabletPointEventSubtype) {
		if (pointingDeviceType == NSPenPointingDevice) {
			if ([self toolType] == kMWJPaperViewPenToolType) {
				[self continueStroke:theEvent];
			} else if ([self toolType] == kMWJPaperViewEraserToolType) {
				[self eraseEvent:theEvent];
			} else if ([self toolType] == kMWJPaperViewRectangularMarqueeToolType) {
				[self continueRectangularSelection:theEvent];
			} else if ([self toolType] == kMWJPaperViewLassoToolType) {
				[self continueLasso:theEvent];
			}
		} else if (pointingDeviceType == NSEraserPointingDevice) {
			[self eraseEvent:theEvent];
		}
		[self tabletPoint:theEvent];
	} else if ([theEvent subtype] == NSTabletProximityEventSubtype) {
		[self tabletProximity:theEvent];
	} else if ([theEvent subtype] == NSMouseEventSubtype) {
		if ([theEvent timestamp] - timeOfLastTabletEvent > TABLET_MOUSE_TIME_MARGIN) {
			[self continueRectangularSelection:theEvent];
		}
	}
}

- (void)mouseUp:(NSEvent *)theEvent {
	if ([NSCursor currentCursor] == [NSCursor closedHandCursor]) {
		[self endMovingSelection:theEvent];
	} else if ([theEvent subtype] == NSTabletPointEventSubtype) {
		if (pointingDeviceType == NSPenPointingDevice) {
			if ([self toolType] == kMWJPaperViewPenToolType) {
				[self endStroke:theEvent];
			} else if ([self toolType] == kMWJPaperViewRectangularMarqueeToolType) {
				[self endRectangularSelection:theEvent];
			} else if ([self toolType] == kMWJPaperViewLassoToolType) {
				[self endLasso:theEvent];
			}
		}
		[self tabletPoint:theEvent];
	} else if ([theEvent subtype] == NSTabletProximityEventSubtype) {
		[self tabletProximity:theEvent];
	} else if ([theEvent subtype] == NSMouseEventSubtype) {
		if ([theEvent timestamp] - timeOfLastTabletEvent > TABLET_MOUSE_TIME_MARGIN) {
			[self endRectangularSelection:theEvent];
		}
	}
}

- (void)mouseMoved:(NSEvent *)theEvent {
	BOOL isTabletPossibleMovingCursor = (([theEvent subtype] == NSTabletPointEventSubtype)
										 && (([self toolType] == kMWJPaperViewRectangularMarqueeToolType)
											 || ([self toolType] == kMWJPaperViewLassoToolType)));
	BOOL isMousePossibleMovingCursor = ([theEvent subtype] == NSMouseEventSubtype);
	if ((isTabletPossibleMovingCursor || isMousePossibleMovingCursor)
		&& [self isOverSelectedObject:theEvent]) {
		if ([NSCursor currentCursor] != [NSCursor openHandCursor]) {
			[[NSCursor openHandCursor] push];
		}
	} else if ([NSCursor currentCursor] == [NSCursor openHandCursor]) {
		[NSCursor pop];
	} else {
	}
}




@end
