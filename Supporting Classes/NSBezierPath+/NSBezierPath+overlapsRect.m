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
//  NSBezierPath+overlapsRect.m
//  MacWJ
//

#import "NSBezierPath+overlapsRect.h"

@implementation NSBezierPath (overlapsRect)

- (BOOL)overlapsRect:(NSRect)rect {
	CGRect rectCG = NSRectToCGRect(rect);
	if (!CGRectIntersectsRect(rectCG, NSRectToCGRect([self bounds]))) {
		// (1) if our bounds don't overlap the rect, then we don't.
		return NO;
		
	} else if ([self containsPoint:rect.origin]
			   || [self containsPoint:NSMakePoint(rect.origin.x,
												  rect.origin.y + rect.size.height)]
			   || [self containsPoint:NSMakePoint(rect.origin.x + rect.size.width,
												  rect.origin.y)]
			   || [self containsPoint:NSMakePoint(rect.origin.x + rect.size.width,
												  rect.origin.y + rect.size.height)]
			   ) {
		// (2) if any of the four corners of the rect are inside our curve, then we overlap
		return YES;
		
	} else {
		// (3) flatten the path and see if any endpoints of what's drawn lie inside the rect
		//     (if an endpoint of a segment of ours is in the rect, then there is overlap)
		BOOL anEndpointInsideRect = NO;
		
		NSBezierPath *flattenedPath = [self bezierPathByFlatteningPath];
		
		NSPoint *points = malloc(3*sizeof(NSPoint));
		NSBezierPathElement pathElementType;
		
		for (NSInteger pathElementIndex = 0;
			 pathElementIndex < [flattenedPath elementCount];
			 pathElementIndex++) {
			pathElementType = [flattenedPath elementAtIndex:pathElementIndex
								  associatedPoints:points];
			switch (pathElementType) {
				case NSMoveToBezierPathElement:
					if (NSPointInRect(points[0], rect)
						&& (pathElementIndex + 1 < [flattenedPath elementCount])
						&& ([flattenedPath elementAtIndex:(pathElementIndex + 1)]
							!= NSMoveToBezierPathElement)) {
						// if the point we just moved to is inside rect, is not the last point,
						// and is not followed by another move, then we overlap for sure.
						anEndpointInsideRect = YES;
					}
					break;
				case NSLineToBezierPathElement:
					if (NSPointInRect(points[0], rect)) {
						// if the point we just drew a line to is inside rect, then we overlap for sure.
						anEndpointInsideRect = YES;
					}
					break;
				case NSCurveToBezierPathElement:
					if (NSPointInRect(points[2], rect)) {
						// if the point we just drew a curve to is inside rect, then we overlap for sure.
						anEndpointInsideRect = YES;
					}
					break;
				case NSClosePathBezierPathElement:
					break;
				default:
					break;
			}
			if (anEndpointInsideRect) break;
		}
		free(points);
		
		if (anEndpointInsideRect) {
			// confirmed overlap because an endpoint of the flattened version of ourself is inside the rect
			return YES;
			
		} else {
			// all endpoints of the flattened version of ourself are outside the rect,
			// but our bounds intersect the rect...
			
			// (4) this is not a definitive result, but it's unlikely that there is overlap...
			// ..... so return NO.
			return NO;
			// TODO: implement finer-grained algorithm here?
		}
	}
}

@end
