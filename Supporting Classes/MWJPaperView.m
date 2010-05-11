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
#import "MWJPastedText.h"

#define ERASER_RADIUS [[NSUserDefaults standardUserDefaults] floatForKey:@"eraserRadius"]
#define ATOP_SELECTION_RADIUS 1.0
#define COPY_AS_IMAGE_SCALE_FACTOR [[NSUserDefaults standardUserDefaults] floatForKey:@"copyAsImageScaleFactor"]
#define TABLET_MOUSE_TIME_MARGIN 0.5

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
- (void)undoableMoveObjectsAtIndexes:(NSIndexSet *)indexesToMove
						   toIndexes:(NSIndexSet *)destinationIndexes
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

#define INTERNAL_PBOARD_TYPE_ARRAY [NSArray arrayWithObject:kMWJPaperViewObjectsOnPaperPboardType]
#define IMAGE_PBOARD_TYPE_ARRAY [NSArray arrayWithObjects:NSPDFPboardType,NSPostScriptPboardType,NSTIFFPboardType,NSPICTPboardType,nil]
#define TEXT_PBOARD_TYPE_ARRAY [NSArray arrayWithObjects:NSRTFPboardType,NSRTFDPboardType,NSHTMLPboardType,NSStringPboardType,nil]
#define NONFILE_PBOARD_TYPE_ARRAY [INTERNAL_PBOARD_TYPE_ARRAY arrayByAddingObjectsFromArray:[IMAGE_PBOARD_TYPE_ARRAY arrayByAddingObjectsFromArray:TEXT_PBOARD_TYPE_ARRAY]]

@implementation MWJPaperView

static NSCursor *penCursor;
static NSCursor *eraserCursor;

@synthesize currentPenNib,toolType,mouseToolType;

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
		[self setMouseToolType:kMWJPaperViewRectangularMarqueeToolType];
		
		[self setSelectedObjectIndexes:[NSIndexSet indexSet]];
		[self setSelectionPath:nil];
		[self registerForDraggedTypes:[NONFILE_PBOARD_TYPE_ARRAY arrayByAddingObject:NSFilenamesPboardType]];
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
	[self setNeedsDisplayInRect:[[self selectionPath] boundsWithLines]];
	
	NSMutableIndexSet *indexesToSelect = [[NSMutableIndexSet alloc] init];
	NSUInteger objectIndex = 0;
	for (id<MWJObjectOnPaper> anObjectOnPaper in objectsOnPaper) {
		if ([anObjectOnPaper performSelector:testingSelector
								  withObject:testingArgument]) {
			[indexesToSelect addIndex:objectIndex];
			[self setNeedsDisplayInRect:[anObjectOnPaper highlightBounds]];
		}
		objectIndex++;
	}
	[self setSelectedObjectIndexes:[[[NSIndexSet alloc] initWithIndexSet:indexesToSelect] autorelease]];
	[indexesToSelect release];
	
	[self setSelectionPath:nil];
}

- (void)selectBelow:(CGFloat)selectionBoundary {
	[self setSelectionByTestingWithSelector:@selector(isBelowNumber:)
						withObjectParameter:[NSNumber numberWithFloat:selectionBoundary]];
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
	for (id<MWJObjectOnPaper> anObjectOnPaper in [objectsOnPaper objectsAtIndexes:indexesToTransform]) {
		[self setNeedsDisplayInRect:[anObjectOnPaper highlightBounds]];
		[anObjectOnPaper transformUsingAffineTransform:theTransform];
		[self setNeedsDisplayInRect:[anObjectOnPaper highlightBounds]];
	}
}

