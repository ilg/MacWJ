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
//  MWJObjectOnPaperParentClass.m
//  MacWJ
//

#import "MWJObjectOnPaperParentClass.h"
#import "MWJObjectOnPaper.h"
#import "NSBezierPath+highlightedStroke.h"
#import "NSBezierPath+overlapsRect.h"


@implementation MWJObjectOnPaperParentClass

@synthesize frame;

#pragma mark -
#pragma mark partial implementation of the MWJObjectOnPaper protocol

- (NSRect)bounds {
	return [self frame];
}

- (NSRect)highlightBounds {
	return [[NSBezierPath bezierPathWithRect:[self frame]] highlightedStrokeBounds];
}

- (void)drawWithHighlightInRect:(NSRect)dirtyRect
					  withRects:(const NSRect *)dirtyRects
						  count:(NSInteger)dirtyRectsCount
{
	[[NSBezierPath bezierPathWithRect:[self frame]] highlightedStroke];
	if ([self respondsToSelector:@selector(drawInRect:withRects:count:)]) {
		[(id<MWJObjectOnPaper>)self drawInRect:dirtyRect
									 withRects:dirtyRects
										 count:dirtyRectsCount];
	}
}

- (BOOL)passesThroughRect:(NSRect)rect {
	// NOTE: CGRectIntersectsRect behaves better than NSIntersectsRect when width or height is zero
	return CGRectIntersectsRect(NSRectToCGRect(rect), NSRectToCGRect([self frame]));
}

- (BOOL)passesThroughRectValue:(NSValue *)rectValue {
	return [self passesThroughRect:[rectValue rectValue]];
}

- (BOOL)passesThroughRegionEnclosedByPath:(NSBezierPath *)path {
	return [path overlapsRect:[self frame]];
}

- (BOOL)isBelow:(CGFloat)selectionBoundary {
	BOOL result = ([self bounds].origin.y > selectionBoundary);
	return result;
}

- (BOOL)isBelowNumber:(NSNumber *)selectionBoundaryNumber {
	return [self isBelow:[selectionBoundaryNumber floatValue]];
}

- (BOOL)isResizable {
	return NO;
}

- (BOOL)isResizableAt:(NSPoint)cursorPoint {
	if (![self isResizable]) {
		return NO;
	} else {
		CGFloat w = 3.0;
		CGPoint pt = NSPointToCGPoint(cursorPoint);
		CGRect f = NSRectToCGRect([self frame]);
		return (CGRectContainsPoint(CGRectMake(CGRectGetMinX(f), CGRectGetMinY(f), w, w), pt)
//				|| CGRectContainsPoint(CGRectMake(CGRectGetMaxX(f) - w, CGRectGetMinY(f), w, w), pt)
//				|| CGRectContainsPoint(CGRectMake(CGRectGetMinX(f), CGRectGetMaxY(f) - w, w, w), pt)
				|| CGRectContainsPoint(CGRectMake(CGRectGetMaxX(f) - w, CGRectGetMaxY(f) - w, w, w), pt)
				);
	}
}

- (void)transformUsingAffineTransform:(NSAffineTransform *)aTransform {
	NSRect ourFrame = [self frame];
	ourFrame.origin = [aTransform transformPoint:ourFrame.origin];
	ourFrame.size = [aTransform transformSize:ourFrame.size];
	[self setFrame:ourFrame];
}

@end
