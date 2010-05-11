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
//  MWJPaperView.h
//  MacWJ
//

#import <Cocoa/Cocoa.h>

@class MWJInkingStroke;
@class MWJInkingPenNib;

typedef enum {
	kMWJPaperViewPenToolType,
	kMWJPaperViewEraserToolType,
	kMWJPaperViewRectangularMarqueeToolType,
	kMWJPaperViewLassoToolType,
	kMWJPaperViewAddRemoveSpaceToolType,
} MWJPaperViewToolType;


@interface MWJPaperView : NSView {
	MWJInkingPenNib *currentPenNib;
	MWJPaperViewToolType toolType;
	MWJPaperViewToolType mouseToolType;
	
	@private
	NSMutableArray *objectsOnPaper;
	MWJInkingStroke *workingStroke;
	CGFloat initialPressure;
	NSPointingDeviceType pointingDeviceType;
	NSIndexSet *selectedObjectIndexes;
	NSPoint rectangularSelectionOrigin;
	NSBezierPath *selectionPath;
	NSPoint previousPoint;
	NSTimeInterval timeOfLastTabletEvent;
	NSPoint continuousActionInitialPoint;
	BOOL isAddRemoveSpace;
}

@property (retain) MWJInkingPenNib *currentPenNib;
@property MWJPaperViewToolType toolType;
@property MWJPaperViewToolType mouseToolType;

@property (retain) NSIndexSet *selectedObjectIndexes;
@property (retain) NSBezierPath *selectionPath;

- (IBAction)cut:(id)sender;
- (IBAction)copy:(id)sender;
- (IBAction)paste:(id)sender;

- (IBAction)bringToFront:(id)sender;
- (IBAction)bringForward:(id)sender;
- (IBAction)sendBackward:(id)sender;
- (IBAction)sendToBack:(id)sender;

- (NSRect)boundsOfObjects;

- (NSData *)data;
- (void)loadFromData:(NSData *)data;

- (NSData *)PNGData;
- (NSData *)PDFData;

@end