- (void)undoableMoveObjectsAtIndexes:(NSIndexSet *)indexesToMove
						   toIndexes:(NSIndexSet *)destinationIndexes
					  withActionName:(NSString *)actionName
{
	NSArray *objectsToMove = [objectsOnPaper objectsAtIndexes:indexesToMove];
	[objectsOnPaper removeObjectsAtIndexes:indexesToMove];
	[objectsOnPaper insertObjects:objectsToMove
						atIndexes:destinationIndexes];
	NSUndoManager *undoer = [self undoManager];
	[[undoer prepareWithInvocationTarget:self]
	 undoableMoveObjectsAtIndexes:destinationIndexes
	 toIndexes:indexesToMove
	 withActionName:actionName];
	[undoer setActionName:actionName];
	for (id<MWJObjectOnPaper> anObjectOnPaper in objectsToMove) {
		[self setNeedsDisplayInRect:[anObjectOnPaper highlightBounds]];
	}
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
#pragma mark for add/remove space tool

- (void)continueAddRemoveSpace:(NSEvent *)theEvent {
}

- (void)endAddRemoveSpace:(NSEvent *)theEvent {
}

- (void)startAddRemoveSpace:(NSEvent *)theEvent {
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
	[NSKeyedUnarchiver setClass:[MWJInkingStroke class] forClassName:@"tabletInkStroke"];
	objectsOnPaper = [[NSMutableArray alloc]
					  initWithArray:[NSKeyedUnarchiver
									 unarchiveObjectWithData:data]];
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

- (void)pasteFromPasteboard:(NSPasteboard *)pb {
	if ([[pb types] containsObject:kMWJPaperViewObjectsOnPaperPboardType]) {
		// handle our own internal pasteboard format first
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
		NSPoint centerPoint;
		centerPoint.x = [self bounds].size.width / 2.0;
		centerPoint.y = [self bounds].size.height / 2.0;
		// not our own, so maybe an image we can paste in?
		NSString *imageType = [pb availableTypeFromArray:IMAGE_PBOARD_TYPE_ARRAY];
		if (imageType) {
			MWJPastedImage *pastedImage = [[MWJPastedImage alloc]
										   initWithData:[pb dataForType:imageType]
										   centeredOn:centerPoint];
			[self undoableAddObjectOnPaper:pastedImage
							withActionName:NSLocalizedString(@"Paste",@"")];
			[self setSelectedObjectIndexes:[NSIndexSet indexSetWithIndex:([objectsOnPaper count] - 1)]];
			[self setNeedsDisplay:YES];
		} else {
			// not an image either, so maybe text we can paste in?
			NSString *textType = [pb availableTypeFromArray:TEXT_PBOARD_TYPE_ARRAY];
			if (textType) {
				MWJPastedText *pastedText = [[MWJPastedText alloc]
											 initWithData:[pb dataForType:textType]
											 centeredOn:centerPoint];
				if (pastedText) {
					[self undoableAddObjectOnPaper:pastedText
									withActionName:NSLocalizedString(@"Paste",@"")];
					[self setSelectedObjectIndexes:[NSIndexSet indexSetWithIndex:([objectsOnPaper count] - 1)]];
					[self setNeedsDisplay:YES];
				}
			}
		}
	}
}

- (IBAction)paste:(id)sender {
	[self pasteFromPasteboard:[NSPasteboard generalPasteboard]];
}

#pragma mark -
#pragma mark stuff for receiving drag and drop

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
	NSPasteboard *pb = [sender draggingPasteboard];
	if ([pb availableTypeFromArray:NONFILE_PBOARD_TYPE_ARRAY]) {
		return NSDragOperationCopy;
	} else if ([[pb types] containsObject:NSFilenamesPboardType]) {
		return NSDragOperationGeneric;
	} else {
		return NSDragOperationNone;
	}
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
	NSPasteboard *pb = [sender draggingPasteboard];
	if ([pb availableTypeFromArray:NONFILE_PBOARD_TYPE_ARRAY]) {
		[self pasteFromPasteboard:pb];
		return YES;
	} else if ([[pb types] containsObject:NSFilenamesPboardType]) {
		NSMutableDictionary *filesToInsert = [[NSMutableDictionary alloc] init];
		for (NSString *aFile in [pb propertyListForType:NSFilenamesPboardType]) {
			NSString *fileType = [[NSWorkspace sharedWorkspace] typeOfFile:aFile
																	 error:NULL];
			if ([[NSImage imageTypes] containsObject:fileType]) {
				[filesToInsert setObject:NSStringFromClass([NSImage class])
								  forKey:aFile];
			} else if ([[NSAttributedString textTypes] containsObject:fileType]) {
				[filesToInsert setObject:NSStringFromClass([NSAttributedString class])
								  forKey:aFile];
			}
		}
		if ([filesToInsert count] > 0) {
			NSUInteger previousObjectCount = [objectsOnPaper count];
			
			// take measurements to cascade the inserted objects
			NSRect spaceRect = [self visibleRect];
			CGFloat xStep = spaceRect.size.width / ([filesToInsert count] + 2);
			CGFloat yStep = spaceRect.size.height / ([filesToInsert count] + 2);
			
			NSUInteger fileIndex = 0;
			for (NSString *aFile in filesToInsert) {
				NSPoint targetPoint = NSMakePoint(spaceRect.origin.x + (fileIndex + 2) * xStep,
												  spaceRect.origin.y + (fileIndex + 2) * yStep);
				id<MWJObjectOnPaper> insertedObject = nil;
				if ([[filesToInsert objectForKey:aFile]
					 isEqualToString:NSStringFromClass([NSImage class])]) {
					insertedObject = [[MWJPastedImage alloc]
									  initWithData:[NSData dataWithContentsOfFile:aFile]
									  centeredOn:targetPoint];
				} else if ([[filesToInsert objectForKey:aFile]
							isEqualToString:NSStringFromClass([NSAttributedString class])]) {
					insertedObject = [[MWJPastedText alloc]
									  initWithData:[NSData dataWithContentsOfFile:aFile]
									  centeredOn:targetPoint];
				}
				
				if (insertedObject) [self undoableAddObjectOnPaper:insertedObject
													withActionName:NSLocalizedString(@"Insert",@"")];
				fileIndex++;
			}
			[self setSelectedObjectIndexes:[NSIndexSet indexSetWithIndexesInRange:
											NSMakeRange(previousObjectCount,
														[objectsOnPaper count] - previousObjectCount)]];
			[self setNeedsDisplay:YES];
			[filesToInsert release];
			return YES;
		} else {
			[filesToInsert release];
			return NO;
		}
	} else {
		return NO;
	}
}

#pragma mark -
#pragma mark object arrangement (move forward/backward)

- (IBAction)bringToFront:(id)sender {
	NSIndexSet *selectedIndexes = [self selectedObjectIndexes];
	NSIndexSet *destinationIndexes = [NSIndexSet indexSetWithIndexesInRange:
									  NSMakeRange([objectsOnPaper count] - [selectedIndexes count],
												  [selectedIndexes count])];
	if (![selectedIndexes isEqualToIndexSet:destinationIndexes]) {
		[self undoableMoveObjectsAtIndexes:selectedIndexes
								 toIndexes:destinationIndexes
							withActionName:@"Bring to Front"];
		[self setSelectedObjectIndexes:destinationIndexes];
	}
}

- (IBAction)bringForward:(id)sender {
	NSMutableIndexSet *indexesToMove = [[NSMutableIndexSet alloc]
										initWithIndexSet:[self selectedObjectIndexes]];
	NSMutableIndexSet *unchangedIndexes = [[NSMutableIndexSet alloc] init];

	// remove the indexes of objects that are already at the front
	for (NSUInteger objectIndex = [objectsOnPaper count] - 1; objectIndex >= 0; objectIndex--) {
		if (([indexesToMove count] > 0)
			&& ([indexesToMove containsIndex:objectIndex])) {
			[indexesToMove removeIndex:objectIndex];
			[unchangedIndexes addIndex:objectIndex];
		} else {
			break;
		}
	}
	
	if ([indexesToMove count] > 0) {
		// the destination indexes corresponding to those indexesToMove that weren't already at the front
		// are all <= objectIndex and need to be decremented by 1
		NSMutableIndexSet *destinationIndexes = [indexesToMove mutableCopy];
		[destinationIndexes shiftIndexesStartingAtIndex:0
													 by:1];
		
		// do the rearrangement
		[self undoableMoveObjectsAtIndexes:indexesToMove
								 toIndexes:destinationIndexes
							withActionName:@"Bring Forward"];
		
		// reset the selection
		[destinationIndexes addIndexes:unchangedIndexes];
		[self setSelectedObjectIndexes:destinationIndexes];
		
		[destinationIndexes release];
	}
	[indexesToMove release];
	[unchangedIndexes release];
}

- (IBAction)sendBackward:(id)sender {
	NSMutableIndexSet *indexesToMove = [[NSMutableIndexSet alloc]
										initWithIndexSet:[self selectedObjectIndexes]];
	NSMutableIndexSet *unchangedIndexes = [[NSMutableIndexSet alloc] init];

	// remove the indexes of objects that are already at the back
	NSUInteger objectIndex;
	for (objectIndex = 0; objectIndex < [objectsOnPaper count]; objectIndex++) {
		if (([indexesToMove count] > 0)
			&& ([indexesToMove containsIndex:objectIndex])) {
			[indexesToMove removeIndex:objectIndex];
			[unchangedIndexes addIndex:objectIndex];
		} else {
			break;
		}
	}
	
	if ([indexesToMove count] > 0) {
		// the destination indexes corresponding to those indexesToMove that weren't already at the back
		// are all >= objectIndex and need to be decremented by 1
		NSMutableIndexSet *destinationIndexes = [indexesToMove mutableCopy];
		[destinationIndexes shiftIndexesStartingAtIndex:objectIndex
													 by:-1];
		
		// do the rearrangement
		[self undoableMoveObjectsAtIndexes:indexesToMove
								 toIndexes:destinationIndexes
							withActionName:@"Send Backward"];
		
		// reset the selection
		[destinationIndexes addIndexes:unchangedIndexes];
		[self setSelectedObjectIndexes:destinationIndexes];
		[destinationIndexes release];
	}
	[indexesToMove release];
	[unchangedIndexes release];
}

- (IBAction)sendToBack:(id)sender {
	NSIndexSet *selectedIndexes = [self selectedObjectIndexes];
	NSIndexSet *destinationIndexes = [NSIndexSet indexSetWithIndexesInRange:
									  NSMakeRange(0,[selectedIndexes count])];
	if (![selectedIndexes isEqualToIndexSet:destinationIndexes]) {
		[self undoableMoveObjectsAtIndexes:selectedIndexes
								 toIndexes:destinationIndexes
							withActionName:@"Send to Back"];
		[self setSelectedObjectIndexes:destinationIndexes];
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

- (void)mouseEvent:(NSEvent *)theEvent {
	NSEventType eventType = [theEvent type];
	short eventSubtype = [theEvent subtype];
	
	if (([NSCursor currentCursor] == [NSCursor openHandCursor])
		&& (eventType == NSLeftMouseDown)) {
		// if the cursor is an open hand, then a mousedown is the start of a drag-move
		[self startMovingSelection:theEvent];
		
	} else if ([NSCursor currentCursor] == [NSCursor closedHandCursor]) {
		// if the cursor is a closed hand, then we are in a drag-move
		if (eventType == NSLeftMouseDragged) {
			// dragging continues
			[self continueMovingSelection:theEvent];
		} else if (eventType == NSLeftMouseUp) {
			// mouseUp ends the drag
			[self endMovingSelection:theEvent];
		}
		
	} else if (eventSubtype == NSTabletProximityEventSubtype) {
		// catch all tablet-proximity events
		[self tabletProximity:theEvent];
		
	} else if ((eventType == NSLeftMouseDragged)
			   && (eventSubtype == NSTabletPointEventSubtype)
			   && ((pointingDeviceType == NSEraserPointingDevice)
				   || ((pointingDeviceType == NSPenPointingDevice)
					   && ([self toolType] == kMWJPaperViewEraserToolType)
					   )
				   )
			   ) {
		// a drag event with the tablet device
		// and either the eraser end of it or the pen end with the eraser tool
		// is an erase event
		[self eraseEvent:theEvent];
		
	} else {
		// now that we aren't in one of the above special cases...
		if ((eventType == NSLeftMouseDown)
			&& ([[self selectedObjectIndexes] count] > 0)) {
			// if there's a selection, mouseDown wipes it out and redraws everything
			[self selectNone];
		}
		
		// figure out whether we're start/continue/end and which group of methods
		NSString *selectorPrefix = nil;
		NSString *selectorGroup = nil;
		
		switch (eventType) {
			case NSLeftMouseDown: selectorPrefix = @"start"; break;
			case NSLeftMouseDragged: selectorPrefix = @"continue"; break;
			case NSLeftMouseUp: selectorPrefix = @"end"; break;
		}
		
		if ((eventSubtype == NSMouseEventSubtype)
			|| (pointingDeviceType == NSPenPointingDevice)) {
			switch ((eventSubtype == NSTabletPointEventSubtype)
					? [self toolType]
					: [self mouseToolType]
					) {
				case kMWJPaperViewPenToolType:
					selectorGroup = @"Stroke"; break;
				case kMWJPaperViewRectangularMarqueeToolType:
					selectorGroup = @"RectangularSelection"; break;
				case kMWJPaperViewLassoToolType:
					selectorGroup = @"Lasso"; break;
				case kMWJPaperViewAddRemoveSpaceToolType:
					selectorGroup = @"AddRemoveSpace"; break;
			}
		}
		
		// if we've set a prefix and a group, then call the proper method
		if (selectorPrefix && selectorGroup) {
			[self performSelector:NSSelectorFromString([NSString stringWithFormat:@"%@%@:",
														selectorPrefix,selectorGroup])
					   withObject:theEvent];
		}
		
		// catch all tablet-point events
		if (eventSubtype == NSTabletPointEventSubtype) [self tabletPoint:theEvent];
	}
}

- (void)mouseDown:(NSEvent *)theEvent {
	[self mouseEvent:theEvent];
}

- (void)mouseDragged:(NSEvent *)theEvent {
	[self mouseEvent:theEvent];
}

- (void)mouseUp:(NSEvent *)theEvent {
	[self mouseEvent:theEvent];
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
