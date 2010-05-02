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
//  tabletInkStroke.h
//  MacWJ
//

#import <Cocoa/Cocoa.h>

@class tabletPenNib;

@interface tabletInkStroke : NSObject {
	NSColor *color;
	
	@private
	NSMutableArray *paths;
	NSPoint currentPoint;
}

@property (retain) NSColor *color;
@property (readonly) NSPoint currentPoint;

- (id)initWithPoint:(NSPoint)startingPoint;
- (void)lineToPoint:(NSPoint)endPoint
	  withThickness:(CGFloat)lineWidth;
- (NSRect)bounds;
- (NSRect)lastSegmentBounds;
- (void)strokeInRect:(NSRect)dirtyRect
		   withRects:(const NSRect *)dirtyRects
			   count:(NSInteger)dirtyRectsCount;
- (BOOL)passesThroughRect:(NSRect)rect;

- (NSImage *)imageFromStroke;

@end
