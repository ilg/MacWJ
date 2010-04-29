//
//  NSBezierPath+boundsWithLines.m
//  tablet experiment
//
//  Created by Isaac Greenspan on 4/29/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "NSBezierPath+boundsWithLines.h"


@implementation NSBezierPath (boundsWithLines)

- (NSRect)boundsWithLines {
	NSRect bounds = [self bounds];
	CGFloat lineWidth = [self lineWidth];
	bounds.size.width += 2.0 * lineWidth;
	bounds.size.height += 2.0 * lineWidth;
	bounds.origin.x -= lineWidth;
	bounds.origin.y -= lineWidth;
	return bounds;
}

@end
