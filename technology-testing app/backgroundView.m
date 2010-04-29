//
//  backgroundView.m
//  tablet experiment
//
//  Created by Isaac Greenspan on 4/29/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "backgroundView.h"


@implementation backgroundView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect {
    // Drawing code here.
	
	// Save the current graphics state first so we can restore it.
	[[NSGraphicsContext currentContext] saveGraphicsState];
	
	// Change the pattern phase.
	[[NSGraphicsContext currentContext] setPatternPhase:
	 NSMakePoint(0,[self frame].size.height)];
	
	// Stick the image in a color and fill the view with that color.
    NSImage *anImage = [NSImage imageNamed:@"lined paper background3"];
	[[NSColor colorWithPatternImage:anImage] set];
	NSRectFill([self bounds]);
	
	// Restore the original graphics state.
	[[NSGraphicsContext currentContext] restoreGraphicsState];
}

@end
