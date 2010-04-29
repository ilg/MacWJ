//
//  tablet_experimentAppDelegate.m
//  tablet experiment
//
//  Created by Isaac Greenspan on 4/27/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "tablet_experimentAppDelegate.h"

@implementation tablet_experimentAppDelegate

@synthesize window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	// Insert code here to initialize your application
	[[NSUserDefaults standardUserDefaults]
	 registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
					   // object, key; nil-terminated
					   [NSNumber numberWithFloat:0.5], @"minStrokeWidth",
					   [NSNumber numberWithFloat:3.0], @"maxStrokeWidth",
					   [NSNumber numberWithFloat:3.0], @"eraserRadius",
					   nil]];
}

@end
