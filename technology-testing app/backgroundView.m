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
//  backgroundView.m
//  tablet experiment
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
