//
//  tabletView.h
//  tablet experiment
//
//  Created by Isaac Greenspan on 4/27/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface tabletView : NSView {
	@private
	NSMutableArray *paths;
	NSBezierPath *workingPath;
	NSCursor *penCursor;
	NSCursor *eraserCursor;
	CGFloat initialPressure;
	NSPointingDeviceType pointingDeviceType;
}

- (IBAction)copy:(id)sender;

@end
