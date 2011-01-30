/*********************************************************************************
 
 © Copyright 2010-2011, Isaac Greenspan
 
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
//  NSBezierPath+highlightedStroke.m
//  MacWJ
//

#import "NSBezierPath+highlightedStroke.h"
#import "NSBezierPath+boundsWithLines.h"

#define HIGHLIGHT_WIDTH 1.5

@implementation NSBezierPath (highlightedStroke)

- (void)highlightedStroke {
	NSBezierPath *highlightPath = [self copy];
	[highlightPath setLineWidth:([self lineWidth] + 2.0 * HIGHLIGHT_WIDTH)];
	
	// Save the current graphics state first so we can restore it.
	[[NSGraphicsContext currentContext] saveGraphicsState];
	
	[[NSColor selectedTextBackgroundColor] setStroke];
	[highlightPath stroke];
	
	// Restore the original graphics state.
	[[NSGraphicsContext currentContext] restoreGraphicsState];
	
	[highlightPath release];
}

- (NSRect)highlightedStrokeBounds {
	NSBezierPath *highlightPath = [self copy];
	[highlightPath setLineWidth:([self lineWidth] + 2.0 * HIGHLIGHT_WIDTH)];
	NSRect bounds = [highlightPath boundsWithLines];
	[highlightPath release];
	return bounds;
}

@end
