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
//  tabletPenNib.m
//  MacWJ
//

#import "tabletPenNib.h"


@implementation tabletPenNib

@synthesize minimumStrokeWidth, maximumStrokeWidth, isAngleDependent, widestAngle, inkColor;

#define MIN_ANGLE_FACTOR 0.2

+ (tabletPenNib *)tabletPenNibWithMinimumWidth:(CGFloat)minimumWidth
								  maximumWidth:(CGFloat)maximumWidth
							  isAngleDependent:(BOOL)angleDependence
							  angleForMaxWidth:(CGFloat)maxWidthAngle
										 color:(NSColor *)color
{
	tabletPenNib *newPen = [[[tabletPenNib alloc] init] autorelease];
	[newPen setMinimumStrokeWidth:minimumWidth];
	[newPen setMaximumStrokeWidth:maximumWidth];
	[newPen setIsAngleDependent:angleDependence];
	if (angleDependence) [newPen setWidestAngle:maxWidthAngle];
	[newPen setInkColor:color];
	return newPen;
}

+ (NSDictionary *)penNibs {
	return [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults]
													   objectForKey:@"penNibs"]];
}


- (CGFloat)lineWidthFrom:(NSPoint)startingPoint
			withPressure:(CGFloat)startingPressure
					  to:(NSPoint)endingPoint
			withPressure:(CGFloat)endingPressure
{
	CGFloat angleFactor = 1.0;
	if ([self isAngleDependent]) {
		CGFloat halfPi = pi / 2.0;
		// compute the angle of the segment, (-pi/2, pi/2]
		CGFloat angle = (
						 ((startingPoint.x - endingPoint.x) != 0.0) // check for vertical segment
						 ? - atanf((startingPoint.y - endingPoint.y) / (startingPoint.x - endingPoint.x))
									// negated because the "flipped" coordinate system flips angles, too
						 : halfPi
						 );
		
		CGFloat angleDifference = ABS([self widestAngle] - angle);
		// adjust the angleDifference to be in [0,pi)
		while (angleDifference >= pi) {
			angleDifference -= pi;
		}
		// (pi/2,pi) folds over (0,pi/2)
		if (angleDifference > halfPi) {
			angleDifference = pi - angleDifference;
		}
		// now, angleDifference is in [0,pi/2] where 0 should be widest and pi/2 should be thinnest
		angleFactor = 1.0 - (1.0 - MIN_ANGLE_FACTOR) * angleDifference / halfPi;
	}
	
	return MAX([self minimumStrokeWidth],
			   (startingPressure + endingPressure) / 2.0 * angleFactor * [self maximumStrokeWidth]
			   );
}

#pragma mark -
#pragma mark for archiving/unarchiving (for saving/loading documents)

NSString * const kTabletPenNibMinWidthKey = @"tabletPenNibMinWidthKey";
NSString * const kTabletPenNibMaxWidthKey = @"tabletPenNibMaxWidthKey";
NSString * const kTabletPenNibAngleDependenceKey = @"tabletPenNibAngleDependenceKey";
NSString * const kTabletPenNibMaxAngleKey = @"tabletPenNibMaxAngleKey";
NSString * const kTabletPenNibColorKey = @"tabletPenNibColorKey";

- (void)encodeWithCoder:(NSCoder *)coder {
	// NSObject does not conform to NSCoding
	//    [super encodeWithCoder:coder];
	[coder encodeFloat:minimumStrokeWidth forKey:kTabletPenNibMinWidthKey];
	[coder encodeFloat:maximumStrokeWidth forKey:kTabletPenNibMaxWidthKey];
	[coder encodeBool:isAngleDependent forKey:kTabletPenNibAngleDependenceKey];
	if ([self isAngleDependent]) [coder encodeFloat:widestAngle forKey:kTabletPenNibMaxAngleKey];
    [coder encodeObject:inkColor forKey:kTabletPenNibColorKey];
}

- (id)initWithCoder:(NSCoder *)coder {
	// NSObject does not conform to NSCoding
	//    self = [super initWithCoder:coder];
	self = [super init];
	if (self) {
		[self setMinimumStrokeWidth:[coder decodeFloatForKey:kTabletPenNibMinWidthKey]];
		[self setMaximumStrokeWidth:[coder decodeFloatForKey:kTabletPenNibMaxWidthKey]];
		[self setIsAngleDependent:[coder decodeBoolForKey:kTabletPenNibAngleDependenceKey]];
		if ([self isAngleDependent]) {
			[self setWidestAngle:[coder decodeFloatForKey:kTabletPenNibMaxAngleKey]];
		}
		[self setInkColor:[coder decodeObjectForKey:kTabletPenNibColorKey]];
	}
    return self;
}


@end
