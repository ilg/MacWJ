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
//  NSBezierPath+isInRect_withRects_count_.m
//  MacWJ
//

#import "NSBezierPath+isInRect_withRects_count_.h"
#import "NSBezierPath+boundsWithLines.h"

@implementation NSBezierPath (isInRect_withRects_count_)

- (BOOL)isInRect:(NSRect)dirtyRect
	   withRects:(const NSRect *)dirtyRects
		   count:(NSInteger)dirtyRectsCount
{
	BOOL result = NO;
	NSInteger i;
	CGRect pathBounds = NSRectToCGRect([self boundsWithLines]);
	// NOTE: CGRectIntersectsRect behaves better than NSIntersectsRect when width or height is zero
	if (CGRectIntersectsRect(pathBounds,NSRectToCGRect(dirtyRect))) {
		// Then test per dirty rect
		for (i = 0; i < dirtyRectsCount; i++) {
			if (CGRectIntersectsRect(pathBounds,NSRectToCGRect(dirtyRects[i]))) {
				result = YES;
				break;
			}
		}
	}
	return result;
}

@end
